
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Colores de CELEX Academy.
const Color azulPagos = Color(0xFF023C87);
const Color fondoPagos = Color(0xFFEAF1FB);

// Tamaño máximo permitido: 5 MB.
const int limitePDF = 5 * 1024 * 1024;

class PagosComprobantes extends StatefulWidget {
  const PagosComprobantes({super.key});

  @override
  State<PagosComprobantes> createState() => _PagosComprobantesState();
}

class _PagosComprobantesState extends State<PagosComprobantes> {
  final supabase = Supabase.instance.client;

  bool cargando = true;
  int? solicitudSubiendo;

  List<Map<String, dynamic>> solicitudesPendientes = [];
  List<Map<String, dynamic>> pagos = [];

  @override
  void initState() {
    super.initState();
    consultarDatos();
  }

  // Consulta solicitudes, pagos, periodos, grupos y tarifas.
  Future<void> consultarDatos() async {
    try {
      final usuario = supabase.auth.currentUser;

      if (usuario == null) {
        throw Exception('No hay una sesión iniciada.');
      }

      // Consultar las solicitudes pendientes de pago del estudiante.
      final respuestaSolicitudes = await supabase
          .from('solicitudes')
          .select('''
            id,
            tipo_tramite,
            estado,
            periodo_id,
            grupo_id,
            horario_examen_id,
            idioma:idiomas!solicitudes_idioma_id_fkey(nombre),
            nivel_solicitado:niveles!solicitudes_nivel_id_fkey(nombre, orden),
            nivel_obtenido:niveles!solicitudes_nivel_obtenido_id_fkey(nombre, orden),
            nivel_asignado:niveles!solicitudes_nivel_asignado_id_fkey(nombre, orden)
          ''')
          .eq('estudiante_id', usuario.id)
          .eq('estado', 'Pendiente de pago')
          .order('fecha_solicitud', ascending: false);

      final solicitudes =
          List<Map<String, dynamic>>.from(respuestaSolicitudes);

      // Obtener los identificadores de los periodos.
      final periodosIds = solicitudes
          .map((solicitud) =>
              int.tryParse(solicitud['periodo_id']?.toString() ?? ''))
          .whereType<int>()
          .toSet()
          .toList();

      // Consultar las fechas necesarias para validar los pagos.
      final Map<int, Map<String, dynamic>> periodosPorId = {};

      if (periodosIds.isNotEmpty) {
        final respuestaPeriodos = await supabase
            .from('periodos')
            .select('''
              id,
              fecha_limite_pago_examen,
              fecha_examen_colocacion,
              fecha_publicacion_grupos,
              fecha_limite_pago,
              fecha_inicio
            ''')
            .inFilter('id', periodosIds);

        for (final periodo in respuestaPeriodos) {
          final datos = Map<String, dynamic>.from(periodo);
          final id = int.tryParse(datos['id'].toString());

          if (id != null) {
            periodosPorId[id] = datos;
          }
        }
      }

      // Consultar la categoría del estudiante.
      final perfil = await supabase
          .from('perfiles_estudiantes')
          .select('categoria')
          .eq('id', usuario.id)
          .maybeSingle();

      final categoriaEstudiante =
          perfil?['categoria']?.toString() ?? '';

      // Consultar si cada grupo está publicado y habilitado para pagos.
      final Map<int, Map<String, dynamic>> gruposPorSolicitud = {};

      for (final solicitud in solicitudes) {
        final grupoId =
            int.tryParse(solicitud['grupo_id']?.toString() ?? '');

        if (grupoId == null) {
          continue;
        }

        final solicitudId =
            int.tryParse(solicitud['id'].toString());

        if (solicitudId == null) {
          continue;
        }

        final respuestaGrupo = await supabase.rpc(
          'obtener_estado_grupo_pago',
          params: {
            'p_solicitud_id': solicitudId,
          },
        );

        final filas = List<Map<String, dynamic>>.from(
          respuestaGrupo as List,
        );

        if (filas.isNotEmpty) {
          gruposPorSolicitud[solicitudId] = filas.first;
        }
      }

      // Agregar los datos del periodo, grupo, tarifa y verificación IPN.
      for (final solicitud in solicitudes) {
        final solicitudId =
            int.tryParse(solicitud['id'].toString());

        final periodoId =
            int.tryParse(solicitud['periodo_id']?.toString() ?? '');

        solicitud['_datos_periodo'] =
            periodoId == null ? {} : periodosPorId[periodoId] ?? {};

        solicitud['_datos_grupo'] = solicitudId == null
            ? {}
            : gruposPorSolicitud[solicitudId] ?? {};

        solicitud['_categoria_estudiante'] = categoriaEstudiante;

        // Consultar la verificación IPN correspondiente al periodo.
        // Público general y examen de colocación no requieren esta validación.
        final esExamen =
            solicitud['tipo_tramite'] == 'Examen de colocación';

        if (esExamen || categoriaEstudiante != 'Comunidad IPN') {
          solicitud['_ipn_verificada'] = true;
        } else if (periodoId != null) {
          try {
            solicitud['_ipn_verificada'] =
                await verificarIPNPeriodo(usuario.id, periodoId);
          } catch (_) {
            // Si no se puede comprobar la verificación,
            // se bloquea el envío por seguridad.
            solicitud['_ipn_verificada'] = false;
          }
        } else {
          solicitud['_ipn_verificada'] = false;
        }

        // Consultar la tarifa correspondiente a esta solicitud.
        try {
          if (categoriaEstudiante.isNotEmpty) {
            solicitud['_datos_tarifa'] = await obtenerTarifa(
              solicitud,
              categoriaEstudiante,
            );
          } else {
            solicitud['_datos_tarifa'] = {};
          }
        } catch (_) {
          solicitud['_datos_tarifa'] = {};
        }
      }

      // Consultar el historial de pagos del estudiante.
      final respuestaPagos = await supabase
          .from('pagos')
          .select('''
            id,
            solicitud_id,
            tipo_pago,
            monto,
            tarifa_id,
            comprobante_url,
            estado,
            fecha_registro,
            notas_coordinador,
            solicitudes:solicitudes!pagos_solicitud_id_fkey(
              tipo_tramite,
              idioma:idiomas!solicitudes_idioma_id_fkey(nombre),
              nivel_solicitado:niveles!solicitudes_nivel_id_fkey(nombre, orden),
              nivel_obtenido:niveles!solicitudes_nivel_obtenido_id_fkey(nombre, orden),
              nivel_asignado:niveles!solicitudes_nivel_asignado_id_fkey(nombre, orden)
            )
          ''')
          .eq('estudiante_id', usuario.id)
          .order('fecha_registro', ascending: false);

      final listaPagos =
          List<Map<String, dynamic>>.from(respuestaPagos);

      // Identificar solicitudes con un pago pendiente de revisión
      // o confirmado.
      final Set<String> solicitudesConPagoActivo = {};

      for (final pago in listaPagos) {
        final estado = pago['estado']?.toString();

        if (estado == 'Pendiente de revisión' ||
            estado == 'Confirmado') {
          final solicitudId = pago['solicitud_id']?.toString();

          if (solicitudId != null) {
            solicitudesConPagoActivo.add(solicitudId);
          }
        }
      }

      // Ocultar solicitudes que ya tienen un pago activo.
      solicitudes.removeWhere((solicitud) {
        final id = solicitud['id']?.toString();

        return id != null && solicitudesConPagoActivo.contains(id);
      });

      if (!mounted) {
        return;
      }

      setState(() {
        solicitudesPendientes = solicitudes;
        pagos = listaPagos;
        cargando = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        cargando = false;
      });

      _mostrarMensaje('No se pudieron consultar los pagos: $error');
    }
  }

