
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:celex_academy/main.dart';

void main() {
  // Comprobamos que la aplicación principal de CELEX Academy se abra.
  testWidgets('CELEX Academy inicia correctamente', (WidgetTester tester) async {
    // Iniciamos la aplicación.
    await tester.pumpWidget(const CelexAcademyApp());

    // Verificamos que exista el MaterialApp.
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
