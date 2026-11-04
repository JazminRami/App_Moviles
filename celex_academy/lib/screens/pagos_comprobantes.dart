
import 'package:flutter/material.dart';

// Colores de CELEX Academy.
const Color azulPagos = Color(0xFF023C87);
const Color fondoPagos = Color(0xFFEAF1FB);

class PagosComprobantes extends StatefulWidget {
  const PagosComprobantes({super.key});

  @override
  State<PagosComprobantes> createState() =>
      _PagosComprobantesState();
}

class _PagosComprobantesState extends State<PagosComprobantes> {
  // Datos de ejemplo. Después se obtendrán de la base de datos.
  String estadoPago = 'Pendiente';
  bool comprobanteEnviado = false;

  void _mostrarMensaje(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje)),
    );
  }

  void _simularEnvioComprobante() {
    setState(() {
      comprobanteEnviado = true;
      estadoPago = 'En revisión';
    });

    _mostrarMensaje(
      'Comprobante de demostración enviado para revisión.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: fondoPagos,

      appBar: AppBar(
        title: const Text(
          'Pagos y comprobantes',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: azulPagos,
        iconTheme: const IconThemeData(color: Colors.white),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Encabezado.
            const Text(
              'Mis pagos',
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.bold,
                color: azulPagos,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Consulta las instrucciones y el estado de tus pagos '
              'de los cursos de CELEX.',
              style: TextStyle(fontSize: 15),
            ),

            const SizedBox(height: 22),

            // Aviso importante.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.orange.shade300,
                ),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.deepOrange,
                    size: 28,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Importante: espera la confirmación de apertura '
                      'de tu grupo y las instrucciones oficiales antes '
                      'de realizar un pago. Realizarlo antes puede '
                      'ocasionar problemas con tu inscripción.',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),

            // Tarjeta del pago.
            Card(
              color: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.receipt_long,
                          color: azulPagos,
                          size: 30,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Inscripción a curso',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                              color: azulPagos,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    _DatoPago(
                      etiqueta: 'Idioma',
                      valor: 'Inglés',
                    ),

                    _DatoPago(
                      etiqueta: 'Nivel',
                      valor: 'Básico 1',
                    ),

                    _DatoPago(
                      etiqueta: 'Categoría',
                      valor: 'Por verificar',
                    ),

                    const Divider(height: 25),

                    const Text(
                      'Monto a pagar',
                      style: TextStyle(fontSize: 14),
                    ),

                    const SizedBox(height: 4),

                    const Text(
                      'Pendiente de asignación',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: azulPagos,
                      ),
                    ),

                    const SizedBox(height: 6),

                    const Text(
                      'El monto dependerá de la tarifa autorizada '
                      'para tu categoría de estudiante.',
                      style: TextStyle(fontSize: 13),
                    ),

                    const SizedBox(height: 18),

                    // Estado del pago.
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: fondoPagos,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: azulPagos,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Estado: $estadoPago',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: azulPagos,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Instrucciones de pago.
                    const Text(
                      'Instrucciones de pago',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 8),

                    const Text(
                      'Las instrucciones oficiales aparecerán aquí '
                      'cuando CELEX confirme la apertura del grupo. '
                      'No utilices datos bancarios de ejemplo.',
                      style: TextStyle(fontSize: 14),
                    ),

                    const SizedBox(height: 20),

                    // Botón de demostración.
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: comprobanteEnviado
                            ? null
                            : _simularEnvioComprobante,
                        icon: const Icon(Icons.upload_file),
                        label: Text(
                          comprobanteEnviado
                              ? 'Comprobante enviado'
                              : 'Simular envío de comprobante',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: azulPagos,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),

                    if (comprobanteEnviado) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'Tu comprobante de demostración está en revisión. '
                        'No se ha adjuntado ningún archivo real.',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 18),

            const Center(
              child: Text(
                'CELEX Academy · Pantalla de demostración',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Widget pequeño para mostrar cada dato del pago.
class _DatoPago extends StatelessWidget {
  final String etiqueta;
  final String valor;

  const _DatoPago({
    required this.etiqueta,
    required this.valor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              etiqueta,
              style: const TextStyle(color: Colors.black54),
            ),
          ),
          Expanded(
            child: Text(
              valor,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