  // Comprueba si el estudiante tiene su verificación IPN aprobada
  // para un periodo específico.
  Future<bool> verificarIPNPeriodo(
    String estudianteId,
    int periodoId,
  ) async {
    final respuesta = await supabase
        .from('verificaciones_ipn_periodo')
        .select('estado')
        .eq('estudiante_id', estudianteId)
        .eq('periodo_id', periodoId)
        .order('fecha_registro', ascending: false)
        .limit(1);

    final verificaciones =
        List<Map<String, dynamic>>.from(respuesta);

    if (verificaciones.isEmpty) {
      return false;
    }

    return verificaciones.first['estado']?.toString() == 'Verificada';
  }

  // Obtiene una relación de Supabase como mapa.
  Map<String, dynamic> obtenerRelacion(dynamic relacion) {
    if (relacion is Map) {
      return Map<String, dynamic>.from(relacion);
    }

    if (relacion is List && relacion.isNotEmpty) {
      return Map<String, dynamic>.from(relacion.first);
    }

    return {};
  }

  // Obtiene el nombre de una relación.
  String obtenerNombre(dynamic relacion) {
    final datos = obtenerRelacion(relacion);
    return datos['nombre']?.toString() ?? 'No disponible';
  }

  // Obtiene el nivel que corresponde mostrar en la solicitud.
  String obtenerNivel(Map<String, dynamic> solicitud) {
    final tipo = solicitud['tipo_tramite']?.toString() ?? '';

    if (tipo == 'Examen de colocación') {
      final asignado =
          obtenerRelacion(solicitud['nivel_asignado']);

      final obtenido =
          obtenerRelacion(solicitud['nivel_obtenido']);

      if (asignado.isNotEmpty) {
        return asignado['nombre']?.toString() ?? 'Por determinar';
      }

      if (obtenido.isNotEmpty) {
        return obtenido['nombre']?.toString() ?? 'Por determinar';
      }

      return 'Por determinar mediante examen';
    }

    final solicitado =
        obtenerRelacion(solicitud['nivel_solicitado']);

    return solicitado['nombre']?.toString() ?? 'No disponible';
  }

