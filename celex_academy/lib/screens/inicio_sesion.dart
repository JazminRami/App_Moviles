
import 'package:flutter/material.dart';

// Importamos las pantallas a las que podremos navegar.
import 'registro.dart';
import 'inicio_estudiante.dart';

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

  @override
  void dispose() {
    // Liberamos los controladores al cerrar la pantalla.
    correoController.dispose();
    contrasenaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Barra superior con botón para regresar.
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

              // Icono provisional de la institución.
              const Icon(
                Icons.school_rounded,
                color: azulLogin,
                size: 76,
              ),

              const SizedBox(height: 20),

              // Título de la pantalla.
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

              // Etiqueta del campo de correo.
              const Text(
                'Correo electrónico',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),

              const SizedBox(height: 8),

              // Campo para escribir el correo.
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

              // Etiqueta del campo de contraseña.
              const Text(
                'Contraseña',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),

              const SizedBox(height: 8),

              // Campo para escribir la contraseña.
              TextField(
                controller: contrasenaController,

                // Si es false, la contraseña permanece oculta.
                obscureText: !mostrarContrasena,

                decoration: InputDecoration(
                  hintText: 'Escribe tu contraseña',
                  prefixIcon: const Icon(Icons.lock_outline),

                  // Botón del ojo para mostrar u ocultar la contraseña.
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

              // Botón para entrar a la aplicación.
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: () {
                    // Por ahora no validamos el correo ni la contraseña.
                    // Abrimos la pantalla principal como demostración.
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const InicioEstudiante(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: azulLogin,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Entrar',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 22),

              // Enlace para quien todavía no tiene cuenta.
              TextButton(
                onPressed: () {
                  // Abrimos la pantalla de registro.
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
