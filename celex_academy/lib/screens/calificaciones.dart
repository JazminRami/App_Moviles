
import 'package:flutter/material.dart';

// Colores principales de CELEX Academy.
const Color azulCalificaciones = Color(0xFF023C87);
const Color fondoCalificaciones = Color(0xFFEAF1FB);

class Calificaciones extends StatelessWidget {
  const Calificaciones({super.key});

  // Calificaciones ficticias para mostrar el funcionamiento.
  final List<Map<String, dynamic>> historial = const [
    {
      'idioma': 'Inglés',
      'nivel': 'Intermedio 2',
      'calificacion': 8.5,
      'aprobado': true,
      'siguiente': 'Intermedio 3',
    },
    {
      'idioma': 'Francés',
      'nivel': 'Básico 1',
      'calificacion': 7.0,
      'aprobado': false,
      'siguiente': 'Básico 1',
    },
  ];

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
      ),

      body: SingleChildScrollView(
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
                border: Border.all(color: const Color(0xFFD2E0F5)),
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

            // Recorremos el historial y creamos una tarjeta por resultado.
            ...historial.map((resultado) {
              return _TarjetaCalificacion(
                idioma: resultado['idioma'],
                nivel: resultado['nivel'],
                calificacion: resultado['calificacion'],
                aprobado: resultado['aprobado'],
                siguiente: resultado['siguiente'],
              );
            }),

            const SizedBox(height: 15),

            const Center(
              child: Text(
                'CELEX Academy · Datos de demostración',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Tarjeta reutilizable para mostrar cada calificación.
class _TarjetaCalificacion extends StatelessWidget {
  final String idioma;
  final String nivel;
  final double calificacion;
  final bool aprobado;
  final String siguiente;

  const _TarjetaCalificacion({
    required this.idioma,
    required this.nivel,
    required this.calificacion,
    required this.aprobado,
    required this.siguiente,
  });

  @override
  Widget build(BuildContext context) {
    final Color colorEstado =
        aprobado ? Colors.green.shade700 : Colors.orange.shade800;

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

            const Text(
              'Calificación final',
              style: TextStyle(color: Colors.black54),
            ),

            const SizedBox(height: 4),

            Text(
              calificacion.toStringAsFixed(1),
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: colorEstado,
              ),
            ),

            const SizedBox(height: 8),

            // Estado del resultado.
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 7,
              ),
              decoration: BoxDecoration(
                color: aprobado
                    ? Colors.green.shade50
                    : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                aprobado ? 'Aprobado' : 'No aprobado',
                style: TextStyle(
                  color: colorEstado,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const Divider(height: 25),

            Text(
              aprobado
                  ? 'Puedes solicitar el siguiente nivel: $siguiente'
                  : 'Debes repetir el nivel: $siguiente',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
