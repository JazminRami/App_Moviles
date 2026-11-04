
import 'package:flutter/material.dart';

// Importamos la pantalla que aparecerá al abrir la aplicación.
import 'screens/pantalla_bienvenida.dart';

// Colores oficiales de CELEX Academy.
const Color azulCelex = Color(0xFF023C87);
const Color azulClaro = Color(0xFFEAF1FB);

// Punto de entrada de la aplicación.
void main() {
  runApp(const CelexAcademyApp());
}

// Widget principal de la aplicación.
class CelexAcademyApp extends StatelessWidget {
  const CelexAcademyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Nombre de nuestra aplicación.
      title: 'CELEX Academy',

      // Ocultamos la etiqueta de depuración.
      debugShowCheckedModeBanner: false,

      // Configuración general del diseño.
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: azulCelex,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'Roboto',
      ),

      // Primera pantalla que verá el estudiante.
      home: const PantallaBienvenida(),
    );
  }
}
