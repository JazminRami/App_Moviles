
import 'package:flutter/material.dart';

// Colores principales de CELEX Academy.
const Color azulPerfil = Color(0xFF023C87);
const Color fondoPerfil = Color(0xFFEAF1FB);

class PerfilEstudiante extends StatelessWidget {
  const PerfilEstudiante({super.key});

  // Datos ficticios del estudiante.
  // Después se obtendrán de la base de datos.
  final String nombre = 'Nombre del estudiante';
  final String correo = 'estudiante@ejemplo.com';
  final String categoria = 'Comunidad IPN';
  final String estadoVerificacion = 'Pendiente de verificar';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: fondoPerfil,

      // Barra superior.
      appBar: AppBar(
        title: const Text(
          'Mi perfil',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: azulPerfil,
        iconTheme: const IconThemeData(color: Colors.white),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 15),

            // Imagen provisional del usuario.
            Container(
              width: 110,
              height: 110,
              decoration: const BoxDecoration(
                color: azulPerfil,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person,
                color: Colors.white,
                size: 65,
              ),
            ),

            const SizedBox(height: 15),

            // Nombre del estudiante.
            Text(
              nombre,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: azulPerfil,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 5),

            Text(
              correo,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black54,
              ),
            ),

            const SizedBox(height: 25),

            // Apartado de datos personales.
            _TarjetaPerfil(
              titulo: 'Datos personales',
              icono: Icons.person_outline,
              contenido: [
                _DatoPerfil(
                  etiqueta: 'Nombre completo',
                  valor: nombre,
                ),
                _DatoPerfil(
                  etiqueta: 'Correo electrónico',
                  valor: correo,
                ),
              ],
            ),

            const SizedBox(height: 18),

            // Apartado de categoría del estudiante.
            _TarjetaPerfil(
              titulo: 'Categoría del estudiante',
              icono: Icons.school_outlined,
              contenido: [
                _DatoPerfil(
                  etiqueta: 'Categoría',
                  valor: categoria,
                ),
                _DatoPerfil(
                  etiqueta: 'Verificación IPN',
                  valor: estadoVerificacion,
                ),
              ],
            ),

            const SizedBox(height: 18),

            // Información sobre las categorías.
            Container(
              width: double.infinity,
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
                    color: azulPerfil,
                    size: 26,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'La categoría del estudiante determina '
                      'la tarifa que corresponde pagar por '
                      'los cursos. La comunidad IPN debe '
                      'verificar su condición.',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),

            const Text(
              'CELEX Academy · Datos de demostración',
              style: TextStyle(
                fontSize: 12,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Tarjeta reutilizable para organizar la información.
class _TarjetaPerfil extends StatelessWidget {
  final String titulo;
  final IconData icono;
  final List<Widget> contenido;

  const _TarjetaPerfil({
    required this.titulo,
    required this.icono,
    required this.contenido,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
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
            Row(
              children: [
                Icon(icono, color: azulPerfil, size: 25),
                const SizedBox(width: 10),
                Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: azulPerfil,
                  ),
                ),
              ],
            ),

            const Divider(height: 25),

            ...contenido,
          ],
        ),
      ),
    );
  }
}

// Widget para mostrar una etiqueta y su valor.
class _DatoPerfil extends StatelessWidget {
  final String etiqueta;
  final String valor;

  const _DatoPerfil({
    required this.etiqueta,
    required this.valor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            etiqueta,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            valor,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
