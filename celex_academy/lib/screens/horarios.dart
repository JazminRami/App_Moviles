
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Colores principales de CELEX Academy.
const Color azulHorarios = Color(0xFF023C87);
const Color fondoHorarios = Color(0xFFEAF1FB);

class Horarios extends StatefulWidget {
  const Horarios({super.key});

  @override
  State<Horarios> createState() => _HorariosState();
}

class _HorariosState extends State<Horarios> {
  // Conexión con Supabase.
  final supabase = Supabase.instance.client;

  // Consulta de los horarios del estudiante.
  late Future<List<Map<String, dynamic>>> horariosFuture;

  @override
  void initState() {
    super.initState();
    horariosFuture = cargarHorarios();
  }

  // Consulta las inscripciones activas del estudiante.
  // Aunque la inscripción siga activa en la base de datos,
  // aquí calculamos si el curso ya terminó según sus fechas.
  Future<List<Map<String, dynamic>>> cargarHorarios() async {
    final usuario = supabase.auth.currentUser;

    if (usuario == null) {
      throw Exception('No hay una sesión iniciada.');
    }

    final respuesta = await supabase
        .from('inscripciones')
        .select('''
          id,
          estado,
          grupos:grupos!inscripciones_grupo_id_fkey(
            nombre,
            codigo_grupo,
            periodo_id,
            fecha_inicio,
            fecha_fin,
            horario,
            estado,
            modalidad,
            nivel:niveles!grupos_nivel_id_fkey(
              nombre,
              idioma:idiomas!niveles_idioma_id_fkey(nombre)
            ),
            periodo:periodos!grupos_periodo_id_fkey(
              nombre,
              fecha_inicio,
              fecha_fin
            )
          )
        ''')
        .eq('estudiante_id', usuario.id)
        .eq('estado', 'Activa')
        .order('fecha_inscripcion', ascending: false);

    final List<Map<String, dynamic>> resultados = [];

    for (final registro in respuesta) {
      final datos = Map<String, dynamic>.from(registro);

      // Obtenemos la información del grupo.
      final grupo = obtenerRelacion(datos['grupos']);

      if (grupo.isEmpty) continue;

      // Obtenemos el nivel, idioma y periodo.
      final nivel = obtenerRelacion(grupo['nivel']);
      final idioma = obtenerRelacion(nivel['idioma']);
      final periodo = obtenerRelacion(grupo['periodo']);

      // Guardamos los datos relacionados.
      datos['nombre_grupo'] =
          grupo['nombre']?.toString() ?? 'Por confirmar';

      datos['codigo_grupo'] =
          grupo['codigo_grupo']?.toString() ?? '';

      datos['periodo'] =
          periodo['nombre']?.toString() ?? 'Por confirmar';

      // Usamos las fechas del periodo, igual que en
      // historial_solicitudes.dart.
      // Si no están disponibles, usamos las fechas del grupo.
      final fechaInicio = periodo['fecha_inicio'] ??
          grupo['fecha_inicio'];

      final fechaFin = periodo['fecha_fin'] ??
          grupo['fecha_fin'];

      datos['fecha_inicio'] = fechaInicio?.toString();
      datos['fecha_fin'] = fechaFin?.toString();

      // Calculamos el estado del curso mediante las fechas.
      datos['estado_curso'] = calcularEstadoCurso(
        fechaInicio,
        fechaFin,
      );

      // Horario general de clases.
      datos['horario'] = '08:00 a 13:00';

      // Horario de receso configurado en el grupo.
      datos['horario_receso'] =
          grupo['horario']?.toString() ?? 'Por confirmar';

      datos['modalidad'] =
          grupo['modalidad']?.toString() ?? 'No especificada';

      datos['estado_grupo'] =
          grupo['estado']?.toString() ?? '';

      datos['nivel'] =
          nivel['nombre']?.toString() ?? 'Sin nivel';

      datos['idioma'] =
          idioma['nombre']?.toString() ?? 'Sin idioma';

      resultados.add(datos);
    }

    return resultados;
  }

