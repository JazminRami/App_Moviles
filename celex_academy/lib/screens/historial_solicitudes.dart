
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Colores de CELEX Academy.
const Color azulHistorial = Color(0xFF023C87);
const Color fondoHistorial = Color(0xFFEAF1FB);

// Pantalla del historial de solicitudes.
class HistorialSolicitudes extends StatefulWidget {
  const HistorialSolicitudes({super.key});

  @override
  State<HistorialSolicitudes> createState() =>
      _HistorialSolicitudesState();
}

class _HistorialSolicitudesState extends State<HistorialSolicitudes> {
  late Future<List<Map<String, dynamic>>> futureSolicitudes;

  @override
  void initState() {
    super.initState();
    cargarSolicitudes();
  }

  // Consulta las solicitudes, pagos, inscripciones y periodos.
  Future<List<Map<String, dynamic>>> consultarSolicitudes() async {
    final supabase = Supabase.instance.client;
    final usuario = supabase.auth.currentUser;

    if (usuario == null) {
      throw Exception('No hay una sesión iniciada.');
    }

    // 1. Consultar las solicitudes y sus pagos.
    final respuesta = await supabase
        .from('solicitudes')
        .select('''
          id,
          tipo_tramite,
          nivel_id,
          nivel_obtenido_id,
          nivel_asignado_id,
          horario_examen_id,
          periodo_id,
          estado,
          fecha_solicitud,
          observaciones,
          idiomas(nombre),
          nivel_solicitado:niveles!solicitudes_nivel_id_fkey(nombre, orden),
          nivel_obtenido:niveles!solicitudes_nivel_obtenido_id_fkey(nombre, orden),
          nivel_asignado:niveles!solicitudes_nivel_asignado_id_fkey(nombre, orden),
          horarios_examen_colocacion(
            hora_inicio,
            hora_fin
          ),
          pagos!pagos_solicitud_id_fkey(
            id,
            tipo_pago,
            estado,
            notas_coordinador,
            fecha_registro
          )
        ''')
        .eq('estudiante_id', usuario.id)
        .order('fecha_solicitud', ascending: false);

    final listaSolicitudes =
        List<Map<String, dynamic>>.from(respuesta);

    if (listaSolicitudes.isEmpty) {
      return listaSolicitudes;
    }

    // 2. Obtener los identificadores de las solicitudes.
    final idsSolicitudes = listaSolicitudes
        .map((solicitud) => solicitud['id'])
        .toList();

    // 3. Consultar las inscripciones del estudiante.
    final respuestaInscripciones = await supabase
        .from('inscripciones')
        .select('solicitud_id, estado')
        .eq('estudiante_id', usuario.id)
        .inFilter('solicitud_id', idsSolicitudes);

    final listaInscripciones =
        List<Map<String, dynamic>>.from(respuestaInscripciones);

    // 4. Relacionar las inscripciones con las solicitudes.
    for (final solicitud in listaSolicitudes) {
      Map<String, dynamic>? inscripcion;

      for (final registro in listaInscripciones) {
        if (registro['solicitud_id'].toString() ==
            solicitud['id'].toString()) {
          inscripcion = registro;
          break;
        }
      }

      solicitud['estado_inscripcion'] = inscripcion?['estado'];
    }

    // 5. Obtener los identificadores de los periodos.
    final idsPeriodos = listaSolicitudes
        .map((solicitud) => solicitud['periodo_id'])
        .where((id) => id != null)
        .toSet()
        .toList();

    // 6. Consultar las fechas de los periodos.
    if (idsPeriodos.isNotEmpty) {
      final respuestaPeriodos = await supabase
          .from('periodos')
          .select('id, nombre, fecha_inicio, fecha_fin')
          .inFilter('id', idsPeriodos);

      final listaPeriodos =
          List<Map<String, dynamic>>.from(respuestaPeriodos);

      // 7. Relacionar cada periodo con su solicitud.
      for (final solicitud in listaSolicitudes) {
        Map<String, dynamic>? periodo;

        for (final registro in listaPeriodos) {
          if (registro['id'].toString() ==
              solicitud['periodo_id'].toString()) {
            periodo = registro;
            break;
          }
        }

        solicitud['datos_periodo'] = periodo;
      }
    }

    return listaSolicitudes;
  }

