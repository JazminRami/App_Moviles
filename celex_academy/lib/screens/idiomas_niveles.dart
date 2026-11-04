
import 'package:flutter/material.dart';

// Colores institucionales de CELEX Academy.
const Color azulIdiomas = Color(0xFF023C87);
const Color fondoIdiomas = Color(0xFFEAF1FB);

// Pantalla para consultar idiomas y niveles disponibles.
class IdiomasNiveles extends StatelessWidget {
  const IdiomasNiveles({super.key});

  // Datos de ejemplo.
  // Más adelante vendrán de la base de datos.
  static const List<Map<String, dynamic>> idiomas = [
    {
      'nombre': 'Inglés',
      'descripcion': 'Aprende inglés desde cero o continúa tu formación.',
      'icono': Icons.language_rounded,
      'niveles': [
        {
          'nombre': 'Básico 1',
          'estado': 'Grupo abierto',
          'disponible': true,
        },
        {
          'nombre': 'Básico 2',
          'estado': 'En espera',
          'disponible': false,
        },
        {
          'nombre': 'Intermedio 1',
          'estado': 'Sin apertura',
          'disponible': false,
        },
        {
          'nombre': 'Intermedio 2',
          'estado': 'Grupo abierto',
          'disponible': true,
        },
        {
          'nombre': 'Intermedio 3',
          'estado': 'En espera',
          'disponible': false,
        },
        {
          'nombre': 'Avanzado 5',
          'estado': 'Sin apertura',
          'disponible': false,
        },
      ],
    },
    {
      'nombre': 'Francés',
      'descripcion': 'Descubre un nuevo idioma y su cultura.',
      'icono': Icons.translate_rounded,
      'niveles': [
        {
          'nombre': 'Básico 1',
          'estado': 'Grupo abierto',
          'disponible': true,
        },
        {
          'nombre': 'Básico 2',
          'estado': 'En espera',
          'disponible': false,
        },
        {
          'nombre': 'Intermedio 1',
          'estado': 'Sin apertura',
          'disponible': false,
        },
        {
          'nombre': 'Avanzado 5',
          'estado': 'Sin apertura',
          'disponible': false,
        },
      ],
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      // Barra superior.
      appBar: AppBar(
        title: const Text('Idiomas y niveles'),
        backgroundColor: azulIdiomas,
        foregroundColor: Colors.white,
        elevation: 0,
      ),

      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          // Introducción.
          const Text(
            'Explora los cursos',
            style: TextStyle(
              color: azulIdiomas,
              fontSize: 25,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            'Consulta los idiomas, sus niveles y el estado '
            'de apertura de los grupos.',
            style: TextStyle(
              color: Colors.black54,
              fontSize: 15,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 20),

          // Aviso sobre los datos.
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: fondoIdiomas,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: azulIdiomas,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Los estados mostrados son ejemplos para '
                    'demostrar el funcionamiento de la aplicación.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Creamos una tarjeta por cada idioma.
          ...idiomas.map((idioma) {
            return _TarjetaIdioma(
              idioma: idioma,
            );
          }),

          const SizedBox(height: 16),

          // Nota sobre los niveles.
          const Text(
            'Los niveles y grupos reales dependerán de la '
            'convocatoria vigente de CELEX ESCOM.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.black45,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// Tarjeta que representa un idioma.
class _TarjetaIdioma extends StatelessWidget {
  final Map<String, dynamic> idioma;

  const _TarjetaIdioma({
    required this.idioma,
  });

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> niveles =
        List<Map<String, dynamic>>.from(idioma['niveles']);

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD9E4F3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Encabezado del idioma.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
              color: fondoIdiomas,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(17),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: azulIdiomas,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    idioma['icono'] as IconData,
                    color: Colors.white,
                    size: 28,
                  ),
                ),

                const SizedBox(width: 14),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        idioma['nombre'] as String,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: azulIdiomas,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        idioma['descripcion'] as String,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Lista de niveles del idioma.
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Niveles de ejemplo',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: azulIdiomas,
                  ),
                ),

                const SizedBox(height: 12),

                ...niveles.map((nivel) {
                  return _FilaNivel(
                    idioma: idioma['nombre'] as String,
                    nivel: nivel,
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Fila que muestra el nivel y su estado.
class _FilaNivel extends StatelessWidget {
  final String idioma;
  final Map<String, dynamic> nivel;

  const _FilaNivel({
    required this.idioma,
    required this.nivel,
  });

  @override
  Widget build(BuildContext context) {
    final bool disponible = nivel['disponible'] as bool;
    final String estado = nivel['estado'] as String;

    // Elegimos un color según el estado del grupo.
    final Color colorEstado = disponible
        ? const Color(0xFF187545)
        : estado == 'En espera'
            ? const Color(0xFF9A6700)
            : Colors.grey.shade700;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE3EAF4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.menu_book_rounded,
                color: azulIdiomas,
                size: 21,
              ),

              const SizedBox(width: 9),

              Expanded(
                child: Text(
                  nivel['nombre'] as String,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: colorEstado.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  estado,
                  style: TextStyle(
                    color: colorEstado,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Botón de consulta del nivel.
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                // Por ahora solo mostramos información.
                // Después conectaremos este botón con la solicitud.
                showDialog(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: Text(
                        '$idioma - ${nivel['nombre']}',
                      ),
                      content: Text(
                        disponible
                            ? 'Este grupo aparece como abierto en '
                                'los datos de prueba. Más adelante '
                                'podrás iniciar tu solicitud aquí.'
                            : 'Estado de prueba: $estado. '
                                'Consulta las convocatorias oficiales '
                                'para conocer la disponibilidad real.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: const Text('Entendido'),
                        ),
                      ],
                    );
                  },
                );
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: azulIdiomas,
                side: const BorderSide(color: azulIdiomas),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Consultar nivel'),
            ),
          ),
        ],
      ),
    );
  }
}
