import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Importamos las pantallas correspondientes.
import 'registro.dart';
import 'inicio_estudiante.dart';
import 'inicio_coordinador.dart';

// Color institucional de CELEX Academy.
const Color azulLogin = Color(0xFF023C87);

// Pantalla de inicio de sesión.
class InicioSesion extends StatefulWidget {
  const InicioSesion({super.key});

  @override
  State<InicioSesion> createState() => _InicioSesionState();
}

class _InicioSesionState extends State<InicioSesion> {
  // Controladores para leer el texto de los campos.
  final TextEditingController correoController =
      TextEditingController();

  final TextEditingController contrasenaController =
      TextEditingController();

  // Indica si la contraseña se muestra o se oculta.
  bool mostrarContrasena = false;

  // Indica si se está validando el inicio de sesión.
  bool cargando = false;

  @override
  void dispose() {
    correoController.dispose();
    contrasenaController.dispose();
    super.dispose();
  }

  // Función para iniciar sesión con Supabase.
  Future<void> iniciarSesion() async {
    final correo = correoController.text.trim();
    final contrasena = contrasenaController.text;

    // Comprobamos que los campos no estén vacíos.
    if (correo.isEmpty || contrasena.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Completa el correo y la contraseña.'),
        ),
      );
      return;
    }

    setState(() {
      cargando = true;
    });

    try {
      final supabase = Supabase.instance.client;

      // Validamos las credenciales del usuario.
      final respuesta = await supabase.auth.signInWithPassword(
        email: correo,
        password: contrasena,
      );

      // Comprobamos que exista una sesión.
      if (respuesta.session == null || respuesta.user == null) {
        throw Exception('No se pudo obtener la sesión del usuario.');
      }

      final usuario = respuesta.user!;

      // Consultamos el rol del usuario que inició sesión.
      // La política RLS permite consultar únicamente su propio registro.
      final registroRol = await supabase
          .from('roles_usuarios')
          .select('rol')
          .eq('usuario_id', usuario.id)
          .maybeSingle();

      // Si tiene el rol coordinador, mostramos su panel.
      // Si no tiene registro o es estudiante, mostramos su pantalla habitual.
      final String rol = registroRol?['rol'] ?? 'estudiante';

      if (!mounted) return;

      if (rol == 'coordinador') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const InicioCoordinador(),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const InicioEstudiante(),
          ),
        );
      }
    } on AuthException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No se pudo iniciar sesión: ${error.message}',
            ),
          ),
        );
      }
    } catch (error) {
      // Si falla la consulta del rol, cerramos la sesión para
      // evitar dejar al usuario en un estado de acceso incierto.
      await Supabase.instance.client.auth.signOut();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Ocurrió un error al identificar tu cuenta: $error',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          cargando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Iniciar sesión'),
        backgroundColor: Colors.white,
        foregroundColor: azulLogin,
        elevation: 0,
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),

              const Icon(
                Icons.school_rounded,
                color: azulLogin,
                size: 76,
              ),

              const SizedBox(height: 20),

              const Text(
                '¡Qué gusto verte!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.bold,
                  color: azulLogin,
                ),
              ),

              const SizedBox(height: 10),

              const Text(
                'Ingresa a tu cuenta de CELEX Academy.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.black54,
                ),
              ),

              const SizedBox(height: 36),

              const Text(
                'Correo electrónico',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),

              const SizedBox(height: 8),

              TextField(
                controller: correoController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: 'ejemplo@correo.com',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              const Text(
                'Contraseña',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),

              const SizedBox(height: 8),

              TextField(
                controller: contrasenaController,
                obscureText: !mostrarContrasena,
                decoration: InputDecoration(
                  hintText: 'Escribe tu contraseña',
                  prefixIcon: const Icon(Icons.lock_outline),

                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        mostrarContrasena = !mostrarContrasena;
                      });
                    },
                    icon: Icon(
                      mostrarContrasena
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                  ),

                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              const SizedBox(height: 30),

              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: cargando ? null : iniciarSesion,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: azulLogin,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: cargando
                      ? const CircularProgressIndicator(
                          color: Colors.white,
                        )
                      : const Text(
                          'Entrar',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 22),

              TextButton(
                onPressed: cargando
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const Registro(),
                          ),
                        );
                      },
                child: const Text(
                  '¿No tienes cuenta? Regístrate',
                  style: TextStyle(color: azulLogin),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}