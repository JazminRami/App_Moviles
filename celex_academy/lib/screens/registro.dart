
import 'package:flutter/material.dart';

// Color institucional.
const Color azulRegistro = Color(0xFF023C87);

// Pantalla para crear una cuenta.
class Registro extends StatefulWidget {
  const Registro({super.key});

  @override
  State<Registro> createState() => _RegistroState();
}

class _RegistroState extends State<Registro> {
  // Controladores de los campos del formulario.
  final TextEditingController nombreController =
      TextEditingController();

  final TextEditingController correoController =
      TextEditingController();

  final TextEditingController contrasenaController =
      TextEditingController();

  final TextEditingController confirmarContrasenaController =
      TextEditingController();

  // Clave para validar el formulario.
  final GlobalKey<FormState> formularioKey = GlobalKey<FormState>();

  // Permiten mostrar u ocultar las contraseñas.
  bool mostrarContrasena = false;
  bool mostrarConfirmacion = false;

  @override
  void dispose() {
    // Liberamos los controladores al cerrar la pantalla.
    nombreController.dispose();
    correoController.dispose();
    contrasenaController.dispose();
    confirmarContrasenaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear cuenta'),
        backgroundColor: Colors.white,
        foregroundColor: azulRegistro,
        elevation: 0,
      ),

      body: SafeArea(
        child: Form(
          key: formularioKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),

                // Icono provisional.
                const Icon(
                  Icons.person_add_alt_1_rounded,
                  color: azulRegistro,
                  size: 70,
                ),

                const SizedBox(height: 18),

                const Text(
                  'Únete a CELEX Academy',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                    color: azulRegistro,
                  ),
                ),

                const SizedBox(height: 10),

                const Text(
                  'Crea tu cuenta para comenzar.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 15,
                  ),
                ),

                const SizedBox(height: 30),

                // Nombre completo.
                const Text(
                  'Nombre completo',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),

                const SizedBox(height: 8),

                TextFormField(
                  controller: nombreController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: 'Escribe tu nombre completo',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (valor) {
                    if (valor == null || valor.trim().isEmpty) {
                      return 'Escribe tu nombre completo.';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 20),

                // Correo electrónico.
                const Text(
                  'Correo electrónico',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),

                const SizedBox(height: 8),

                TextFormField(
                  controller: correoController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: 'ejemplo@correo.com',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (valor) {
                    if (valor == null || valor.trim().isEmpty) {
                      return 'Escribe tu correo electrónico.';
                    }

                    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$')
                        .hasMatch(valor.trim())) {
                      return 'Escribe un correo válido.';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 20),

                // Crear contraseña.
                const Text(
                  'Contraseña',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),

                const SizedBox(height: 8),

                TextFormField(
                  controller: contrasenaController,
                  obscureText: !mostrarContrasena,
                  decoration: InputDecoration(
                    hintText: 'Crea una contraseña',
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
                  validator: (valor) {
                    if (valor == null || valor.isEmpty) {
                      return 'Crea una contraseña.';
                    }

                    if (valor.length < 8) {
                      return 'Debe tener al menos 8 caracteres.';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 20),

                // Confirmar contraseña.
                const Text(
                  'Confirmar contraseña',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),

                const SizedBox(height: 8),

                TextFormField(
                  controller: confirmarContrasenaController,
                  obscureText: !mostrarConfirmacion,
                  decoration: InputDecoration(
                    hintText: 'Escribe nuevamente tu contraseña',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          mostrarConfirmacion = !mostrarConfirmacion;
                        });
                      },
                      icon: Icon(
                        mostrarConfirmacion
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (valor) {
                    if (valor == null || valor.isEmpty) {
                      return 'Confirma tu contraseña.';
                    }

                    if (valor != contrasenaController.text) {
                      return 'Las contraseñas no coinciden.';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 30),

                // Botón para validar el registro.
                SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    onPressed: crearCuenta,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: azulRegistro,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Crear cuenta',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Regresa a la pantalla anterior.
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'Ya tengo una cuenta',
                    style: TextStyle(color: azulRegistro),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Valida los datos antes de continuar.
  void crearCuenta() {
    if (!formularioKey.currentState!.validate()) {
      return;
    }

    // Por ahora solamente mostramos una confirmación.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Datos correctos. El registro aún no está conectado.',
        ),
      ),
    );
  }
}
