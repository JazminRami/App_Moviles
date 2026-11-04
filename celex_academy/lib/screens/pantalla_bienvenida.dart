
import 'package:flutter/material.dart';

// Importamos las pantallas a las que podremos navegar.
import 'inicio_sesion.dart';
import 'registro.dart';

// Colores de CELEX Academy.
const Color azulCelex = Color(0xFF023C87);
const Color azulClaro = Color(0xFFEAF1FB);

// Pantalla de bienvenida.
class PantallaBienvenida extends StatelessWidget {
  const PantallaBienvenida({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Evita que el contenido choque con las barras del teléfono.
      body: SafeArea(
        child: Center(
          // Permite desplazarse si la pantalla es pequeña.
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 28,
              vertical: 24,
            ),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 24),

                // Mostramos el logo guardado en la carpeta imagenes.
                Image.asset(
                  'assets/imagenes/Logo_App.png',
                  width: 180,
                  height: 180,
                  fit: BoxFit.contain,

                  // Si no se encuentra el logo, mostramos un icono.
                  errorBuilder: (context, error, stackTrace) {
                    print('ERROR AL CARGAR LOGO: $error');

                    return Container(
                      width: 180,
                      height: 180,
                      color: Colors.red,
                      child: const Center(
                        child: Text(
                          'ERROR LOGO',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 12),

                // Nombre de nuestra aplicación.
                const Text(
                  'CELEX Academy',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: azulCelex,
                  ),
                ),

                const SizedBox(height: 8),

                // Frase que acompaña al nombre.
                const Text(
                  'Tu camino para aprender nuevos idiomas',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.black54,
                  ),
                ),

                const SizedBox(height: 48),

                // Mensaje de bienvenida.
                const Text(
                  '¡Bienvenido!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF26364A),
                  ),
                ),

                const SizedBox(height: 12),

                // Descripción de la aplicación.
                const Text(
                  'Consulta idiomas, solicita tu inscripción '
                  'y da seguimiento a tus cursos de CELEX ESCOM '
                  'desde un solo lugar.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.5,
                    color: Colors.black54,
                  ),
                ),

                const SizedBox(height: 36),

                // Botón para abrir la pantalla de inicio de sesión.
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () {
                      // Navigator.push abre una pantalla nueva.
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const InicioSesion(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: azulCelex,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Iniciar sesión',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // Botón para abrir la pantalla de registro.
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: OutlinedButton(
                    onPressed: () {
                      // Abrimos directamente la pantalla de registro.
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const Registro(),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: azulCelex,
                      side: const BorderSide(
                        color: azulCelex,
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
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

                const SizedBox(height: 40),

                // Identificación institucional.
                const Text(
                  'CELEX ESCOM · IPN',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 1.2,
                    color: Colors.black45,
                  ),
                ),

                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