  // Maneja las relaciones que Supabase devuelve como mapa o lista.
  Map<String, dynamic> obtenerRelacion(dynamic relacion) {
    if (relacion is Map) {
      return Map<String, dynamic>.from(relacion);
    }

    if (relacion is List && relacion.isNotEmpty) {
      return Map<String, dynamic>.from(relacion.first);
    }

    return {};
  }

  // Convierte una fecha YYYY-MM-DD a DateTime sin hora.
  DateTime? convertirFecha(dynamic fecha) {
    if (fecha == null) return null;

    final partes = fecha.toString().split('-');

    if (partes.length != 3) return null;

    try {
      return DateTime(
        int.parse(partes[0]),
        int.parse(partes[1]),
        int.parse(partes[2]),
      );
    } catch (_) {
      return null;
    }
  }

  // Calcula el estado del curso usando las fechas del periodo.
  String calcularEstadoCurso(dynamic fechaInicio, dynamic fechaFin) {
    final inicio = convertirFecha(fechaInicio);
    final fin = convertirFecha(fechaFin);

    if (inicio == null || fin == null) {
      return 'Fecha por confirmar';
    }

    // Se compara únicamente la fecha, sin considerar la hora.
    final hoy = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );

    if (hoy.isBefore(inicio)) {
      return 'Pendiente de inicio';
    }

    if (hoy.isAfter(fin)) {
      return 'Curso finalizado';
    }

