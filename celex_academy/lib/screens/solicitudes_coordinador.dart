
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Colores institucionales de CELEX Academy.
const Color azulSolicitudesCoord = Color(0xFF023C87);
const Color fondoSolicitudesCoord = Color(0xFFEAF1FB);

class SolicitudesCoordinador extends StatefulWidget {
  const SolicitudesCoordinador({super.key});

  @override
  State<SolicitudesCoordinador> createState() =>
      _SolicitudesCoordinadorState();
}

class _SolicitudesCoordinadorState extends State<SolicitudesCoordinador> {
  final supabase = Supabase.instance.client;

  bool cargandoPeriodos = true;

  List<Map<String, dynamic>> periodos = [];
  int? periodoSeleccionadoId;

  late Future<List<Map<String, dynamic>>> futurasSolicitudes;

  // Estados que indican que un periodo está en operación.
  final List<String> estadosPeriodoActivo = [
    'Inscripciones',
    'Colocacion',
    'Distribucion',
    'Pagos',
    'En curso',
  ];

  @override
  void initState() {
    super.initState();
    futurasSolicitudes = Future.value([]);
    cargarPeriodos();
  }

  // =========================================================
  // PERIODOS
  // =========================================================

  // Carga los periodos y selecciona automáticamente el actual.
  Future<void> cargarPeriodos() async {
    try {
      final respuesta = await supabase
          .from('periodos')
          .select('id, nombre, fecha_inicio, estado')
          .order('fecha_inicio', ascending: false);

      final lista = List<Map<String, dynamic>>.from(respuesta);

      int? periodoActualId;

      if (lista.isNotEmpty) {
        // Primero se busca un periodo que esté en una etapa activa.
        final periodoActivo = lista.where((periodo) {
          return estadosPeriodoActivo.contains(
            periodo['estado']?.toString(),
          );
        }).firstOrNull;

        // Si no hay uno activo, se toma el periodo más reciente.
        final periodoElegido = periodoActivo ?? lista.first;

        periodoActualId = (periodoElegido['id'] as num).toInt();
      }

      if (!mounted) return;

      setState(() {
        periodos = lista;
        periodoSeleccionadoId = periodoActualId;
        cargandoPeriodos = false;
      });

      if (periodoActualId != null) {
        setState(() {
          futurasSolicitudes = obtenerSolicitudes(periodoActualId!);
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        cargandoPeriodos = false;
      });

      mostrarMensaje('No se pudieron cargar los periodos: $e');
    }
  }

  // Cambia el periodo seleccionado y carga sus solicitudes.
  void cambiarPeriodo(int? nuevoPeriodoId) {
    if (nuevoPeriodoId == null ||
        nuevoPeriodoId == periodoSeleccionadoId) {
      return;
    }

    setState(() {
      periodoSeleccionadoId = nuevoPeriodoId;
      futurasSolicitudes = obtenerSolicitudes(nuevoPeriodoId);
    });
  }

  // Nombre del periodo seleccionado.
  String obtenerNombrePeriodo() {
    final periodo = periodos.firstWhere(
      (p) => (p['id'] as num).toInt() == periodoSeleccionadoId,
      orElse: () => {},
    );

    return periodo['nombre']?.toString() ?? 'Periodo seleccionado';
  }

  // =========================================================
  // SOLICITUDES
  // =========================================================

  // Consulta únicamente las solicitudes del periodo seleccionado.
  Future<List<Map<String, dynamic>>> obtenerSolicitudes(
    int periodoId,
  ) async {
    final respuesta = await supabase
        .from('solicitudes')
        .select('''
          id,
          estudiante_id,
          idioma_id,
          tipo_tramite,
          estado,
          fecha_solicitud,
          observaciones,
          periodo_id,
          horario_examen_id,
          nivel_obtenido_id,
          nivel_asignado_id,
          calificacion_examen,
          motivo_asignacion,
          idiomas(nombre),
          nivel_solicitado:niveles!solicitudes_nivel_id_fkey(nombre, orden),
          nivel_obtenido:niveles!solicitudes_nivel_obtenido_id_fkey(nombre, orden),
          nivel_asignado:niveles!solicitudes_nivel_asignado_id_fkey(nombre, orden),
          perfiles_estudiantes(nombre_completo, correo)
        ''')
        .eq('periodo_id', periodoId)
        .order('fecha_solicitud', ascending: false);

    final solicitudes = List<Map<String, dynamic>>.from(respuesta);

    // Obtener todos los horarios asignados en una sola consulta.
    final horariosIds = solicitudes
        .map((s) => s['horario_examen_id'])
        .where((id) => id != null)
        .map((id) => (id as num).toInt())
        .toSet()
        .toList();

    final Map<int, Map<String, dynamic>> horariosPorId = {};

    if (horariosIds.isNotEmpty) {
      final respuestaHorarios = await supabase
          .from('horarios_examen_colocacion')
          .select('id, hora_inicio, hora_fin, cupo_maximo, activo')
          .inFilter('id', horariosIds);

      for (final horario in respuestaHorarios) {
        horariosPorId[(horario['id'] as num).toInt()] =
            Map<String, dynamic>.from(horario);
      }
    }

    // Asociar cada horario con su solicitud.
    for (final solicitud in solicitudes) {
      final horarioId = solicitud['horario_examen_id'];

      solicitud['horario_examen'] = horarioId == null
          ? null
          : horariosPorId[(horarioId as num).toInt()];
    }

    return solicitudes;
  }

  // Actualizar la lista del periodo actual.
  Future<void> actualizarSolicitudes() async {
    final periodoId = periodoSeleccionadoId;

    if (periodoId == null) return;

    setState(() {
      futurasSolicitudes = obtenerSolicitudes(periodoId);
    });

    await futurasSolicitudes;
  }

  // =========================================================
  // UTILIDADES
  // =========================================================

  void mostrarMensaje(String mensaje) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje)),
    );
  }

  Color obtenerColorEstado(String estado) {
    switch (estado) {
      case 'Aceptada':
      case 'Pago confirmado':
      case 'Activa':
        return Colors.green;

      case 'Rechazada':
      case 'Cancelada':
        return Colors.red;

      case 'Pendiente de pago':
      case 'Esperando grupo':
        return Colors.orange;

      case 'En revisión':
        return Colors.blue;

      default:
        return Colors.grey;
    }
  }

  String formatearFecha(dynamic fecha) {
    if (fecha == null) return 'Sin fecha';

    final date = DateTime.parse(fecha.toString()).toLocal();

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String formatearHora(dynamic hora) {
    if (hora == null) return '--:--';

    final texto = hora.toString();

    return texto.length >= 5 ? texto.substring(0, 5) : texto;
  }

  bool esExamenColocacion(Map<String, dynamic> solicitud) {
    return solicitud['tipo_tramite'] == 'Examen de colocación';
  }

  String obtenerIdioma(Map<String, dynamic> solicitud) {
    final idioma =
        solicitud['idiomas'] as Map<String, dynamic>? ?? {};

    return idioma['nombre']?.toString() ?? 'Idioma no disponible';
  }

  String obtenerNivel(Map<String, dynamic> solicitud) {
    final nivel =
        solicitud['nivel_solicitado'] as Map<String, dynamic>? ?? {};

    return nivel['nombre']?.toString() ?? 'Sin nivel especificado';
  }

  int obtenerOrdenNivel(Map<String, dynamic> solicitud) {
    final nivel =
        solicitud['nivel_solicitado'] as Map<String, dynamic>? ?? {};

    return (nivel['orden'] as num?)?.toInt() ?? 999;
  }

  String obtenerNombreNivel(
    Map<String, dynamic> solicitud,
    String campo,
  ) {
    final nivel = solicitud[campo] as Map<String, dynamic>? ?? {};

    return nivel['nombre']?.toString() ?? 'Sin registrar';
  }

  // =========================================================
  // HORARIOS DE EXAMEN
  // =========================================================

  // Cuenta los estudiantes asignados a un horario.
  Future<int> obtenerAlumnosAsignados(
    int horarioId,
    int solicitudActualId,
  ) async {
    final respuesta = await supabase
        .from('solicitudes')
        .select('id, estado')
        .eq('horario_examen_id', horarioId);

    final asignaciones = List<Map<String, dynamic>>.from(respuesta);

    return asignaciones.where((asignacion) {
      final id = (asignacion['id'] as num).toInt();
      final estado = asignacion['estado']?.toString();

      return id != solicitudActualId &&
          estado != 'Cancelada' &&
          estado != 'Rechazada';
    }).length;
  }

  // Asigna o cambia el horario de un examen de colocación.
  Future<void> asignarHorarioExamen(
    Map<String, dynamic> solicitud,
  ) async {
    try {
      final solicitudId = (solicitud['id'] as num).toInt();
      final periodoId = solicitud['periodo_id'];

      if (periodoId == null) {
        throw Exception('La solicitud no tiene un periodo asignado.');
      }

      final estadoActual = solicitud['estado']?.toString();

      if (estadoActual != 'Pendiente' &&
          estadoActual != 'Pendiente de pago') {
        mostrarMensaje(
          'No se puede modificar el horario porque la solicitud ya avanzó a otra etapa.',
        );
        return;
      }

      // No permitir cambiar el horario si ya hay un pago en proceso.
      final pagos = await supabase
          .from('pagos')
          .select('id, estado')
          .eq('solicitud_id', solicitudId)
          .eq('tipo_pago', 'Examen de colocación');

      final tienePagoEnProceso =
          List<Map<String, dynamic>>.from(pagos).any((pago) {
        final estadoPago = pago['estado']?.toString();

        return estadoPago == 'Pendiente de revisión' ||
            estadoPago == 'Confirmado';
      });

      if (tienePagoEnProceso) {
        mostrarMensaje(
          'No se puede cambiar el horario porque el estudiante ya tiene un pago en proceso o confirmado.',
        );
        return;
      }

      // Consultar los horarios activos del periodo.
      final respuestaHorarios = await supabase
          .from('horarios_examen_colocacion')
          .select('''
            id,
            periodo_id,
            hora_inicio,
            hora_fin,
            cupo_maximo,
            activo
          ''')
          .eq('periodo_id', periodoId)
          .eq('activo', true)
          .order('hora_inicio');

      final horarios =
          List<Map<String, dynamic>>.from(respuestaHorarios);

      if (horarios.isEmpty) {
        mostrarMensaje(
          'Este periodo todavía no tiene horarios de examen activos.',
        );
        return;
      }

      // Consultar la ocupación de los horarios.
      for (final horario in horarios) {
        final horarioId = (horario['id'] as num).toInt();

        horario['alumnos_asignados'] = await obtenerAlumnosAsignados(
          horarioId,
          solicitudId,
        );
      }

      if (!mounted) return;

      int? horarioSeleccionado =
          (solicitud['horario_examen_id'] as num?)?.toInt();

      if (!horarios.any(
        (h) => (h['id'] as num).toInt() == horarioSeleccionado,
      )) {
        horarioSeleccionado = null;
      }

      final int? horarioElegido = await showDialog<int>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (contextDialogo, actualizarDialogo) {
              final horarioActual = horarios.firstWhere(
                (h) =>
                    (h['id'] as num).toInt() == horarioSeleccionado,
                orElse: () => {},
              );

              return AlertDialog(
                title: const Text(
                  'Asignar horario de examen',
                  style: TextStyle(
                    color: azulSolicitudesCoord,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Selecciona uno de los horarios activos del periodo.',
                      ),
                      const SizedBox(height: 15),
                      DropdownButtonFormField<int>(
                        initialValue: horarioSeleccionado,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Horario disponible',
                          border: OutlineInputBorder(),
                        ),
                        items: horarios.map((horario) {
                          final id = (horario['id'] as num).toInt();
                          final inicio =
                              formatearHora(horario['hora_inicio']);
                          final fin =
                              formatearHora(horario['hora_fin']);
                          final ocupados =
                              horario['alumnos_asignados'] as int;
                          final cupo =
                              (horario['cupo_maximo'] as num?)?.toInt();

                          final lugares = cupo == null
                              ? 'Sin límite'
                              : '$ocupados/$cupo ocupados';

                          return DropdownMenuItem<int>(
                            value: id,
                            child: Text(
                              '$inicio - $fin ($lugares)',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (valor) {
                          actualizarDialogo(() {
                            horarioSeleccionado = valor;
                          });
                        },
                      ),
                      if (horarioActual.isNotEmpty) ...[
                        const SizedBox(height: 15),
                        Builder(
                          builder: (context) {
                            final ocupados =
                                horarioActual['alumnos_asignados'] as int;
                            final cupo =
                                (horarioActual['cupo_maximo'] as num?)
                                    ?.toInt();
                            final disponibles =
                                cupo == null ? null : cupo - ocupados;

                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: fondoSolicitudesCoord,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Capacidad del horario',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: azulSolicitudesCoord,
                                    ),
                                  ),
                                  const SizedBox(height: 7),
                                  Text(
                                    cupo == null
                                        ? '$ocupados estudiantes asignados. Sin límite de cupo.'
                                        : '$ocupados de $cupo lugares ocupados.',
                                  ),
                                  if (disponibles != null)
                                    Text(
                                      disponibles > 0
                                          ? 'Lugares disponibles: $disponibles'
                                          : 'No hay lugares disponibles.',
                                      style: TextStyle(
                                        color: disponibles > 0
                                            ? Colors.green
                                            : Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Cancelar'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: azulSolicitudesCoord,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      if (horarioSeleccionado == null) {
                        ScaffoldMessenger.of(contextDialogo).showSnackBar(
                          const SnackBar(
                            content: Text('Selecciona un horario.'),
                          ),
                        );
                        return;
                      }

                      final horario = horarios.firstWhere(
                        (h) =>
                            (h['id'] as num).toInt() ==
                            horarioSeleccionado,
                      );

                      final ocupados =
                          horario['alumnos_asignados'] as int;
                      final cupo =
                          (horario['cupo_maximo'] as num?)?.toInt();

                      if (cupo != null && ocupados >= cupo) {
                        ScaffoldMessenger.of(contextDialogo).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Este horario ya no tiene lugares disponibles.',
                            ),
                          ),
                        );
                        return;
                      }

                      Navigator.pop(dialogContext, horarioSeleccionado);
                    },
                    child: const Text('Continuar'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (horarioElegido == null) return;

      // Volver a comprobar la capacidad antes de guardar.
      final ocupadosActualizados = await obtenerAlumnosAsignados(
        horarioElegido,
        solicitudId,
      );

      final horarioElegidoDatos = horarios.firstWhere(
        (h) => (h['id'] as num).toInt() == horarioElegido,
      );

      final cupoElegido =
          (horarioElegidoDatos['cupo_maximo'] as num?)?.toInt();

      if (cupoElegido != null &&
          ocupadosActualizados >= cupoElegido) {
        mostrarMensaje(
          'El horario acaba de llenarse. Selecciona otro horario disponible.',
        );
        return;
      }

      // Guardar el horario y actualizar el estado de la solicitud.
      await supabase.from('solicitudes').update({
        'horario_examen_id': horarioElegido,
        'estado': 'Pendiente de pago',
      }).eq('id', solicitudId);

      if (!mounted) return;

      mostrarMensaje(
        'Horario asignado correctamente. La solicitud ahora está pendiente de pago.',
      );

      await actualizarSolicitudes();
    } catch (e) {
      mostrarMensaje('No se pudo asignar el horario: $e');
    }
  }

  // =========================================================
  // RESULTADOS DE EXAMEN
  // =========================================================

  // Registra o edita el resultado de un examen de colocación.
  // No modifica el estado de la solicitud: después del resultado todavía
  // debe realizarse la asignación de grupo y el pago del curso.
  Future<void> registrarResultadoExamen(
    Map<String, dynamic> solicitud,
  ) async {
    TextEditingController? calificacionController;
    TextEditingController? motivoController;

    try {
      // Convertir y validar los identificadores antes de consultar Supabase.
      final idSolicitud = (solicitud['id'] as num?)?.toInt();
      final idiomaId = (solicitud['idioma_id'] as num?)?.toInt();

      if (idSolicitud == null || idiomaId == null) {
        throw Exception(
          'La solicitud no contiene un identificador o idioma válido.',
        );
      }

      // Comprobar que exista al menos un pago confirmado del examen.
      // limit(1) evita errores de maybeSingle si por alguna prueba anterior
      // hubiera más de un pago confirmado asociado a la misma solicitud.
      final pago = await supabase
          .from('pagos')
          .select('id')
          .eq('solicitud_id', idSolicitud)
          .eq('tipo_pago', 'Examen de colocación')
          .eq('estado', 'Confirmado')
          .limit(1)
          .maybeSingle();

      if (pago == null) {
        mostrarMensaje(
          'No se puede registrar el resultado: el examen todavía no tiene un pago confirmado.',
        );
        return;
      }

      // Consultar los niveles activos correspondientes al idioma del examen.
      final respuestaNiveles = await supabase
          .from('niveles')
          .select('id, nombre, orden')
          .eq('idioma_id', idiomaId)
          .eq('activo', true)
          .order('orden');

      final niveles = List<Map<String, dynamic>>.from(respuestaNiveles);

      if (niveles.isEmpty) {
        throw Exception('No hay niveles activos para este idioma.');
      }

      // Preparar una lista limpia de niveles con identificadores válidos.
      final nivelesValidos = niveles.where((nivel) {
        return nivel['id'] is num &&
            nivel['nombre'] != null &&
            nivel['nombre'].toString().trim().isNotEmpty;
      }).toList();

      if (nivelesValidos.isEmpty) {
        throw Exception('No se encontraron niveles válidos para este idioma.');
      }

      final idsNiveles = nivelesValidos
          .map((nivel) => (nivel['id'] as num).toInt())
          .toSet();

      calificacionController = TextEditingController(
        text: solicitud['calificacion_examen']?.toString() ?? '',
      );

      motivoController = TextEditingController(
        text: solicitud['motivo_asignacion']?.toString() ?? '',
      );

      // Conservar los niveles guardados si siguen activos para ese idioma.
      int? nivelObtenidoId =
          (solicitud['nivel_obtenido_id'] as num?)?.toInt();
      int? nivelAsignadoId =
          (solicitud['nivel_asignado_id'] as num?)?.toInt();

      if (nivelObtenidoId == null || !idsNiveles.contains(nivelObtenidoId)) {
        nivelObtenidoId = null;
      }

      if (nivelAsignadoId == null || !idsNiveles.contains(nivelAsignadoId)) {
        nivelAsignadoId = null;
      }

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          bool guardandoResultado = false;

          return StatefulBuilder(
            builder: (contextDialogo, actualizarDialogo) {
              // Se calculan las opciones una sola vez a partir de los niveles
              // validados, para evitar valores iniciales que no existan.
              final opcionesNiveles = nivelesValidos.map((nivel) {
                final idNivel = (nivel['id'] as num).toInt();
                return DropdownMenuItem<int>(
                  value: idNivel,
                  child: Text(
                    nivel['nombre'].toString(),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList();

              Future<void> guardarResultado() async {
                if (guardandoResultado) return;

                final calificacion = double.tryParse(
                  calificacionController!.text
                      .trim()
                      .replaceAll(',', '.'),
                );

                if (nivelObtenidoId == null ||
                    nivelAsignadoId == null ||
                    calificacion == null ||
                    calificacion < 0 ||
                    calificacion > 100) {
                  ScaffoldMessenger.of(contextDialogo).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Selecciona ambos niveles e ingresa una calificación entre 0 y 100.',
                      ),
                    ),
                  );
                  return;
                }

                final motivo = motivoController!.text.trim();

                if (nivelObtenidoId != nivelAsignadoId && motivo.isEmpty) {
                  ScaffoldMessenger.of(contextDialogo).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Escribe el motivo del cambio de nivel.',
                      ),
                    ),
                  );
                  return;
                }

                actualizarDialogo(() {
                  guardandoResultado = true;
                });

                try {
                  // Guardar únicamente el resultado académico del examen.
                  // El estado de la solicitud se conserva para que continúe
                  // el flujo normal de asignación de grupo y pago del curso.
                  final respuestaActualizacion = await supabase
                      .from('solicitudes')
                      .update({
                        'nivel_obtenido_id': nivelObtenidoId,
                        'nivel_asignado_id': nivelAsignadoId,
                        'calificacion_examen': calificacion,
                        'motivo_asignacion':
                            nivelObtenidoId == nivelAsignadoId ? null : motivo,
                      })
                      .eq('id', idSolicitud)
                      .select('id')
                      .maybeSingle();

                  if (respuestaActualizacion == null) {
                    throw Exception(
                      'No se actualizó la solicitud. Verifica los permisos de coordinación y que la solicitud siga existiendo.',
                    );
                  }

                  if (!contextDialogo.mounted) return;

                  Navigator.of(contextDialogo).pop();

                  if (!mounted) return;

                  mostrarMensaje(
                    'Resultado del examen guardado correctamente.',
                  );

                  await actualizarSolicitudes();
                } catch (e) {
                  if (!contextDialogo.mounted) return;

                  actualizarDialogo(() {
                    guardandoResultado = false;
                  });

                  ScaffoldMessenger.of(contextDialogo).showSnackBar(
                    SnackBar(
                      content: Text('No se pudo guardar el resultado: $e'),
                    ),
                  );
                }
              }

              return AlertDialog(
                title: const Text(
                  'Resultado del examen',
                  style: TextStyle(
                    color: azulSolicitudesCoord,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Nivel obtenido en el examen',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int>(
                        initialValue: nivelObtenidoId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'Selecciona el nivel obtenido',
                        ),
                        items: opcionesNiveles,
                        onChanged: guardandoResultado
                            ? null
                            : (valor) {
                                actualizarDialogo(() {
                                  nivelObtenidoId = valor;
                                  nivelAsignadoId ??= valor;
                                });
                              },
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Calificación del examen',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: calificacionController,
                        enabled: !guardandoResultado,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'Ingresa una calificación de 0 a 100',
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Nivel que se asignará al estudiante',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int>(
                        initialValue: nivelAsignadoId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'Selecciona el nivel asignado',
                        ),
                        items: opcionesNiveles,
                        onChanged: guardandoResultado
                            ? null
                            : (valor) {
                                actualizarDialogo(() {
                                  nivelAsignadoId = valor;
                                });
                              },
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Motivo interno de la asignación',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'Este dato solamente será visible para coordinación.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: motivoController,
                        enabled: !guardandoResultado,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText:
                              'Escribe el motivo si asignas otro nivel...',
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: guardandoResultado
                        ? null
                        : () => Navigator.of(dialogContext).pop(),
                    child: const Text('Cancelar'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: azulSolicitudesCoord,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: guardandoResultado ? null : guardarResultado,
                    child: guardandoResultado
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Guardar resultado'),
                  ),
                ],
              );
            },
          );
        },
      );
    } catch (e) {
      mostrarMensaje('Error al preparar el examen: $e');
    } finally {
      calificacionController?.dispose();
      motivoController?.dispose();
    }
  }

  // =========================================================
  // TARJETAS DE SOLICITUDES
  // =========================================================

  Widget construirSolicitud(Map<String, dynamic> solicitud) {
    final estudiante =
        solicitud['perfiles_estudiantes'] as Map<String, dynamic>? ?? {};

    final nivelAsignado =
        solicitud['nivel_asignado'] as Map<String, dynamic>? ?? {};

    final estado = solicitud['estado']?.toString() ?? 'Pendiente';
    final id = solicitud['id'];

    final nombreNivelAsignado = nivelAsignado['nombre']?.toString();
    final esExamen = esExamenColocacion(solicitud);

    final nivelObtenido = obtenerNombreNivel(
      solicitud,
      'nivel_obtenido',
    );

    final calificacion = solicitud['calificacion_examen'];

    final horario =
        solicitud['horario_examen'] as Map<String, dynamic>?;

    final puedeAsignarHorario =
        estado == 'Pendiente' || estado == 'Pendiente de pago';

    return Card(
      color: Colors.white,
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'SOL-${id.toString().padLeft(4, '0')}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: azulSolicitudesCoord,
                    fontSize: 15,
                  ),
                ),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: obtenerColorEstado(estado)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      estado,
                      style: TextStyle(
                        color: obtenerColorEstado(estado),
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 22),
            const Text(
              'Estudiante',
              style: TextStyle(
                color: azulSolicitudesCoord,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              estudiante['nombre_completo'] ?? 'Nombre no disponible',
            ),
            Text(
              estudiante['correo'] ?? 'Correo no disponible',
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 12),
            const Text(
              'Información de la solicitud',
              style: TextStyle(
                color: azulSolicitudesCoord,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Trámite: ${solicitud['tipo_tramite'] ?? 'No disponible'}',
            ),
            Text('Idioma: ${obtenerIdioma(solicitud)}'),
            Text('Nivel solicitado: ${obtenerNivel(solicitud)}'),

            // Información adicional exclusiva de exámenes.
            if (esExamen && horario != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: fondoSolicitudesCoord,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.schedule,
                      color: azulSolicitudesCoord,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Horario asignado: '
                        '${formatearHora(horario['hora_inicio'])} - '
                        '${formatearHora(horario['hora_fin'])}',
                        style: const TextStyle(
                          color: azulSolicitudesCoord,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (esExamen && horario == null)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Todavía no tiene un horario de examen asignado.',
                  style: TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

            if (esExamen && solicitud['nivel_obtenido_id'] != null)
              Text(
                'Nivel obtenido: $nivelObtenido',
                style: const TextStyle(
                  color: azulSolicitudesCoord,
                  fontWeight: FontWeight.bold,
                ),
              ),

            if (esExamen && calificacion != null)
              Text('Calificación del examen: $calificacion'),

            if (esExamen && nombreNivelAsignado != null)
              Text(
                'Nivel asignado: $nombreNivelAsignado',
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),

            Text(
              'Fecha: ${formatearFecha(solicitud['fecha_solicitud'])}',
            ),

            if (solicitud['observaciones'] != null &&
                solicitud['observaciones'].toString().isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text(
                'Observaciones:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(solicitud['observaciones'].toString()),
            ],

            // Los botones de modificación solo aparecen en exámenes.
            if (esExamen) ...[
              const SizedBox(height: 14),
              if (puedeAsignarHorario)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => asignarHorarioExamen(solicitud),
                    icon: const Icon(Icons.schedule),
                    label: Text(
                      horario == null
                          ? 'Asignar horario de examen'
                          : 'Cambiar horario de examen',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => registrarResultadoExamen(solicitud),
                  icon: const Icon(Icons.assignment_turned_in_outlined),
                  label: Text(
                    solicitud['nivel_obtenido_id'] == null
                        ? 'Registrar resultado del examen'
                        : 'Editar resultado del examen',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: azulSolicitudesCoord,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // =========================================================
  // APARTADO DE EXÁMENES
  // =========================================================

  Widget construirApartadoExamenes(
    List<Map<String, dynamic>> examenes,
  ) {
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: ExpansionTile(
        initiallyExpanded: false,
        leading: const Icon(
          Icons.assignment_turned_in_outlined,
          color: azulSolicitudesCoord,
          size: 30,
        ),
        title: const Text(
          'Exámenes de colocación',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: azulSolicitudesCoord,
          ),
        ),
        subtitle: Text('${examenes.length} solicitudes'),
        childrenPadding: const EdgeInsets.all(12),
        children: examenes.map(construirSolicitud).toList(),
      ),
    );
  }

  // =========================================================
  // APARTADO DE CURSOS
  // =========================================================

  // Agrupa las solicitudes de cursos por idioma y nivel.
  Widget construirApartadoCursos(
    List<Map<String, dynamic>> solicitudesCursos,
  ) {
    final Map<String, List<Map<String, dynamic>>> porIdioma = {};

    for (final solicitud in solicitudesCursos) {
      final idioma = obtenerIdioma(solicitud);

      porIdioma.putIfAbsent(idioma, () => []);
      porIdioma[idioma]!.add(solicitud);
    }

    final idiomasOrdenados = porIdioma.keys.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 12, top: 5),
          child: Text(
            'Solicitudes de cursos',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: azulSolicitudesCoord,
            ),
          ),
        ),
        ...idiomasOrdenados.map((idioma) {
          final solicitudesIdioma = porIdioma[idioma]!;

          final Map<String, List<Map<String, dynamic>>> porNivel = {};

          for (final solicitud in solicitudesIdioma) {
            final nivel = obtenerNivel(solicitud);

            porNivel.putIfAbsent(nivel, () => []);
            porNivel[nivel]!.add(solicitud);
          }

          final nivelesOrdenados = porNivel.keys.toList();

          nivelesOrdenados.sort((a, b) {
            final ordenA = porNivel[a]!
                .map(obtenerOrdenNivel)
                .reduce((x, y) => x < y ? x : y);

            final ordenB = porNivel[b]!
                .map(obtenerOrdenNivel)
                .reduce((x, y) => x < y ? x : y);

            return ordenA.compareTo(ordenB);
          });

          return Card(
            color: Colors.white,
            margin: const EdgeInsets.only(bottom: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: ExpansionTile(
              initiallyExpanded: false,
              leading: const Icon(
                Icons.language,
                color: azulSolicitudesCoord,
                size: 30,
              ),
              title: Text(
                idioma,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: azulSolicitudesCoord,
                  fontSize: 17,
                ),
              ),
              subtitle: Text(
                '${solicitudesIdioma.length} solicitudes',
              ),
              childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              children: nivelesOrdenados.map((nivel) {
                final solicitudesNivel = porNivel[nivel]!;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: fondoSolicitudesCoord,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ExpansionTile(
                    initiallyExpanded: false,
                    leading: const Icon(
                      Icons.school_outlined,
                      color: azulSolicitudesCoord,
                    ),
                    title: Text(
                      nivel,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: azulSolicitudesCoord,
                      ),
                    ),
                    subtitle: Text(
                      '${solicitudesNivel.length} estudiantes',
                    ),
                    childrenPadding: const EdgeInsets.all(10),
                    children: solicitudesNivel
                        .map(construirSolicitud)
                        .toList(),
                  ),
                );
              }).toList(),
            ),
          );
        }),
      ],
    );
  }

  // =========================================================
  // INFORMACIÓN SUPERIOR
  // =========================================================

  Widget construirInformacionSuperior(
    List<Map<String, dynamic>> solicitudes,
  ) {
    final examenes = solicitudes.where(esExamenColocacion).length;
    final cursos = solicitudes.length - examenes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Selector de periodo.
        const Text(
          'Periodo',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: azulSolicitudesCoord,
          ),
        ),
        const SizedBox(height: 7),
        DropdownButtonFormField<int>(
          initialValue: periodoSeleccionadoId,
          isExpanded: true,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            prefixIcon: const Icon(
              Icons.calendar_month,
              color: azulSolicitudesCoord,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          items: periodos.map((periodo) {
            return DropdownMenuItem<int>(
              value: (periodo['id'] as num).toInt(),
              child: Text(
                periodo['nombre']?.toString() ?? 'Periodo',
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: cambiarPeriodo,
        ),

        const SizedBox(height: 15),

        // Aviso sobre las funciones de esta pantalla.
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: azulSolicitudesCoord.withValues(alpha: 0.2)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline,
                color: azulSolicitudesCoord,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'En esta pantalla únicamente se pueden modificar los horarios y resultados de los exámenes de colocación. Las solicitudes de cursos son solo de consulta.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // Total de solicitudes.
        Text(
          'Solicitudes registradas: ${solicitudes.length}',
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.bold,
            color: azulSolicitudesCoord,
          ),
        ),

        const SizedBox(height: 10),

        // Contadores por tipo.
        Row(
          children: [
            Expanded(
              child: _construirContador(
                'Exámenes de colocación',
                examenes,
                Icons.assignment_turned_in_outlined,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _construirContador(
                'Solicitudes de cursos',
                cursos,
                Icons.school_outlined,
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),
      ],
    );
  }

  Widget _construirContador(
    String titulo,
    int cantidad,
    IconData icono,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, color: azulSolicitudesCoord),
          const SizedBox(height: 8),
          Text(
            cantidad.toString(),
            style: const TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.bold,
              color: azulSolicitudesCoord,
            ),
          ),
          Text(
            titulo,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // PANTALLA PRINCIPAL
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: fondoSolicitudesCoord,
      appBar: AppBar(
        title: const Text('Solicitudes'),
        backgroundColor: azulSolicitudesCoord,
        foregroundColor: Colors.white,
      ),
      body: cargandoPeriodos
          ? const Center(
              child: CircularProgressIndicator(
                color: azulSolicitudesCoord,
              ),
            )
          : periodos.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No hay periodos registrados.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : FutureBuilder<List<Map<String, dynamic>>>(
                  future: futurasSolicitudes,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: azulSolicitudesCoord,
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: Colors.red,
                                size: 45,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No se pudieron cargar las solicitudes.\n${snapshot.error}',
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: actualizarSolicitudes,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Reintentar'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final solicitudes = snapshot.data ?? [];

                    final examenes = solicitudes
                        .where(esExamenColocacion)
                        .toList();

                    final cursos = solicitudes
                        .where((s) => !esExamenColocacion(s))
                        .toList();

                    return RefreshIndicator(
                      color: azulSolicitudesCoord,
                      onRefresh: actualizarSolicitudes,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(18),
                        children: [
                          construirInformacionSuperior(solicitudes),

                          if (examenes.isNotEmpty)
                            construirApartadoExamenes(examenes),

                          if (cursos.isNotEmpty)
                            construirApartadoCursos(cursos),

                          if (solicitudes.isEmpty)
                            const Padding(
                              padding: EdgeInsets.only(top: 35),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.assignment_outlined,
                                    size: 65,
                                    color: Colors.grey,
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    'No hay solicitudes registradas para este periodo.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.black54,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
