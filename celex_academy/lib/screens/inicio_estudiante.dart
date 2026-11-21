
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'idiomas_niveles.dart';
import 'historial_solicitudes.dart';
import 'pagos_comprobantes.dart';
import 'calificaciones.dart';
import 'perfil_estudiante.dart';
import 'horarios.dart';
import 'verificacion_ipn_estudiante.dart';

// Colores principales de CELEX Academy.
const Color azulInicio = Color(0xFF023C87);
const Color azulFondo = Color(0xFFEAF1FB);

// Pantalla principal del estudiante.
class InicioEstudiante extends StatefulWidget {
  const InicioEstudiante({super.key});

  @override
  State<InicioEstudiante> createState() => _InicioEstudianteState();
}

class _InicioEstudianteState extends State<InicioEstudiante> {
  // Consultas para obtener los datos del estudiante.
  late Future<String> nombreEstudiante;
  late Future<bool> esComunidadIpn;

  @override
  void initState() {
    super.initState();

    nombreEstudiante = obtenerNombreEstudiante();
    esComunidadIpn = obtenerCategoriaEstudiante();
  }

  // Obtiene el nombre completo y devuelve solamente el primer nombre.
  Future<String> obtenerNombreEstudiante() async {
    try {
      final usuario = Supabase.instance.client.auth.currentUser;

      if (usuario == null) {
        return 'Bienvenido';
      }

      final datos = await Supabase.instance.client
          .from('perfiles_estudiantes')
          .select('nombre_completo')
          .eq('id', usuario.id)
          .maybeSingle();

      final nombreCompleto = datos?['nombre_completo'] as String?;

      if (nombreCompleto == null || nombreCompleto.trim().isEmpty) {
        return 'Bienvenido';
      }

      return nombreCompleto.trim().split(RegExp(r'\s+')).first;
    } catch (e) {
      return 'Bienvenido';
    }
  }

  // Comprueba si el estudiante pertenece a Comunidad IPN.
  Future<bool> obtenerCategoriaEstudiante() async {
    try {
      final usuario = Supabase.instance.client.auth.currentUser;

      if (usuario == null) {
        return false;
      }

      final datos = await Supabase.instance.client
          .from('perfiles_estudiantes')
          .select('categoria')
          .eq('id', usuario.id)
          .maybeSingle();

      final categoria = datos?['categoria'] as String?;

      return categoria == 'Comunidad IPN';
    } catch (e) {
      // Si no se pueden consultar los datos,
      // se oculta la opción por seguridad.
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      // Barra superior de la aplicación.
      appBar: AppBar(
        backgroundColor: azulInicio,
        foregroundColor: Colors.white,
        elevation: 0,

        // Evita que aparezca la flecha de regresar.
        automaticallyImplyLeading: false,

        title: const Text(
          'CELEX Academy',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          // Botón para acceder al perfil.
          IconButton(
            tooltip: 'Mi perfil',
            icon: const Icon(Icons.person_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PerfilEstudiante(),
                ),
              );
            },
          ),
        ],
      ),

      // Contenido de la pantalla.
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Saludo personalizado y centrado.
              FutureBuilder<String>(
                future: nombreEstudiante,
                builder: (context, snapshot) {
                  final nombre = snapshot.data ?? 'Bienvenido';

                  return Text(
                    '¡Hola, $nombre! 👋',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                      color: azulInicio,
                    ),
                  );
                },
              ),

              const SizedBox(height: 22),

              // Tarjeta compacta de bienvenida.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 20,
                ),
                decoration: BoxDecoration(
                  color: azulInicio,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.school_rounded,
                      color: Colors.white,
                      size: 34,
                    ),
                    SizedBox(height: 10),
                    Text(
                      '¡Bienvenido a CELEX Academy!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Tu futuro comienza con un idioma.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              const Text(
                'Mis servicios',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: azulInicio,
                ),
              ),

              const SizedBox(height: 16),

              // Idiomas y niveles.
              _TarjetaServicio(
                icono: Icons.language_rounded,
                titulo: 'Idiomas y niveles',
                descripcion: 'Explora los cursos disponibles.',
                alPresionar: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const IdiomasNiveles(),
                    ),
                  );
                },
              ),

              // Mis solicitudes.
              _TarjetaServicio(
                icono: Icons.assignment_outlined,
                titulo: 'Mis solicitudes',
                descripcion: 'Consulta y da seguimiento a tus solicitudes.',
                alPresionar: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const HistorialSolicitudes(),
                    ),
                  );
                },
              ),

              // Pagos.
              _TarjetaServicio(
                icono: Icons.receipt_long_rounded,
                titulo: 'Pagos',
                descripcion: 'Consulta tus pagos y comprobantes.',
                alPresionar: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PagosComprobantes(),
                    ),
                  );
                },
              ),

              // Calificaciones.
              _TarjetaServicio(
                icono: Icons.school_outlined,
                titulo: 'Calificaciones',
                descripcion: 'Revisa tus resultados académicos.',
                alPresionar: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const Calificaciones(),
                    ),
                  );
                },
              ),

              // Horarios.
              _TarjetaServicio(
                icono: Icons.calendar_month,
                titulo: 'Mis horarios',
                descripcion: 'Consulta los horarios de tus clases.',
                alPresionar: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const Horarios(),
                    ),
                  );
                },
              ),

              // Verificación IPN.
              // Solo aparece para estudiantes de Comunidad IPN.
              FutureBuilder<bool>(
                future: esComunidadIpn,
                builder: (context, snapshot) {
                  if (snapshot.data != true) {
                    return const SizedBox.shrink();
                  }

                  return _TarjetaServicio(
                    icono: Icons.verified_user_rounded,
                    titulo: 'Verificación IPN',
                    descripcion: 'Comprueba tu categoría como estudiante.',
                    alPresionar: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const VerificacionIpnEstudiante(),
                        ),
                      );
                    },
                  );
                },
              ),

              const SizedBox(height: 10),

              // Aviso importante para los estudiantes.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: azulFondo,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFFD2E0F5),
                  ),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: azulInicio,
                      size: 26,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Aviso importante',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: azulInicio,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Antes de realizar un pago, verifica '
                            'tu solicitud y confirma que el grupo '
                            'haya sido abierto.',
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.5,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

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
        ),
      ),
    );
  }
}

// Tarjeta de servicio con el mismo diseño del panel del coordinador.
class _TarjetaServicio extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String descripcion;
  final VoidCallback alPresionar;

  const _TarjetaServicio({
    required this.icono,
    required this.titulo,
    required this.descripcion,
    required this.alPresionar,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: InkWell(
        onTap: alPresionar,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              // Icono del servicio.
              Icon(
                icono,
                color: azulInicio,
                size: 34,
              ),

              const SizedBox(width: 16),

              // Nombre y descripción del servicio.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: azulInicio,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      descripcion,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),

              // Flecha que indica que se puede abrir.
              const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.black45,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