    return 'Curso activo';
  }

  // Convierte una fecha YYYY-MM-DD a DD/MM/YYYY.
  String formatearFecha(dynamic fecha) {
    if (fecha == null) return 'Por confirmar';

    final partes = fecha.toString().split('-');

    if (partes.length != 3) return fecha.toString();

    return '${partes[2]}/${partes[1]}/${partes[0]}';
  }

  // Actualiza la información.
  void actualizarHorarios() {
    setState(() {
      horariosFuture = cargarHorarios();
    });
  }

  // Mensaje cuando el estudiante no tiene inscripciones.
  Widget construirMensajeSinHorarios() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFD2E0F5),
        ),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.calendar_month_outlined,
            color: azulHorarios,
            size: 55,
          ),
          SizedBox(height: 15),
          Text(
            'Aún no tienes horarios asignados.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: azulHorarios,
            ),
          ),
          SizedBox(height: 12),
          Text(
            'Puedes consultar el idioma y el nivel de tus '
            'solicitudes en el apartado correspondiente.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 12),
          Divider(),
          SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline,
                color: azulHorarios,
                size: 22,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'El nombre de tu grupo, su código o letra y '
                  'tu horario estarán disponibles cuando CELEX '
                  'asigne tu grupo, tu pago sea confirmado y '
                  'tu inscripción quede activa.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: fondoHorarios,
      appBar: AppBar(
        title: const Text(
          'Mis horarios',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: azulHorarios,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            onPressed: actualizarHorarios,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: horariosFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: azulHorarios,
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(25),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 50,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No se pudieron cargar tus horarios.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Verifica tu conexión e intenta nuevamente.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 15),
                    ElevatedButton(
                      onPressed: actualizarHorarios,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: azulHorarios,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Intentar nuevamente'),
                    ),
                  ],
                ),
              ),
            );
          }

          final cursos = snapshot.data ?? [];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Horarios de mis cursos',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: azulHorarios,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Consulta los horarios y la información '
                  'de tus cursos inscritos.',
                  style: TextStyle(fontSize: 15),
                ),
                const SizedBox(height: 20),

                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFD2E0F5),
                    ),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: azulHorarios,
                        size: 26,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Los datos de tu grupo y horario se '
                          'mostrarán cuando tu pago haya sido '
                          'confirmado y tu inscripción esté activa. '
                          'El estado del curso se actualizará '
                          'automáticamente según sus fechas.',
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                const Text(
                  'Mis cursos',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: azulHorarios,
                  ),
                ),
                const SizedBox(height: 12),

                if (cursos.isEmpty) construirMensajeSinHorarios(),

                ...cursos.map((curso) {
                  return _TarjetaHorario(
                    curso: curso,
                    formatearFecha: formatearFecha,
                  );
                }),

                const SizedBox(height: 20),
                const Center(
                  child: Text(
                    'CELEX Academy',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                    ),
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

// Tarjeta reutilizable para mostrar cada curso.
class _TarjetaHorario extends StatelessWidget {
  final Map<String, dynamic> curso;
  final String Function(dynamic) formatearFecha;

  const _TarjetaHorario({
    required this.curso,
    required this.formatearFecha,
  });

  @override
  Widget build(BuildContext context) {
    final codigoGrupo = curso['codigo_grupo']?.toString() ?? '';
    final estadoCurso =
        curso['estado_curso']?.toString() ?? 'Fecha por confirmar';

    // Definimos el color y el icono según el estado del curso.
    Color colorEstado;
    IconData iconoEstado;

    switch (estadoCurso) {
      case 'Curso finalizado':
        colorEstado = Colors.grey.shade700;
        iconoEstado = Icons.check_circle;
        break;

      case 'Curso activo':
        colorEstado = Colors.green;
        iconoEstado = Icons.play_circle_fill;
        break;

      case 'Pendiente de inicio':
        colorEstado = Colors.orange.shade800;
        iconoEstado = Icons.schedule;
        break;

      default:
        colorEstado = Colors.blueGrey;
        iconoEstado = Icons.info_outline;
    }

    return Card(
      color: Colors.white,
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 15),
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
                  Icons.language,
                  color: azulHorarios,
                  size: 28,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    curso['idioma']?.toString() ?? 'Sin idioma',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: azulHorarios,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Nivel: ${curso['nivel']}',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Divider(height: 25),

            _DatoHorario(
              icono: Icons.groups_outlined,
              etiqueta: 'Grupo',
              valor: curso['nombre_grupo']?.toString() ?? 'Por confirmar',
            ),

            if (codigoGrupo.isNotEmpty)
              _DatoHorario(
                icono: Icons.tag,
                etiqueta: 'Código',
                valor: codigoGrupo,
              ),

            _DatoHorario(
              icono: Icons.calendar_today,
              etiqueta: 'Periodo',
              valor: curso['periodo']?.toString() ?? 'Por confirmar',
            ),

            _DatoHorario(
              icono: Icons.access_time,
              etiqueta: 'Horario',
              valor: curso['horario']?.toString() ?? '08:00 a 13:00',
            ),

            _DatoHorario(
              icono: Icons.coffee_outlined,
              etiqueta: 'Horario receso',
              valor: curso['horario_receso']?.toString() ?? 'Por confirmar',
            ),

            _DatoHorario(
              icono: Icons.event,
              etiqueta: 'Fecha de inicio',
              valor: formatearFecha(curso['fecha_inicio']),
            ),

            _DatoHorario(
              icono: Icons.event_available,
              etiqueta: 'Fecha de término',
              valor: formatearFecha(curso['fecha_fin']),
            ),

            _DatoHorario(
              icono: Icons.location_on_outlined,
              etiqueta: 'Modalidad',
              valor: curso['modalidad']?.toString() ?? 'No especificada',
            ),

            const Divider(height: 20),

            // Estado calculado a partir de las fechas del periodo.
            Row(
              children: [
                Icon(
                  iconoEstado,
                  color: colorEstado,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    estadoCurso,
                    style: TextStyle(
                      color: colorEstado,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Widget para mostrar cada dato del horario.
class _DatoHorario extends StatelessWidget {
  final IconData icono;
  final String etiqueta;
  final String valor;

  const _DatoHorario({
    required this.icono,
    required this.etiqueta,
    required this.valor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icono,
            color: azulHorarios,
            size: 20,
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 105,
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
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
