
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Colores principales de CELEX Academy.
const Color azulCalificaciones = Color(0xFF023C87);
const Color fondoCalificaciones = Color(0xFFEAF1FB);

// Pantalla para consultar el historial académico del estudiante.
class Calificaciones extends StatefulWidget {
  const Calificaciones({super.key});

  @override
  State<Calificaciones> createState() => _CalificacionesState();
}

class _CalificacionesState extends State<Calificaciones> {
  // Conexión con Supabase.
  final supabase = Supabase.instance.client;

  // Aquí guardamos la consulta del historial académico.
  late Future<List<Map<String, dynamic>>> historialFuture;

  @override
  void initState() {
    super.initState();

    // Consultamos las calificaciones al abrir la pantalla.
    historialFuture = cargarHistorial();
  }

  // Obtiene el historial académico del estudiante.
  Future<List<Map<String, dynamic>>> cargarHistorial() async {
    final usuario = supabase.auth.currentUser;

    if (usuario == null) {
      throw Exception('No hay una sesión iniciada.');
    }

    // Consultamos los resultados y sus relaciones con idiomas y niveles.
    final respuesta = await supabase
        .from('historial_academico')
        .select('''
          id,
          idioma_id,
          nivel_id,
          calificacion_final,
          estado,
          fecha_inicio,
          fecha_fin,
          idiomas(nombre),
          niveles(nombre, orden, idioma_id)
        ''')
        .eq('estudiante_id', usuario.id)
        .order('fecha_registro', ascending: false);

    final List<Map<String, dynamic>> resultados = [];

    // Procesamos cada registro del historial.
    for (final registro in respuesta) {
      final datos = Map<String, dynamic>.from(registro);

      final nivel = obtenerRelacion(datos['niveles']);

      final estado = datos['estado']?.toString() ?? '';

      final calificacion =
          (datos['calificacion_final'] as num?)?.toDouble();

      String? siguiente;

      // Si el estudiante aprobó, buscamos el siguiente nivel.
      if (estado == 'Finalizado' &&
          calificacion != null &&
          calificacion >= 8) {
        final idiomaId = nivel['idioma_id'];
        final orden = (nivel['orden'] as num?)?.toInt();

        if (idiomaId != null && orden != null) {
          final siguienteNivel = await supabase
              .from('niveles')
              .select('nombre')
              .eq('idioma_id', idiomaId)
              .eq('orden', orden + 1)
              .eq('activo', true)
              .maybeSingle();

          siguiente = siguienteNivel?['nombre']?.toString();
        }
      }

      // Agregamos el siguiente nivel al resultado para mostrarlo.
      datos['siguiente'] = siguiente;

      resultados.add(datos);
    }

    return resultados;
  }

  // Obtiene los datos de una relación de Supabase.
  // Esto permite manejar relaciones que lleguen como mapa o lista.
  Map<String, dynamic> obtenerRelacion(dynamic relacion) {
    if (relacion is Map) {
      return Map<String, dynamic>.from(relacion);
    }

    if (relacion is List && relacion.isNotEmpty) {
      return Map<String, dynamic>.from(relacion.first);
    }

    return {};
  }

