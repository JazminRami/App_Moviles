
import 'package:flutter/material.dart';

// Colores principales de CELEX Academy.
const Color azulCertificado = Color(0xFF023C87);
const Color fondoCertificado = Color(0xFFEAF1FB);

// Pantalla de solicitud de certificado.
class SolicitudCertificado extends StatefulWidget {
  const SolicitudCertificado({super.key});

  @override
  State<SolicitudCertificado> createState() =>
      _SolicitudCertificadoState();
}

class _SolicitudCertificadoState extends State<SolicitudCertificado> {
  // Estado inicial de la solicitud.
  String estadoSolicitud = 'No solicitada';

  // Indica si el estudiante ya envió su solicitud.
  bool solicitudEnviada = false;

  // Método para enviar la solicitud de ejemplo.
  void _enviarSolicitud() {
    setState(() {
      solicitudEnviada = true;
      estadoSolicitud = 'En revisión';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tu solicitud de certificado fue registrada.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      // Barra superior.
      appBar: AppBar(
        backgroundColor: azulCertificado,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Solicitud de certificado',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),

      // Contenido de la pantalla.
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Encabezado.
              const Text(
                '¡Felicidades por llegar hasta aquí! 🎓',
                style: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                  color: azulCertificado,
                ),
              ),

              const SizedBox(height: 10),

              const Text(
                'Consulta la información para solicitar tu '
                'certificado de estudios de CELEX ESCOM.',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.black54,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 24),

              // Tarjeta informativa.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: fondoCertificado,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.workspace_premium_rounded,
                      color: azulCertificado,
                      size: 42,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Certificado CELEX',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: azulCertificado,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Al concluir satisfactoriamente el nivel '
                      'Avanzado 5, podrás iniciar el proceso '
                      'para solicitar tu certificado.',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Requisitos.
              const Text(
                'Requisitos',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: azulCertificado,
                ),
              ),

              const SizedBox(height: 12),

              _TarjetaRequisito(
                icono: Icons.check_circle_outline,
                texto: 'Haber concluido el nivel Avanzado 5.',
              ),

              _TarjetaRequisito(
                icono: Icons.school_outlined,
                texto: 'Contar con el registro de tus resultados.',
              ),

              _TarjetaRequisito(
                icono: Icons.receipt_long_outlined,
                texto: 'Realizar el pago correspondiente cuando '
                    'CELEX indique las instrucciones.',
              ),

              const SizedBox(height: 24),

              // Estado de la solicitud.
              const Text(
                'Estado de mi solicitud',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: azulCertificado,
                ),
              ),

              const SizedBox(height: 12),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: fondoCertificado,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFFD2E0F5),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      solicitudEnviada
                          ? Icons.hourglass_top_rounded
                          : Icons.info_outline,
                      color: azulCertificado,
                      size: 30,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Estado actual',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            estadoSolicitud,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: azulCertificado,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Información sobre el pago y la entrega.
              const Text(
                'Pago y entrega',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: azulCertificado,
                ),
              ),

              const SizedBox(height: 12),

              _TarjetaInformacion(
                icono: Icons.payments_outlined,
                titulo: 'Pago del certificado',
                descripcion:
                    'El costo y las instrucciones de pago '
                    'deberán consultarse directamente con CELEX.',
              ),

              _TarjetaInformacion(
                icono: Icons.location_on_outlined,
                titulo: 'Entrega del certificado',
                descripcion:
                    'La entrega se realizará en las instalaciones '
                    'de CELEX ESCOM, de acuerdo con las indicaciones '
                    'que proporcione el centro.',
              ),

              const SizedBox(height: 24),

              // Botón para registrar la solicitud.
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed:
                      solicitudEnviada ? null : _enviarSolicitud,
                  icon: const Icon(Icons.send_rounded),
                  label: Text(
                    solicitudEnviada
                        ? 'Solicitud enviada'
                        : 'Solicitar certificado',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: azulCertificado,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade400,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              const Center(
                child: Text(
                  'CELEX ESCOM · IPN',
                  style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 1.2,
                    color: Colors.black45,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Tarjeta reutilizable para mostrar los requisitos.
class _TarjetaRequisito extends StatelessWidget {
  final IconData icono;
  final String texto;

  const _TarjetaRequisito({
    required this.icono,
    required this.texto,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icono,
            color: azulCertificado,
            size: 23,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(
                fontSize: 14,
                height: 1.4,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Tarjeta reutilizable para pago y entrega.
class _TarjetaInformacion extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String descripcion;

  const _TarjetaInformacion({
    required this.icono,
    required this.titulo,
    required this.descripcion,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFD2E0F5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icono,
            color: azulCertificado,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: azulCertificado,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  descripcion,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
