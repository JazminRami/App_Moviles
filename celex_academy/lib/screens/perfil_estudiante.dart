
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Colores principales de CELEX Academy.
const Color azulPerfil = Color(0xFF023C87);
const Color fondoPerfil = Color(0xFFEAF1FB);

// Pantalla del perfil del estudiante.
class PerfilEstudiante extends StatefulWidget {
  const PerfilEstudiante({super.key});

  @override
  State<PerfilEstudiante> createState() => _PerfilEstudianteState();
}

class _PerfilEstudianteState extends State<PerfilEstudiante> {

  // Consulta para obtener los datos del estudiante.
  Future<Map<String, dynamic>?> obtenerPerfil() async {
    final usuario = Supabase.instance.client.auth.currentUser;

    if (usuario == null) {
      return null;
    }

    final respuesta = await Supabase.instance.client
        .from('perfiles_estudiantes')
        .select(
          'nombre_completo, correo, categoria, estado_verificacion_ipn',
        )
        .eq('id', usuario.id)
        .maybeSingle();

    return respuesta;
  }

  // Muestra una confirmación antes de cerrar sesión.
  Future<void> confirmarCerrarSesion() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Cerrar sesión'),
          content: const Text(
            '¿Estás seguro de que deseas cerrar tu sesión?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Cerrar sesión'),
            ),
          ],
        );
      },
    );

    if (confirmar == true) {
      await cerrarSesion();
    }
  }

  // Cierra la sesión de Supabase y regresa a la pantalla inicial.
  Future<void> cerrarSesion() async {
    try {
      await Supabase.instance.client.auth.signOut();

      if (!mounted) return;

      Navigator.pushNamedAndRemoveUntil(
        context,
        '/',
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo cerrar la sesión. Intenta nuevamente.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Construye la pantalla con los datos obtenidos.
  Widget construirPerfil(
    String nombre,
    String correo,
    String categoria,
    String estadoVerificacion,
    bool mostrarVerificacion,
  ) {
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

            // Nombre obtenido de Supabase.
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

            // Correo obtenido de Supabase.
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

                // Solo se muestra para Comunidad IPN.
                if (mostrarVerificacion)
                  _DatoPerfil(
                    etiqueta: 'Verificación IPN',
                    valor: estadoVerificacion,
                  ),
              ],
            ),

            const SizedBox(height: 18),

            // Información según la categoría del estudiante.
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
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: azulPerfil,
                    size: 26,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      mostrarVerificacion
                          ? 'La categoría Comunidad IPN requiere '
                              'verificar la pertenencia a la comunidad '
                              'del Instituto Politécnico Nacional.'
                          : 'La categoría del estudiante determina '
                              'la tarifa que corresponde pagar por '
                              'los cursos.',
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Botón para cerrar sesión.
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: confirmarCerrarSesion,
                icon: const Icon(Icons.logout),
                label: const Text(
                  'Cerrar sesión',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 25),

            const Text(
              'CELEX Academy',
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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: obtenerPerfil(),
      builder: (context, snapshot) {

        // Mientras se consultan los datos.
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                color: azulPerfil,
              ),
            ),
          );
        }

        // Si ocurrió un error al consultar Supabase.
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Mi perfil'),
              backgroundColor: azulPerfil,
              foregroundColor: Colors.white,
            ),
            body: const Center(
              child: Text(
                'No se pudieron cargar los datos del perfil.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        // Si no existe un perfil.
        if (snapshot.data == null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Mi perfil'),
              backgroundColor: azulPerfil,
              foregroundColor: Colors.white,
            ),
            body: const Center(
              child: Text(
                'No se encontró el perfil del estudiante.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        // Obtenemos los datos de la consulta.
        final datos = snapshot.data!;

        final nombre = datos['nombre_completo'] ?? 'Sin nombre';
        final correo = datos['correo'] ?? 'Sin correo';
        final categoria = datos['categoria'] ?? 'Por determinar';

        final estadoVerificacion =
            datos['estado_verificacion_ipn'] ?? 'Pendiente';

        // Determinar si se debe mostrar la verificación IPN.
        final mostrarVerificacion = categoria == 'Comunidad IPN';

        // Mostramos el perfil con los datos reales.
        return construirPerfil(
          nombre,
          correo,
          categoria,
          estadoVerificacion,
          mostrarVerificacion,
        );
      },
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