  // Convierte una fecha de Supabase a DateTime.
  DateTime? convertirFecha(dynamic valor) {
    if (valor == null) {
      return null;
    }

    return DateTime.tryParse(valor.toString());
  }

  // Obtiene la fecha actual sin considerar la hora.
  DateTime obtenerFechaActual() {
    final ahora = DateTime.now();

    return DateTime(
      ahora.year,
      ahora.month,
      ahora.day,
    );
  }

  // Convierte una fecha a un formato legible.
  String fechaLegible(dynamic valor) {
    final fecha = convertirFecha(valor);

    if (fecha == null) {
      return 'No disponible';
    }

    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');

    return '$dia/$mes/${fecha.year}';
  }

  // Muestra la fecha y hora en que se registró el pago.
  String fechaHoraLegible(dynamic valor) {
    final fecha = convertirFecha(valor);

    if (fecha == null) {
      return 'No disponible';
    }

    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    final hora = fecha.hour.toString().padLeft(2, '0');
    final minuto = fecha.minute.toString().padLeft(2, '0');

    return '$dia/$mes/${fecha.year} a las $hora:$minuto';
  }

  // Da formato al importe de una tarifa.
  String formatoMonto(dynamic valor) {
    if (valor == null) {
      return 'No disponible';
    }

    final monto = double.tryParse(valor.toString());

    if (monto == null) {
      return 'No disponible';
    }

    return '\$${monto.toStringAsFixed(2)} MXN';
  }

  // Convierte el estado interno a su nombre visible.
  String nombreEstadoPago(String estado) {
    if (estado == 'Pendiente de revisión') {
      return 'Revisión de pago';
    }

    return estado;
  }

  // Indica por qué todavía no se puede realizar un pago.
  String motivoNoDisponible(Map<String, dynamic> solicitud) {
    final tipo = solicitud['tipo_tramite']?.toString() ?? '';

    final periodo =
        obtenerRelacion(solicitud['_datos_periodo']);

    final fechaActual = obtenerFechaActual();

    // Validaciones para examen de colocación.
    if (tipo == 'Examen de colocación') {
      if (solicitud['horario_examen_id'] == null) {
        return 'CELEX todavía no te asigna un horario para el examen.';
      }

      final fechaLimite =
          convertirFecha(periodo['fecha_limite_pago_examen']);

      final fechaExamen =
          convertirFecha(periodo['fecha_examen_colocacion']);

      if (fechaLimite == null || fechaExamen == null) {
        return 'El periodo todavía no tiene configuradas '
            'las fechas de pago y examen.';
      }

      if (fechaActual.isAfter(fechaLimite)) {
        return 'El plazo para pagar el examen terminó el '
            '${fechaLegible(fechaLimite)}.';
      }

      if (!fechaActual.isBefore(fechaExamen)) {
        return 'La fecha del examen ya llegó o pasó. '
            'Ya no puedes registrar este pago.';
      }

      return '';
    }

    // Validaciones para pago de curso.
    if (solicitud['grupo_id'] == null) {
      return 'Todavía no tienes un grupo asignado. '
          'Espera las indicaciones de CELEX.';
    }

    final grupo =
        obtenerRelacion(solicitud['_datos_grupo']);

    if (grupo.isEmpty) {
      return 'No se pudo verificar la disponibilidad de tu grupo '
          'para realizar el pago. Actualiza la pantalla o contacta a CELEX.';
    }

    if (grupo['publicado'] != true) {
      return 'Tu grupo todavía no ha sido publicado por CELEX.';
    }

    final estadoGrupo = grupo['estado']?.toString() ?? '';

    if (estadoGrupo != 'Abierto' && estadoGrupo != 'Lleno') {
      return 'Tu grupo todavía no está habilitado para recibir pagos.';
    }

    final fechaPublicacion =
        convertirFecha(periodo['fecha_publicacion_grupos']);

    final fechaLimite =
        convertirFecha(periodo['fecha_limite_pago']);

    final fechaInicio =
        convertirFecha(periodo['fecha_inicio']);

    if (fechaPublicacion == null ||
        fechaLimite == null ||
        fechaInicio == null) {
      return 'El periodo todavía no tiene configuradas '
          'todas las fechas para el pago del curso.';
    }

    if (fechaActual.isBefore(fechaPublicacion)) {
      return 'Podrás pagar a partir de la publicación de grupos: '
          '${fechaLegible(fechaPublicacion)}.';
    }

    if (fechaActual.isAfter(fechaLimite)) {
      return 'El plazo para pagar el curso terminó el '
          '${fechaLegible(fechaLimite)}.';
    }

    if (!fechaActual.isBefore(fechaInicio)) {
      return 'El periodo de pago terminó porque las clases '
          'ya comenzaron el ${fechaLegible(fechaInicio)}.';
    }

    return '';
  }

