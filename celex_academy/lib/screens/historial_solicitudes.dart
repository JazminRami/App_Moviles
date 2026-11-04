
import 'package:flutter/material.dart';

// Importamos el formulario para crear nuevas solicitudes.
import 'nueva_solicitud.dart';

// Colores de CELEX Academy.
const Color azulHistorial = Color(0xFF023C87);
const Color fondoHistorial = Color(0xFFEAF1FB);

// Pantalla del historial de solicitudes.
class HistorialSolicitudes extends StatelessWidget {
  const HistorialSolicitudes({super.key});

  // Solicitudes ficticias para probar el diseño.
  // Después mostraremos aquí las solicitudes reales del estudiante.
  static const List<Map<String, String>> solicitudes = [
    {
      'folio': 'SOL-001',
      'tipo': 'Inscripción a curso',
      'idioma': 'Inglés',
      'nivel': 'Básico 1',
      'estado': 'Pendiente de revisión',
    },
    {
      'folio': 'SOL-002',
      'tipo': 'Examen de colocación',
      'idioma': 'Francés',
      'nivel': 'Por determinar',
      'estado': 'En espera',
    },
    {
      'folio': 'SOL-003',
      'tipo': 'Inscripción a curso',
      'idioma': 'Inglés',
      'nivel': 'Intermedio 1',
      'estado': 'Grupo confirmado',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      // Barra superior.
      appBar: AppBar(
        title: const Text('Mis solicitudes'),
        backgroundColor: azulHistorial,
        foregroundColor: Colors.white,
        elevation: 0,
      ),

      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Encabezado.
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
            'Consulta el estado de tus trámites de CELEX ESCOM.',
            style: TextStyle(
              fontSize: 15,
              color: Colors.black54,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 20),

          // Aviso de que son datos de ejemplo.
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: fondoHistorial,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  color: azulHistorial,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Estas solicitudes son ejemplos. '
                    'Todavía no están guardadas en una base de datos.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Lista de solicitudes de ejemplo.
          ...solicitudes.map((solicitud) {
            return _TarjetaSolicitud(
              solicitud: solicitud,
            );
          }),

          const SizedBox(height: 12),

          // Botón para iniciar otro trámite.
          SizedBox(
            height: 54,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NuevaSolicitud(),
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text(
                'Crear nueva solicitud',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: azulHistorial,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

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
      ),
    );
  }
}

// Tarjeta reutilizable para mostrar cada solicitud.
class _TarjetaSolicitud extends StatelessWidget {
  final Map<String, String> solicitud;

  const _TarjetaSolicitud({
    required this.solicitud,
  });

  @override
  Widget build(BuildContext context) {
    final String estado = solicitud['estado']!;

    // Elegimos un color según el estado de la solicitud.
    Color colorEstado;

    if (estado == 'Grupo confirmado') {
      colorEstado = const Color(0xFF187545);
    } else if (estado == 'En espera') {
      colorEstado = const Color(0xFF9A6700);
    } else {
      colorEstado = const Color(0xFF456A9D);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(17),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Folio y estado.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.description_outlined,
                color: azulHistorial,
                size: 28,
              ),

              const SizedBox(width: 10),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      solicitud['folio']!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      solicitud['tipo']!,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: azulHistorial,
                      ),
                    ),
                  ],
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: colorEstado.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  estado,
                  style: TextStyle(
                    color: colorEstado,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),

          const Divider(height: 28),

          // Datos de la solicitud.
          _DatoSolicitud(
            etiqueta: 'Idioma',
            valor: solicitud['idioma']!,
          ),

          const SizedBox(height: 10),

          _DatoSolicitud(
            etiqueta: 'Nivel',
            valor: solicitud['nivel']!,
          ),

          const SizedBox(height: 14),

          // Explicación del estado.
          Text(
            _descripcionEstado(estado),
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black54,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // Texto explicativo según el estado.
  String _descripcionEstado(String estado) {
    switch (estado) {
      case 'Grupo confirmado':
        return 'En este ejemplo, el grupo ya fue confirmado. '
            'El siguiente paso sería consultar las instrucciones '
            'oficiales de pago.';

      case 'En espera':
        return 'En este ejemplo, debes esperar las indicaciones '
            'sobre la fecha y el procedimiento del examen.';

      default:
        return 'En este ejemplo, la solicitud está pendiente '
            'de revisión. Espera la confirmación correspondiente.';
    }
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
      children: [
        SizedBox(
          width: 75,
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
