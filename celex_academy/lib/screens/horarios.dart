
import 'package:flutter/material.dart';

// Colores principales de CELEX Academy.
const Color azulHorarios = Color(0xFF023C87);
const Color fondoHorarios = Color(0xFFEAF1FB);

class Horarios extends StatelessWidget {
  const Horarios({super.key});

  // Datos ficticios de ejemplo.
  final List<Map<String, String>> cursos = const [
    {
      'idioma': 'Inglés',
      'nivel': 'Intermedio 2',
      'dias': 'Lunes y miércoles',
      'hora': '16:00 - 18:00',
      'aula': 'Por confirmar',
      'modalidad': 'Presencial',
      'inicio': 'Por confirmar',
      'fin': 'Por confirmar',
    },
    {
      'idioma': 'Francés',
      'nivel': 'Básico 1',
      'dias': 'Martes y jueves',
      'hora': '10:00 - 12:00',
      'aula': 'Por confirmar',
      'modalidad': 'Presencial',
      'inicio': 'Por confirmar',
      'fin': 'Por confirmar',
    },
  ];

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
      ),

      body: SingleChildScrollView(
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

            // Aviso sobre los horarios.
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
                      'Los horarios definitivos se mostrarán '
                      'cuando tu grupo esté confirmado.',
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

            // Mostramos una tarjeta por cada curso de ejemplo.
            ...cursos.map((curso) {
              return _TarjetaHorario(curso: curso);
            }),

            const SizedBox(height: 15),

            // Apartado de recesos.
            Card(
              color: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.calendar_month,
                          color: azulHorarios,
                          size: 27,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Periodos de receso',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: azulHorarios,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    const Text(
                      'Consulta los periodos de receso '
                      'establecidos en el calendario académico.',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 12),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: fondoHorarios,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'Fechas de receso: por confirmar.',
                        style: TextStyle(
                          color: azulHorarios,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

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

// Tarjeta reutilizable para mostrar los datos de cada curso.
class _TarjetaHorario extends StatelessWidget {
  final Map<String, String> curso;

  const _TarjetaHorario({required this.curso});

  @override
  Widget build(BuildContext context) {
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
                    curso['idioma']!,
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
              icono: Icons.calendar_today,
              etiqueta: 'Días',
              valor: curso['dias']!,
            ),

            _DatoHorario(
              icono: Icons.access_time,
              etiqueta: 'Horario',
              valor: curso['hora']!,
            ),

            _DatoHorario(
              icono: Icons.location_on_outlined,
              etiqueta: 'Aula',
              valor: curso['aula']!,
            ),

            _DatoHorario(
              icono: Icons.people_outline,
              etiqueta: 'Modalidad',
              valor: curso['modalidad']!,
            ),

            _DatoHorario(
              icono: Icons.event,
              etiqueta: 'Fecha de inicio',
              valor: curso['inicio']!,
            ),

            _DatoHorario(
              icono: Icons.event_available,
              etiqueta: 'Fecha de término',
              valor: curso['fin']!,
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