  // Comprueba si el estudiante ya puede realizar el pago.
  bool puedeRealizarPago(Map<String, dynamic> solicitud) {
    return motivoNoDisponible(solicitud).isEmpty;
  }

  // Comprueba si la solicitud tiene un pago pendiente de revisión
  // o confirmado.
  bool tienePagoActivo(int solicitudId) {
    return pagos.any((pago) {
      final id = int.tryParse(
        pago['solicitud_id']?.toString() ?? '',
      );

      final estado = pago['estado']?.toString();

      return id == solicitudId &&
          (estado == 'Pendiente de revisión' ||
              estado == 'Confirmado');
    });
  }

  // Muestra mensajes en pantalla.
  void _mostrarMensaje(String mensaje) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje)),
    );
  }

  // Busca la tarifa activa que corresponde a la solicitud.
  Future<Map<String, dynamic>> obtenerTarifa(
    Map<String, dynamic> solicitud,
    String categoria,
  ) async {
    final periodoId = int.tryParse(
      solicitud['periodo_id'].toString(),
    );

    if (periodoId == null) {
      throw Exception('La solicitud no tiene un periodo válido.');
    }

    final tipoTramite =
        solicitud['tipo_tramite']?.toString() ?? '';

    final tipoPago = tipoTramite == 'Examen de colocación'
        ? 'Examen de colocación'
        : 'Curso';

    // El examen tiene una tarifa única para ambas categorías.
    final categoriaTarifa =
        tipoPago == 'Examen de colocación' ? 'Todos' : categoria;

    final respuesta = await supabase
        .from('tarifas_periodo')
        .select('id, monto, tipo_pago, categoria')
        .eq('periodo_id', periodoId)
        .eq('tipo_pago', tipoPago)
        .eq('categoria', categoriaTarifa)
        .eq('activo', true)
        .maybeSingle();

    if (respuesta == null) {
      throw Exception(
        'No existe una tarifa activa para $tipoPago '
        'en este periodo y categoría.',
      );
    }

    return Map<String, dynamic>.from(respuesta);
  }

  // Selecciona un PDF y lo sube a Supabase Storage.
  Future<void> seleccionarComprobante(
    Map<String, dynamic> solicitud,
  ) async {
    final solicitudId =
        int.tryParse(solicitud['id'].toString());

    if (solicitudId == null) {
      _mostrarMensaje('No se pudo identificar la solicitud.');
      return;
    }

    if (solicitudSubiendo != null) {
      return;
    }

    // Comprobar nuevamente la verificación IPN antes de permitir
    // seleccionar el comprobante.
    final tipoTramite =
        solicitud['tipo_tramite']?.toString() ?? '';

    final categoria =
        solicitud['_categoria_estudiante']?.toString() ?? '';

    if (tipoTramite != 'Examen de colocación' &&
        categoria == 'Comunidad IPN') {
      final usuario = supabase.auth.currentUser;
      final periodoId = int.tryParse(
        solicitud['periodo_id']?.toString() ?? '',
      );

      if (usuario == null || periodoId == null) {
        _mostrarMensaje(
          'No se pudo comprobar tu verificación IPN para este periodo.',
        );
        return;
      }

      try {
        final verificada = await verificarIPNPeriodo(
          usuario.id,
          periodoId,
        );

        if (!verificada) {
          _mostrarMensaje(
            'Primero debes registrar y validar tu categoría IPN '
            'para este periodo.',
          );
          return;
        }
      } catch (_) {
        _mostrarMensaje(
          'No se pudo comprobar tu verificación IPN. '
          'Inténtalo nuevamente.',
        );
        return;
      }
    }

    // Validar nuevamente las fechas y el estado del grupo.
    final motivo = motivoNoDisponible(solicitud);

    if (motivo.isNotEmpty) {
      _mostrarMensaje(motivo);
      return;
    }

    // No permitir otro comprobante si ya hay uno pendiente o confirmado.
    if (tienePagoActivo(solicitudId)) {
      _mostrarMensaje('Esta solicitud ya tiene un pago registrado.');
      return;
    }

    String? rutaArchivo;
    bool archivoSubido = false;

    try {
      // Abrir el selector de archivos y permitir únicamente PDF.
      final archivo = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (archivo == null) {
        return;
      }

      if (archivo.extension?.toLowerCase() != 'pdf') {
        _mostrarMensaje('Solamente se permiten archivos PDF.');
        return;
      }

      final tamano = await archivo.length();

      if (tamano == null || tamano == 0) {
        _mostrarMensaje('No se pudo leer el archivo seleccionado.');
        return;
      }

      if (tamano > limitePDF) {
        _mostrarMensaje('El PDF no debe superar los 5 MB.');
        return;
      }

      final bytes = await archivo.readAsBytes();

      if (bytes.isEmpty || bytes.length > limitePDF) {
        _mostrarMensaje('El archivo no es válido o supera los 5 MB.');
        return;
      }

      final usuario = supabase.auth.currentUser;

      if (usuario == null) {
        _mostrarMensaje('Debes iniciar sesión nuevamente.');
        return;
      }

      setState(() {
        solicitudSubiendo = solicitudId;
      });

      // Consultar nuevamente la categoría del estudiante.
      final perfil = await supabase
          .from('perfiles_estudiantes')
          .select('categoria')
          .eq('id', usuario.id)
          .single();

      final categoriaActual =
          perfil['categoria']?.toString() ?? '';

      if (categoriaActual.isEmpty) {
        throw Exception('No se encontró la categoría del estudiante.');
      }

      // Comprobar otra vez la verificación IPN antes de subir el PDF.
      // El examen de colocación no necesita esta validación.
      if (tipoTramite != 'Examen de colocación' &&
          categoriaActual == 'Comunidad IPN') {
        final periodoId = int.tryParse(
          solicitud['periodo_id']?.toString() ?? '',
        );

        if (periodoId == null) {
          throw Exception('No se pudo identificar el periodo.');
        }

        final verificada = await verificarIPNPeriodo(
          usuario.id,
          periodoId,
        );

        if (!verificada) {
          throw Exception(
            'Primero debes registrar y validar tu categoría IPN '
            'para este periodo.',
          );
        }
      }

      // Buscar nuevamente la tarifa correspondiente en Supabase.
      final tarifa = await obtenerTarifa(
        solicitud,
        categoriaActual,
      );

      final tarifaId = int.tryParse(tarifa['id'].toString());
      final monto = (tarifa['monto'] as num).toDouble();

      if (tarifaId == null) {
        throw Exception('No se pudo identificar la tarifa.');
      }

      final tipoPago = tipoTramite == 'Examen de colocación'
          ? 'Examen de colocación'
          : 'Curso';

      // Crear la ruta privada del comprobante.
      final nombreArchivo =
          'solicitud_${solicitudId}_${DateTime.now().millisecondsSinceEpoch}.pdf';

      rutaArchivo = '${usuario.id}/$nombreArchivo';

      // Subir el PDF al bucket privado.
      await supabase.storage
          .from('comprobantes')
          .uploadBinary(
            rutaArchivo,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'application/pdf',
              upsert: false,
            ),
          );

      archivoSubido = true;

      // Registrar el pago mediante la RPC.
      await supabase.rpc(
        'registrar_comprobante_pago_celex',
        params: {
          'p_solicitud_id': solicitudId,
          'p_tipo_pago': tipoPago,
          'p_tarifa_id': tarifaId,
          'p_monto': monto,
          'p_comprobante_url': rutaArchivo,
        },
      );

      if (!mounted) {
        return;
      }

      _mostrarMensaje('¡Comprobante enviado correctamente!');

      // Actualizar la pantalla.
      await consultarDatos();
    } catch (error) {
      // Si se subió el archivo, pero falló el registro del pago,
      // intentamos eliminarlo para no dejar archivos sin utilizar.
      if (archivoSubido && rutaArchivo != null) {
        try {
          await supabase.storage
              .from('comprobantes')
              .remove([rutaArchivo]);
        } catch (_) {
          // No interrumpimos el mensaje del error principal.
        }
      }

      _mostrarMensaje('No se pudo enviar el comprobante: $error');
    } finally {
      if (mounted) {
        setState(() {
          solicitudSubiendo = null;
        });
      }
    }
  }

  // Devuelve el color correspondiente al estado del pago.
  Color colorEstado(String estado) {
    switch (estado) {
      case 'Confirmado':
        return Colors.green;
      case 'Rechazado':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: fondoPagos,
      appBar: AppBar(
        title: const Text(
          'Pagos y comprobantes',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: azulPagos,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            onPressed: cargando ? null : consultarDatos,
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: consultarDatos,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Mis pagos',
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                        color: azulPagos,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Consulta tus pagos y envía los comprobantes '
                      'correspondientes a tus solicitudes de CELEX.',
                      style: TextStyle(fontSize: 15),
                    ),
                    const SizedBox(height: 22),

                    // Aviso importante.
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.orange.shade300,
                        ),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.deepOrange,
                            size: 28,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Importante: el examen de colocación '
                              'debe pagarse antes de presentarlo. '
                              'El curso se paga después de la publicación '
                              'de grupos y antes del inicio de clases.',
                              style: TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    const Text(
                      'Mis solicitudes',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: azulPagos,
                      ),
                    ),

                    const SizedBox(height: 12),

                    if (solicitudesPendientes.isEmpty)
                      _mensajeVacio(
                        Icons.receipt_long,
                        'No tienes solicitudes pendientes de pago.',
                        'Cuando tengas una solicitud pendiente, '
                            'aparecerá aquí.',
                      )
                    else
                      ...solicitudesPendientes.map(
                        (solicitud) => _tarjetaSolicitud(solicitud),
                      ),

                    const SizedBox(height: 26),

                    const Text(
                      'Historial de pagos',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: azulPagos,
                      ),
                    ),

                    const SizedBox(height: 12),

                    if (pagos.isEmpty)
                      _mensajeVacio(
                        Icons.history,
                        'Todavía no tienes pagos registrados.',
                        'Aquí aparecerán los comprobantes que envíes.',
                      )
                    else
                      ...pagos.map(
                        (pago) => _tarjetaPago(pago),
                      ),

                    const SizedBox(height: 20),

                    const Center(
                      child: Text(
                        'CELEX Academy',
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // Tarjeta de una solicitud pendiente de pago.
  Widget _tarjetaSolicitud(Map<String, dynamic> solicitud) {
    final solicitudId = int.parse(solicitud['id'].toString());

    final idioma = obtenerNombre(solicitud['idioma']);
    final nivel = obtenerNivel(solicitud);

    final tipoTramite =
        solicitud['tipo_tramite']?.toString() ?? 'Curso';

    final esExamen = tipoTramite == 'Examen de colocación';

    final categoria =
        solicitud['_categoria_estudiante']?.toString() ?? '';

    final tarifa =
        obtenerRelacion(solicitud['_datos_tarifa']);

    final tieneTarifa = tarifa.isNotEmpty;

    final monto = tieneTarifa
        ? formatoMonto(tarifa['monto'])
        : 'Tarifa no disponible';

    final categoriaMostrar = esExamen
        ? 'Tarifa única'
        : categoria.isEmpty
            ? 'No disponible'
            : categoria;

    // La verificación IPN solo es obligatoria para cursos
    // de estudiantes registrados como Comunidad IPN.
    final requiereVerificacionIPN =
        !esExamen && categoria == 'Comunidad IPN';

    final ipnVerificada =
        solicitud['_ipn_verificada'] == true;

    final puedeSubirPorIPN =
        !requiereVerificacionIPN || ipnVerificada;

    final yaTienePago = tienePagoActivo(solicitudId);
    final estaSubiendo = solicitudSubiendo == solicitudId;

    final motivo = motivoNoDisponible(solicitud);
    final tienePagoDisponible = motivo.isEmpty;

    String textoBoton;

    if (estaSubiendo) {
      textoBoton = 'Subiendo comprobante...';
    } else if (yaTienePago) {
      textoBoton = 'Comprobante registrado';
    } else if (!tieneTarifa) {
      textoBoton = 'Tarifa no disponible';
    } else if (!puedeSubirPorIPN) {
      textoBoton = 'Verificación IPN pendiente';
    } else if (!tienePagoDisponible) {
      textoBoton = 'Pago no disponible';
    } else {
      textoBoton = 'Seleccionar comprobante PDF';
    }

    return Card(
      color: Colors.white,
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.receipt_long,
                  color: azulPagos,
                  size: 30,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    tipoTramite,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: azulPagos,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 15),

            _DatoPago(
              etiqueta: 'Folio',
              valor: 'SOL-$solicitudId',
            ),

            _DatoPago(
              etiqueta: 'Idioma',
              valor: idioma,
            ),

            _DatoPago(
              etiqueta: 'Nivel',
              valor: nivel,
            ),

            const Divider(height: 25),

            const Text(
              'Detalle del pago',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: azulPagos,
              ),
            ),

            const SizedBox(height: 8),

            _DatoPago(
              etiqueta: 'Concepto',
              valor: esExamen ? 'Examen de colocación' : 'Curso',
            ),

            _DatoPago(
              etiqueta: 'Cuenta',
              valor: '9757583753758758457598',
            ),

            _DatoPago(
              etiqueta: 'Categoría',
              valor: categoriaMostrar,
            ),

            // Aviso visible cuando falta la verificación IPN.
            if (requiereVerificacionIPN && !ipnVerificada) ...[
              const SizedBox(height: 5),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: Colors.orange.shade300,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.deepOrange,
                      size: 21,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'No has validado tu verificación IPN para este '
                        'periodo. No podrás subir tu comprobante hasta '
                        'que CELEX verifique tu categoría.',
                        style: TextStyle(
                          color: Colors.deepOrange.shade800,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            _DatoPago(
              etiqueta: 'Monto',
              valor: monto,
            ),

            if (!tieneTarifa) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  'No se encontró una tarifa activa para esta solicitud. '
                  'Por favor, contacta a CELEX antes de realizar el pago.',
                  style: TextStyle(
                    color: Colors.deepOrange.shade800,
                    fontSize: 13,
                  ),
                ),
              ),
            ],

            const Divider(height: 25),

            // Mensaje de disponibilidad según el tipo de solicitud.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: tienePagoDisponible
                    ? Colors.green.shade50
                    : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    tienePagoDisponible
                        ? Icons.check_circle_outline
                        : Icons.info_outline,
                    color: tienePagoDisponible
                        ? Colors.green.shade700
                        : Colors.deepOrange,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      tienePagoDisponible
                          ? (esExamen
                              ? 'Tu horario está asignado y todavía '
                                  'estás dentro del plazo para pagar '
                                  'el examen.'
                              : 'Tu grupo está publicado y estás '
                                  'dentro del plazo para pagar el curso.')
                          : motivo,
                      style: TextStyle(
                        fontSize: 13,
                        color: tienePagoDisponible
                            ? Colors.green.shade800
                            : Colors.deepOrange.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 15),

            const Text(
              'Comprobante de pago',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 6),

            const Text(
              'Selecciona el PDF de tu comprobante. '
              'El archivo no debe superar los 5 MB.',
              style: TextStyle(fontSize: 13),
            ),

            const SizedBox(height: 15),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: yaTienePago ||
                        estaSubiendo ||
                        !tienePagoDisponible ||
                        !tieneTarifa ||
                        !puedeSubirPorIPN
                    ? null
                    : () => seleccionarComprobante(solicitud),
                icon: estaSubiendo
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.picture_as_pdf),
                label: Text(textoBoton),
                style: ElevatedButton.styleFrom(
                  backgroundColor: azulPagos,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade400,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Tarjeta de un pago registrado en el historial.
  Widget _tarjetaPago(Map<String, dynamic> pago) {
    final estado =
        pago['estado']?.toString() ?? 'Pendiente de revisión';

    final estadoVisible = nombreEstadoPago(estado);

    final solicitud =
        obtenerRelacion(pago['solicitudes']);

    final idioma = obtenerNombre(solicitud['idioma']);

    final nivel = solicitud.isEmpty
        ? 'No disponible'
        : obtenerNivel(solicitud);

    final solicitudId = pago['solicitud_id'];
    final pagoId = pago['id'];

    final tipoPago =
        pago['tipo_pago']?.toString() ?? 'No disponible';

    final monto = pago['monto'] == null
        ? 'Pendiente de asignación'
        : formatoMonto(pago['monto']);

    final fechaRegistro =
        fechaHoraLegible(pago['fecha_registro']);

    final notaAnterior =
        pago['notas_coordinador']?.toString().trim() ?? '';

    final tieneNotaAnterior = notaAnterior.isNotEmpty;

    String mensajeEstado;

    switch (estado) {
      case 'Pendiente de revisión':
        mensajeEstado =
            'Tu comprobante fue enviado correctamente y está '
            'en revisión por parte del personal de CELEX. '
            'No necesitas enviarlo nuevamente.';
        break;

      case 'Confirmado':
        mensajeEstado =
            '¡Tu pago fue confirmado! El personal de CELEX '
            'validó tu comprobante. Consulta la sección de tus '
            'grupos para revisar la información de tu inscripción.';
        break;

      case 'Rechazado':
        mensajeEstado =
            'Tu comprobante fue rechazado por CELEX. '
            'Revisa el motivo del rechazo y, si el periodo de pago '
            'continúa vigente, podrás enviar nuevamente tu comprobante '
            'desde la sección "Mis solicitudes".';
        break;

      default:
        mensajeEstado =
            'Consulta el estado de tu pago con el personal de CELEX.';
    }

    return Card(
      color: Colors.white,
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.receipt_long,
                  color: azulPagos,
                  size: 30,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Registro de pago',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: azulPagos,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 15),

            const Text(
              'Información del pago',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: azulPagos,
              ),
            ),

            const SizedBox(height: 8),

            _DatoPago(
              etiqueta: 'Folio de pago',
              valor: 'PAG-$pagoId',
            ),

            _DatoPago(
              etiqueta: 'Solicitud',
              valor: 'SOL-$solicitudId',
            ),

            _DatoPago(
              etiqueta: 'Concepto',
              valor: tipoPago,
            ),

            _DatoPago(
              etiqueta: 'Idioma',
              valor: idioma,
            ),

            _DatoPago(
              etiqueta: 'Nivel',
              valor: nivel,
            ),

            _DatoPago(
              etiqueta: 'Monto',
              valor: monto,
            ),

            _DatoPago(
              etiqueta: 'Enviado',
              valor: fechaRegistro,
            ),

            const Divider(height: 25),

            const Text(
              'Estado del comprobante',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: azulPagos,
              ),
            ),

            const SizedBox(height: 9),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: colorEstado(estado).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                  color: colorEstado(estado).withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    estado == 'Confirmado'
                        ? Icons.check_circle
                        : estado == 'Rechazado'
                            ? Icons.cancel
                            : Icons.hourglass_top,
                    color: colorEstado(estado),
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          estadoVisible,
                          style: TextStyle(
                            color: colorEstado(estado),
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          mensajeEstado,
                          style: TextStyle(
                            color: colorEstado(estado),
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Mostrar la nota del rechazo anterior.
            if (tieneNotaAnterior) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.orange.shade200,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Colors.deepOrange,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Este pago fue rechazado anteriormente.',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.deepOrange,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Motivo: $notaAnterior',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black87,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (estado == 'Rechazado') ...[
              const SizedBox(height: 12),
              const Text(
                'Tu solicitud vuelve a estar disponible '
                'en "Mis solicitudes" para que puedas '
                'corregir y enviar otro comprobante. '
                'Se conservará el mismo folio de pago.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.black87,
                ),
              ),
            ],

            if (estado == 'Confirmado') ...[
              const SizedBox(height: 12),
              const Text(
                'Conserva este registro como comprobante '
                'de que tu pago fue validado.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.green,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Mensaje para cuando no hay registros.
  Widget _mensajeVacio(
    IconData icono,
    String titulo,
    String descripcion,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(
            icono,
            color: azulPagos,
            size: 38,
          ),
          const SizedBox(height: 10),
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: azulPagos,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            descripcion,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// Widget pequeño para mostrar cada dato del pago.
class _DatoPago extends StatelessWidget {
  final String etiqueta;
  final String valor;

  const _DatoPago({
    required this.etiqueta,
    required this.valor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              etiqueta,
              style: const TextStyle(
                color: Colors.black54,
              ),
            ),
          ),
          Expanded(
            child: Text(
              valor,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
