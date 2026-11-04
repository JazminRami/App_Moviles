
import 'package:flutter/material.dart';

// Colores de CELEX Academy.
const Color azulSolicitud = Color(0xFF023C87);
const Color fondoSolicitud = Color(0xFFEAF1FB);

// Pantalla para solicitar un trámite.
class NuevaSolicitud extends StatefulWidget {
  const NuevaSolicitud({super.key});

  @override
  State<NuevaSolicitud> createState() => _NuevaSolicitudState();
}

class _NuevaSolicitudState extends State<NuevaSolicitud> {
  // Permite validar los campos del formulario.
  final GlobalKey<FormState> formularioKey = GlobalKey<FormState>();

  // Opciones seleccionadas por el estudiante.
  String? tipoTramite;
  String? idiomaSeleccionado;
  String? nivelSeleccionado;

  // Niveles disponibles como ejemplos.
  final List<String> niveles = [
    'Básico 1',
    'Básico 2',
    'Básico 3',
    'Intermedio 1',
    'Intermedio 2',
    'Intermedio 3',
    'Avanzado 1',
    'Avanzado 2',
    'Avanzado 3',
    'Avanzado 4',
    'Avanzado 5',
  ];

  // Indica si se trata de un examen de colocación.
  bool get esExamen =>
      tipoTramite == 'Examen de colocación';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      // Barra superior.
      appBar: AppBar(
        title: const Text('Nueva solicitud'),
        backgroundColor: azulSolicitud,
        foregroundColor: Colors.white,
        elevation: 0,
      ),

      body: SafeArea(
        child: Form(
          key: formularioKey,
          child: ListView(
            padding: const EdgeInsets.all(22),
            children: [
              // Encabezado.
              const Icon(
                Icons.assignment_add,
                size: 58,
                color: azulSolicitud,
              ),

              const SizedBox(height: 14),

              const Text(
                'Solicita tu trámite',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                  color: azulSolicitud,
                ),
              ),

              const SizedBox(height: 10),

              const Text(
                'Completa los siguientes datos para iniciar '
                'tu proceso en CELEX ESCOM.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: Colors.black54,
                ),
              ),

              const SizedBox(height: 28),

              // Primer campo: tipo de trámite.
              const Text(
                '¿Qué trámite deseas realizar?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 9),

              DropdownButtonFormField<String>(
                // Valor inicial del menú desplegable.
                initialValue: tipoTramite,
                isExpanded: true,
                decoration: InputDecoration(
                  prefixIcon: const Icon(
                    Icons.assignment_outlined,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 16,
                  ),
                ),
                hint: const Text('Selecciona un trámite'),
                items: const [
                  DropdownMenuItem(
                    value: 'Inscripción a curso',
                    child: Text('Inscripción a curso'),
                  ),
                  DropdownMenuItem(
                    value: 'Examen de colocación',
                    child: Text('Examen de colocación'),
                  ),
                ],
                validator: (valor) {
                  if (valor == null) {
                    return 'Selecciona el tipo de trámite.';
                  }
                  return null;
                },
                onChanged: (valor) {
                  setState(() {
                    tipoTramite = valor;

                    // Si cambia el trámite, reiniciamos el nivel.
                    nivelSeleccionado = null;
                  });
                },
              ),

              const SizedBox(height: 22),

              // Segundo campo: idioma.
              const Text(
                'Idioma',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 9),

              DropdownButtonFormField<String>(
                // Valor inicial del menú desplegable.
                initialValue: idiomaSeleccionado,
                isExpanded: true,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.language),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 16,
                  ),
                ),
                hint: const Text('Selecciona un idioma'),
                items: const [
                  DropdownMenuItem(
                    value: 'Inglés',
                    child: Text('Inglés'),
                  ),
                  DropdownMenuItem(
                    value: 'Francés',
                    child: Text('Francés'),
                  ),
                ],
                validator: (valor) {
                  if (valor == null) {
                    return 'Selecciona un idioma.';
                  }
                  return null;
                },
                onChanged: (valor) {
                  setState(() {
                    idiomaSeleccionado = valor;
                  });
                },
              ),

              const SizedBox(height: 22),

              // El nivel solo se solicita para inscripción.
              if (!esExamen) ...[
                const Text(
                  'Nivel al que deseas ingresar',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 9),

                DropdownButtonFormField<String>(
                  // Valor inicial del menú desplegable.
                  initialValue: nivelSeleccionado,
                  isExpanded: true,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.menu_book),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 16,
                    ),
                  ),
                  hint: const Text('Selecciona un nivel'),
                  items: niveles.map((nivel) {
                    return DropdownMenuItem<String>(
                      value: nivel,
                      child: Text(nivel),
                    );
                  }).toList(),
                  validator: (valor) {
                    if (!esExamen && valor == null) {
                      return 'Selecciona el nivel que deseas cursar.';
                    }
                    return null;
                  },
                  onChanged: (valor) {
                    setState(() {
                      nivelSeleccionado = valor;
                    });
                  },
                ),

                const SizedBox(height: 22),
              ],

              // Aviso que cambia según el trámite.
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: fondoSolicitud,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: const Color(0xFFD2E0F5),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: azulSolicitud,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        esExamen
                            ? 'El examen de colocación permite '
                                'determinar tu nivel. La fecha, el '
                                'pago y la asignación se confirmarán '
                                'según las indicaciones de CELEX.'
                            : 'Enviar esta solicitud no garantiza '
                                'que el grupo esté abierto. Espera '
                                'la confirmación antes de realizar '
                                'cualquier pago.',
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Botón para enviar la solicitud de demostración.
              SizedBox(
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: enviarSolicitud,
                  icon: const Icon(Icons.send_rounded),
                  label: const Text(
                    'Enviar solicitud',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: azulSolicitud,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              const Text(
                'Formulario de demostración: la solicitud '
                'todavía no se guarda en una base de datos.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black45,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Valida los campos y muestra un resumen.
  void enviarSolicitud() {
    // Si hay un campo obligatorio vacío, no continuamos.
    if (!formularioKey.currentState!.validate()) {
      return;
    }

    // En un examen todavía no se asigna un nivel.
    final String nivelFinal =
        esExamen ? 'Por determinar mediante examen' : nivelSeleccionado!;

    // Mostramos una confirmación de prueba.
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          icon: const Icon(
            Icons.check_circle_outline,
            color: azulSolicitud,
            size: 48,
          ),
          title: const Text('Solicitud preparada'),
          content: Text(
            'Tipo de trámite: $tipoTramite\n\n'
            'Idioma: $idiomaSeleccionado\n\n'
            'Nivel: $nivelFinal\n\n'
            'Este es un ejemplo. Tu solicitud no se ha '
            'guardado ni enviado a CELEX.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Volver al formulario'),
            ),
            ElevatedButton(
              onPressed: () {
                // Cerramos el aviso y regresamos al menú.
                Navigator.pop(context);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: azulSolicitud,
                foregroundColor: Colors.white,
              ),
              child: const Text('Finalizar'),
            ),
          ],
        );
      },
    );
  }
}