  // Carga o actualiza las solicitudes.
  void cargarSolicitudes() {
    futureSolicitudes = consultarSolicitudes();
  }

  // Convierte una fecha de Supabase a un formato legible.
  String formatearFecha(dynamic fecha) {
    if (fecha == null) return 'No disponible';

    final texto = fecha.toString();

    // Las columnas DATE se interpretan sin conversión de zona horaria.
    final fechaConvertida = DateTime.tryParse(texto.substring(0, 10));

    if (fechaConvertida == null) return 'No disponible';

    final dia = fechaConvertida.day.toString().padLeft(2, '0');
    final mes = fechaConvertida.month.toString().padLeft(2, '0');
    final anio = fechaConvertida.year.toString();

    return '$dia/$mes/$anio';
  }

  // Convierte una hora de Supabase a formato de 12 horas.
  String formatearHora(dynamic hora) {
    if (hora == null) return 'No disponible';

    final partes = hora.toString().split(':');

    if (partes.length < 2) return hora.toString();

    final horaNumero = int.tryParse(partes[0]) ?? 0;
    final minutos = partes[1];

    final periodo = horaNumero >= 12 ? 'p. m.' : 'a. m.';
    final hora12 = horaNumero % 12 == 0 ? 12 : horaNumero % 12;

    return '${hora12.toString().padLeft(2, '0')}:$minutos $periodo';
  }

  // Obtiene el pago más reciente de una solicitud.
  Map<String, dynamic>? obtenerPagoReciente(
    Map<String, dynamic> solicitud,
  ) {
    final pagos = solicitud['pagos'];

    if (pagos == null) return null;

    if (pagos is Map<String, dynamic>) {
      return pagos;
    }

    if (pagos is! List || pagos.isEmpty) {
      return null;
    }

    final listaPagos = List<Map<String, dynamic>>.from(
      pagos.map((pago) => Map<String, dynamic>.from(pago)),
    );

    listaPagos.sort((a, b) {
      final fechaA = DateTime.tryParse(
        a['fecha_registro']?.toString() ?? '',
      );

      final fechaB = DateTime.tryParse(
        b['fecha_registro']?.toString() ?? '',
      );

      if (fechaA == null && fechaB == null) return 0;
      if (fechaA == null) return 1;
      if (fechaB == null) return -1;

      return fechaB.compareTo(fechaA);
    });

    return listaPagos.first;
  }

  // Interpreta las fechas del periodo sin alterar la fecha del calendario.
  DateTime? convertirFechaCalendario(dynamic fecha) {
    if (fecha == null) return null;

    final texto = fecha.toString();

    if (texto.length < 10) return null;

    return DateTime.tryParse(texto.substring(0, 10));
  }

  // Determina el estado del curso con las fechas reales del periodo.
  String obtenerEstadoCurso(Map<String, dynamic> solicitud) {
    final periodo =
        solicitud['datos_periodo'] as Map<String, dynamic>?;

    if (periodo == null) {
      return 'Pago confirmado';
    }

    final fechaInicio =
        convertirFechaCalendario(periodo['fecha_inicio']);

    final fechaFin =
        convertirFechaCalendario(periodo['fecha_fin']);

    if (fechaInicio == null || fechaFin == null) {
      return 'Pago confirmado';
    }

    final ahora = DateTime.now();

    // Se compara únicamente el día, sin considerar las horas.
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);

    if (hoy.isBefore(fechaInicio)) {
      return 'Pendiente de inicio';
    }

    if (hoy.isAfter(fechaFin)) {
      return 'Curso finalizado';
    }