  // Actualiza el historial cuando el estudiante lo solicita.
  void actualizarHistorial() {
    setState(() {
      historialFuture = cargarHistorial();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: fondoCalificaciones,

      appBar: AppBar(
        title: const Text(
          'Calificaciones',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: azulCalificaciones,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // Botón para actualizar los resultados.
          IconButton(
            onPressed: actualizarHistorial,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
          ),
        ],
      ),

      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: historialFuture,
        builder: (context, snapshot) {
          // Mientras se consultan los datos.
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: azulCalificaciones,
              ),
            );
          }

          // Si ocurrió un error.
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
                      'No se pudo cargar tu historial académico.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 15),
                    ElevatedButton(
                      onPressed: actualizarHistorial,
                      child: const Text('Intentar nuevamente'),
                    ),
                  ],
                ),
              ),
            );
          }

          final historial = snapshot.data ?? [];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mi historial académico',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: azulCalificaciones,
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  'Consulta tus resultados y conoce qué nivel '
                  'te corresponde cursar.',
                  style: TextStyle(fontSize: 15),
                ),

                const SizedBox(height: 22),

                // Regla de aprobación.
                Container(
                  padding: const EdgeInsets.all(16),
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
                        color: azulCalificaciones,
                        size: 27,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Para aprobar un nivel necesitas obtener '
                          'una calificación mínima de 8.0.',
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                const Text(
                  'Resultados',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: azulCalificaciones,
                  ),
                ),

                const SizedBox(height: 12),

                // Si no hay resultados registrados.
                if (historial.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(25),
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
                          Icons.school_outlined,
                          color: azulCalificaciones,
                          size: 55,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Aún no tienes calificaciones registradas.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Cuando finalices un curso, tus resultados '
                          'aparecerán en esta sección.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Mostramos una tarjeta por cada registro académico.
                ...historial.map((resultado) {
                  final idioma = obtenerRelacion(resultado['idiomas']);
                  final nivel = obtenerRelacion(resultado['niveles']);

                  final calificacion =
                      (resultado['calificacion_final'] as num?)
                          ?.toDouble();

                  return _TarjetaCalificacion(
                    idioma: idioma['nombre']?.toString() ?? 'Sin idioma',
                    nivel: nivel['nombre']?.toString() ?? 'Sin nivel',
                    calificacion: calificacion,
                    estado: resultado['estado']?.toString() ?? '',
                    siguiente: resultado['siguiente']?.toString(),
                  );
                }),

                const SizedBox(height: 15),

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

// Tarjeta reutilizable para mostrar cada resultado académico.
class _TarjetaCalificacion extends StatelessWidget {
  final String idioma;
  final String nivel;
  final double? calificacion;
  final String estado;
  final String? siguiente;

  const _TarjetaCalificacion({
    required this.idioma,
    required this.nivel,
    required this.calificacion,
    required this.estado,
    required this.siguiente,
  });

  @override
  Widget build(BuildContext context) {
    final bool enCurso = estado == 'En curso';

    final bool aprobado =
        !enCurso && (calificacion ?? 0) >= 8;

    final Color colorEstado = enCurso
        ? azulCalificaciones
        : aprobado
            ? Colors.green.shade700
            : Colors.orange.shade800;

    final String textoEstado = enCurso
        ? 'En curso'
        : aprobado
            ? 'Aprobado'
            : 'No aprobado';

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
                  Icons.menu_book_rounded,
                  color: azulCalificaciones,
                  size: 28,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    idioma,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: azulCalificaciones,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Text(
              'Nivel cursado: $nivel',
              style: const TextStyle(fontSize: 14),
            ),

            const SizedBox(height: 16),

            if (!enCurso) ...[
              const Text(
                'Calificación final',
                style: TextStyle(color: Colors.black54),
              ),

              const SizedBox(height: 4),

              Text(
                calificacion?.toStringAsFixed(1) ?? '--',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: colorEstado,
                ),
              ),
            ],

            if (enCurso)
              const Text(
                'Este nivel todavía no tiene una calificación final.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                ),
              ),

            const SizedBox(height: 12),

            // Estado del resultado.
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 7,
              ),
              decoration: BoxDecoration(
                color: enCurso
                    ? const Color(0xFFEAF1FB)
                    : aprobado
                        ? Colors.green.shade50
                        : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                textoEstado,
                style: TextStyle(
                  color: colorEstado,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            // Información según el resultado obtenido.
            if (!enCurso) ...[
              const Divider(height: 25),

              Text(
                aprobado
                    ? siguiente != null
                        ? 'Puedes continuar al siguiente nivel: $siguiente'
                        : '¡Felicidades! Has completado todos los niveles '
                            'de este idioma.'
                    : 'Debes repetir el nivel: $nivel',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
