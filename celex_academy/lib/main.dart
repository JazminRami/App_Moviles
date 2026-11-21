
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/pantalla_bienvenida.dart';

// Colores oficiales de CELEX Academy.
const Color azulCelex = Color(0xFF023C87);
const Color azulClaro = Color(0xFFEAF1FB);

// Punto de entrada de la aplicación.
Future<void> main() async {
  // Prepara Flutter antes de inicializar Supabase.
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa la conexión con Supabase.
  await Supabase.initialize(
    url: 'https://jqvtdikadsistryvbkjr.supabase.co',
    publishableKey: 'sb_publishable_1tZQPRDJK-8MMOVbUJWohw_GLj5mIU7',
  );

  // Inicia la aplicación después de conectar Supabase.
  runApp(const CelexAcademyApp());
}

// Widget principal de la aplicación.
class CelexAcademyApp extends StatelessWidget {
  const CelexAcademyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CELEX Academy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: azulCelex,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'Roboto',
      ),
      home: const PantallaBienvenida(),
    );
  }
}