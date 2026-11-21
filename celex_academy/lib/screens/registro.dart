
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Color institucional.
const Color azulRegistro = Color(0xFF023C87);
const Color fondoRegistro = Color(0xFFEAF1FB);

// Pantalla para crear una cuenta.
class Registro extends StatefulWidget {
  const Registro({super.key});

  @override
  State<Registro> createState() => _RegistroState();
}

class _RegistroState extends State<Registro> {
  // Controladores de los campos.
  final nombreController = TextEditingController();
  final correoController = TextEditingController();
  final contrasenaController = TextEditingController();
  final confirmarContrasenaController = TextEditingController();

  // Categoría seleccionada.
  String? categoriaSeleccionada;

  // Control de visibilidad de contraseñas.
  bool mostrarContrasena = false;
  bool mostrarConfirmacion = false;

  // Control de carga.
  bool cargando = false;

  // Registrar estudiante en Supabase.
  Future<void> registrarEstudiante() async {
    final nombre = nombreController.text.trim();
    final correo = correoController.text.trim();
    final contrasena = contrasenaController.text;
    final confirmar = confirmarContrasenaController.text;

    // Validar campos vacíos.
    if (nombre.isEmpty ||
        correo.isEmpty ||
        contrasena.isEmpty ||
        confirmar.isEmpty ||
        categoriaSeleccionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Completa todos los campos.'),
        ),
      );
      return;
    }

    // Validar que las contraseñas coincidan.
    if (contrasena != confirmar) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Las contraseñas no coinciden.'),
        ),
      );
      return;
    }

    setState(() {
      cargando = true;
    });

    try {
      // Crear cuenta y enviar los datos al perfil automático.
      final respuesta = await Supabase.instance.client.auth.signUp(
        email: correo,
        password: contrasena,
        emailRedirectTo: 'celexacademy://login-callback',
        data: {
          'nombre_completo': nombre,
          'categoria': categoriaSeleccionada,
        },
      );

      if (!mounted) return;

      if (respuesta.user != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cuenta creada correctamente.'),
          ),
        );

        Navigator.pop(context);
      }
    } on AuthException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al registrar: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          cargando = false;
        });
      }
    }
  }

  @override
  void dispose() {
    nombreController.dispose();
    correoController.dispose();
    contrasenaController.dispose();
    confirmarContrasenaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: fondoRegistro,
      appBar: AppBar(
        title: const Text(
          'Crear cuenta',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: azulRegistro,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 15),

            const Text(
              '¡Bienvenido a CELEX Academy!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: azulRegistro,
              ),
            ),

            const SizedBox(height: 25),

            // Nombre completo.
            TextField(
              controller: nombreController,
              decoration: const InputDecoration(
                labelText: 'Nombre completo',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
            ),

            const SizedBox(height: 16),

            // Correo electrónico.
            TextField(
              controller: correoController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Correo electrónico',
                prefixIcon: Icon(Icons.email_outlined),
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
            ),

            const SizedBox(height: 16),

            // Categoría del estudiante.
            DropdownButtonFormField<String>(
              initialValue: categoriaSeleccionada,
              decoration: const InputDecoration(
                labelText: 'Categoría del estudiante',
                prefixIcon: Icon(Icons.school_outlined),
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
              items: const [
                DropdownMenuItem(
                  value: 'Comunidad IPN',
                  child: Text('Comunidad IPN'),
                ),
                DropdownMenuItem(
                  value: 'Público general',
                  child: Text('Público general'),
                ),
              ],
              onChanged: (valor) {
                setState(() {
                  categoriaSeleccionada = valor;
                });
              },
            ),

            const SizedBox(height: 16),

            // Contraseña.
            TextField(
              controller: contrasenaController,
              obscureText: !mostrarContrasena,
              decoration: InputDecoration(
                labelText: 'Contraseña',
                prefixIcon: const Icon(Icons.lock_outline),
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
                suffixIcon: IconButton(
                  icon: Icon(
                    mostrarContrasena
                        ? Icons.visibility_off
                        : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(() {
                      mostrarContrasena = !mostrarContrasena;
                    });
                  },
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Confirmar contraseña.
            TextField(
              controller: confirmarContrasenaController,
              obscureText: !mostrarConfirmacion,
              decoration: InputDecoration(
                labelText: 'Confirmar contraseña',
                prefixIcon: const Icon(Icons.lock_outline),
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
                suffixIcon: IconButton(
                  icon: Icon(
                    mostrarConfirmacion
                        ? Icons.visibility_off
                        : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(() {
                      mostrarConfirmacion = !mostrarConfirmacion;
                    });
                  },
                ),
              ),
            ),

            const SizedBox(height: 25),

            // Botón para registrar.
            ElevatedButton(
              onPressed: cargando ? null : registrarEstudiante,
              style: ElevatedButton.styleFrom(
                backgroundColor: azulRegistro,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              child: cargando
                  ? const CircularProgressIndicator(
                      color: Colors.white,
                    )
                  : const Text(
                      'Crear cuenta',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