    return 'Curso activo';
  }

  // Obtiene el estado que debe mostrarse al estudiante.
  String obtenerEstadoVisible(Map<String, dynamic> solicitud) {
    // IMPORTANTE:
    // El estado de la solicitud tiene prioridad sobre el pago.
    // Esto evita que un examen pagado siga apareciendo como
    // "Pago confirmado" cuando su periodo ya venció.
    final estadoSolicitud = solicitud['estado']?.toString();

    if (estadoSolicitud == 'Periodo vencido') {
      return 'Periodo vencido';
    }

    if (estadoSolicitud == 'Cancelada' ||
        estadoSolicitud == 'Rechazada') {
      return estadoSolicitud!;
    }

    final pago = obtenerPagoReciente(solicitud);

    if (pago == null) {
      return estadoSolicitud ?? 'Pendiente';
    }

    final estadoPago = pago['estado']?.toString();
    final tipoPago = pago['tipo_pago']?.toString();

    switch (estadoPago) {
      case 'Pendiente de revisión':
        return 'Revisión de pago';

      case 'Rechazado':
        return 'Pago rechazado';

      case 'Confirmado':
        // Solamente los pagos de curso se relacionan
        // con el inicio y finalización de una inscripción.
        if (tipoPago == 'Curso' &&
            solicitud['estado_inscripcion'] == 'Activa') {
          return obtenerEstadoCurso(solicitud);
        }

        // Un pago confirmado de examen no significa que
        // el alumno ya esté inscrito en un curso.
        return 'Pago confirmado';

      default:
        return estadoSolicitud ?? 'Pendiente';
    }
  }

  // Obtiene el motivo o las notas del coordinador.
  String? obtenerNotaPago(Map<String, dynamic> solicitud) {
    final pago = obtenerPagoReciente(solicitud);

    if (pago == null) return null;

    final nota = pago['notas_coordinador']?.toString().trim();

    if (nota == null || nota.isEmpty) {
      return null;
    }

    return nota;
  }

  // Indica si un comprobante rechazado fue enviado nuevamente.
  bool pagoReenviado(Map<String, dynamic> solicitud) {
    final pago = obtenerPagoReciente(solicitud);

    if (pago == null) return false;

    return pago['estado'] == 'Pendiente de revisión' &&
        obtenerNotaPago(solicitud) != null;
  }

  // Explica el estado actual de la solicitud.
  String descripcionEstado(String estado) {
    switch (estado) {
      case 'Pendiente':
        return 'Tu solicitud fue registrada y está pendiente de revisión por CELEX.';

      case 'En revisión':
        return 'CELEX está revisando la información de tu solicitud.';

      case 'Esperando grupo':
        return 'Tu solicitud está registrada. Debes esperar la confirmación de apertura de un grupo.';

      case 'Pendiente de pago':
        return 'Tu solicitud fue autorizada para continuar. Consulta las instrucciones de pago y realiza el trámite correspondiente.';

      case 'Revisión de pago':
        return 'Tu comprobante fue enviado correctamente. El coordinador está revisando tu pago.';

      case 'Pago rechazado':
        return 'Tu comprobante fue rechazado. Revisa el motivo indicado y vuelve a enviar tu comprobante desde la sección de pagos.';

      case 'Pago confirmado':
        return 'Tu pago fue confirmado. Consulta el siguiente paso de tu proceso de inscripción.';

      case 'Periodo vencido':
        return 'El periodo terminó y no se abrió un grupo para esta solicitud. Conservamos el resultado de tu examen de colocación para que puedas continuar desde el nivel asignado cuando se abra un nuevo periodo.';

      case 'Pendiente de inicio':
        return 'Tu pago fue confirmado y tu inscripción está activa. El curso todavía no comienza.';

      case 'Curso activo':
        return 'Tu curso se encuentra dentro de las fechas establecidas para este periodo.';

      case 'Curso finalizado':
        return 'El periodo de tu curso ya terminó. Consulta tu resultado académico en la sección de calificaciones.';

      case 'Aceptada':
        return 'Tu solicitud fue aceptada por CELEX.';

      case 'Rechazada':
        return 'Tu solicitud fue rechazada. Revisa las observaciones registradas por CELEX.';

      case 'Cancelada':
        return 'Esta solicitud fue cancelada.';

      case 'Finalizado':
        return 'Tu curso ha finalizado. Consulta tu resultado académico en la sección de calificaciones.';

      default:
        return 'Consulta con CELEX para conocer más detalles de tu solicitud.';
    }
  }

  // Selecciona un color según el estado.
  Color colorEstado(String estado) {
    switch (estado) {
      case 'Pago confirmado':
      case 'Curso activo':
      case 'Curso finalizado':
      case 'Finalizado':
      case 'Aceptada':
        return const Color(0xFF187545);

      case 'Rechazada':
      case 'Pago rechazado':
      case 'Cancelada':
        return const Color(0xFFB42318);

      case 'Pendiente de pago':
      case 'Revisión de pago':
      case 'Pendiente de inicio':
        return const Color(0xFF9A6700);

      case 'Esperando grupo':
        return const Color(0xFF7952A0);

      case 'Periodo vencido':
        return const Color(0xFF456A9D);

      default:
        return const Color(0xFF456A9D);
    }
  }

  // Obtiene el idioma de la solicitud.
  String obtenerIdioma(Map<String, dynamic> solicitud) {
    final idioma = solicitud['idiomas'];

    if (idioma == null) return 'No disponible';

    return idioma['nombre']?.toString() ?? 'No disponible';
  }

  // Obtiene el nivel correspondiente.
  String obtenerNivel(Map<String, dynamic> solicitud) {
    final esExamen =
        solicitud['tipo_tramite'] == 'Examen de colocación';

    if (esExamen) {
      final nivelAsignado =
          solicitud['nivel_asignado'] as Map<String, dynamic>?;

      final nivelObtenido =
          solicitud['nivel_obtenido'] as Map<String, dynamic>?;

      // Si el coordinador asignó un nivel diferente al obtenido,
      // mostramos el nivel asignado, que es el que debe conservarse.
      if (nivelAsignado != null) {
        return nivelAsignado['nombre'].toString();
      }

      if (nivelObtenido != null) {
        return nivelObtenido['nombre'].toString();
      }

      return 'Por determinar mediante examen';
    }

    final nivel =
        solicitud['nivel_solicitado'] as Map<String, dynamic>?;

    if (nivel == null) return 'No disponible';

    return nivel['nombre'].toString();
  }

  // Construye el nombre que aparecerá en la ficha.
  String obtenerNombreFicha(Map<String, dynamic> solicitud) {
    final idioma = obtenerIdioma(solicitud);
    final esExamen =
        solicitud['tipo_tramite'] == 'Examen de colocación';

    if (esExamen) {
      return 'Examen de colocación · $idioma';
    }

    return '$idioma · ${obtenerNivel(solicitud)}';
  }

  // Obtiene el horario asignado al examen.
  Map<String, dynamic>? obtenerHorario(
    Map<String, dynamic> solicitud,
  ) {
    final horario = solicitud['horarios_examen_colocacion'];

    if (horario == null) return null;

    if (horario is Map<String, dynamic>) {
      return horario;
    }

    if (horario is List && horario.isNotEmpty) {
      return Map<String, dynamic>.from(horario.first);
    }

    return null;
  }

  // Construye una ficha desplegable de solicitud.
  Widget construirTarjeta(Map<String, dynamic> solicitud) {
    final estado = obtenerEstadoVisible(solicitud);
    final color = colorEstado(estado);

    final folio = 'SOL-${solicitud['id'].toString().padLeft(4, '0')}';

    final esExamen =
        solicitud['tipo_tramite'] == 'Examen de colocación';

    final horario = obtenerHorario(solicitud);
    final notaPago = obtenerNotaPago(solicitud);
    final fueReenviado = pagoReenviado(solicitud);

    final periodo =
        solicitud['datos_periodo'] as Map<String, dynamic>?;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFD9E4F3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),

      // Al tocar la ficha se despliega toda su información.
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          childrenPadding: const EdgeInsets.fromLTRB(
            16,
            0,
            16,
            17,
          ),
          leading: Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: fondoHistorial,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              esExamen
                  ? Icons.assignment_outlined
                  : Icons.menu_book_outlined,
              color: azulHistorial,
              size: 25,
            ),
          ),

          // Nombre del curso y estado siempre visibles.
          title: Text(
            obtenerNombreFicha(solicitud),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: azulHistorial,
            ),
          ),

          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  folio,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 7),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    estado,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Información que aparece al abrir la ficha.
          children: [
            const Divider(height: 20),

            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Información de la solicitud',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: azulHistorial,
                ),
              ),
            ),

            const SizedBox(height: 14),

            _DatoSolicitud(
              etiqueta: 'Trámite',
              valor: solicitud['tipo_tramite']?.toString() ??
                  'No disponible',
            ),

            const SizedBox(height: 10),

            _DatoSolicitud(
              etiqueta: 'Idioma',
              valor: obtenerIdioma(solicitud),
            ),

            const SizedBox(height: 10),

            _DatoSolicitud(
              etiqueta: 'Nivel',
              valor: obtenerNivel(solicitud),
            ),

            const SizedBox(height: 10),

            _DatoSolicitud(
              etiqueta: 'Fecha',
              valor: formatearFecha(solicitud['fecha_solicitud']),
            ),

            if (periodo != null) ...[
              const SizedBox(height: 10),
              _DatoSolicitud(
                etiqueta: 'Periodo',
                valor: periodo['nombre']?.toString() ??
                    'No disponible',
              ),
              const SizedBox(height: 10),
              _DatoSolicitud(
                etiqueta: 'Inicio del curso',
                valor: formatearFecha(periodo['fecha_inicio']),
              ),
              const SizedBox(height: 10),
              _DatoSolicitud(
                etiqueta: 'Fin del curso',
                valor: formatearFecha(periodo['fecha_fin']),
              ),
            ],

            // Información del examen de colocación.
            if (esExamen &&
                solicitud['horario_examen_id'] != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: fondoHistorial,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.event_available,
                          color: azulHistorial,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Horario de examen asignado',
                            style: TextStyle(
                              color: azulHistorial,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (horario != null) ...[
                      _DatoSolicitud(
                        etiqueta: 'Hora de inicio',
                        valor: formatearHora(
                          horario['hora_inicio'],
                        ),
                      ),
                      const SizedBox(height: 8),
                      _DatoSolicitud(
                        etiqueta: 'Hora de término',
                        valor: formatearHora(
                          horario['hora_fin'],
                        ),
                      ),
                    ] else
                      const Text(
                        'Tu horario fue asignado. Consulta con CELEX los detalles.',
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 13,
                        ),
                      ),
                  ],
                ),
              ),
            ],

            // Observaciones de la solicitud.
            if (solicitud['observaciones'] != null &&
                solicitud['observaciones']
                    .toString()
                    .trim()
                    .isNotEmpty) ...[
              const SizedBox(height: 14),
              _DatoSolicitud(
                etiqueta: 'Observaciones',
                valor: solicitud['observaciones'].toString(),
              ),
            ],

            // Motivo del rechazo o nota del coordinador.
            if (notaPago != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4E5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFF2D3A2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: Color(0xFF9A6700),
                          size: 19,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            fueReenviado
                                ? 'El pago fue rechazado anteriormente.'
                                : 'Nota del coordinador:',
                            style: const TextStyle(
                              color: Color(0xFF805500),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      notaPago,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Explicación del estado.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: fondoHistorial,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    color: color,
                    size: 19,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      descripcionEstado(estado),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: fondoHistorial,

      // Barra superior.
      appBar: AppBar(
        title: const Text('Mis solicitudes'),
        backgroundColor: azulHistorial,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: () {
              setState(cargarSolicitudes);
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),

      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: futureSolicitudes,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: azulHistorial,
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: azulHistorial,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No se pudieron cargar tus solicitudes.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(cargarSolicitudes);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: azulHistorial,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            );
          }

          final solicitudes = snapshot.data ?? [];

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Historial de solicitudes',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: azulHistorial,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Consulta tus cursos y trámites de CELEX ESCOM. '
                'Selecciona una ficha para ver sus detalles.',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.black54,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 24),

              if (solicitudes.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFD9E4F3),
                    ),
                  ),
                  child: const Column(
                    children: [
                      Icon(
                        Icons.inbox_outlined,
                        color: azulHistorial,
                        size: 55,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Todavía no tienes solicitudes',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: azulHistorial,
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Cuando realices un trámite desde '
                        'Idiomas disponibles, aparecerá aquí.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.black54,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
                Text(
                  'Solicitudes registradas: ${solicitudes.length}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: azulHistorial,
                  ),
                ),

                const SizedBox(height: 14),

                // Mostrar primero las solicitudes más recientes.
                ...solicitudes.map(construirTarjeta),
              ],

              const SizedBox(height: 12),

              const Center(
                child: Text(
                  'CELEX ESCOM · IPN',
                  style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 1.2,
                    color: Colors.black45,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// Fila para mostrar un dato de la solicitud.
class _DatoSolicitud extends StatelessWidget {
  final String etiqueta;
  final String valor;

  const _DatoSolicitud({
    required this.etiqueta,
    required this.valor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 115,
          child: Text(
            etiqueta,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 13,
            ),
          ),
        ),
        Expanded(
          child: Text(
            valor,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}
