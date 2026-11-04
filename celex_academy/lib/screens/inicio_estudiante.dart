
import 'package:flutter/material.dart';
import 'idiomas_niveles.dart';
import 'historial_solicitudes.dart';
import 'pagos_comprobantes.dart';
import 'calificaciones.dart';
import 'perfil_estudiante.dart';
import 'horarios.dart';
import 'solicitud_certificado.dart';

// Color principal de CELEX Academy.
const Color azulInicio = Color(0xFF023C87);
const Color azulFondo = Color(0xFFEAF1FB);

// Pantalla principal del estudiante.
class InicioEstudiante extends StatelessWidget {
  const InicioEstudiante({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      // Barra superior de la aplicación.
      appBar: AppBar(
        backgroundColor: azulInicio,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'CELEX Academy',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          // Botón para acceder al perfil.
          IconButton(
            tooltip: 'Mi perfil',
            icon: const Icon(Icons.person_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PerfilEstudiante(),
                ),
              );
            },
          ),
        ],
      ),

      // Contenido de la pantalla.
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Saludo al estudiante.
              const Text(
                '¡Hola, estudiante! 👋',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                  color: azulInicio,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                '¿Qué te gustaría hacer hoy?',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                ),
              ),

              const SizedBox(height: 24),

              // Tarjeta de bienvenida.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: azulInicio,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.school_rounded,
                      color: Colors.white,
                      size: 38,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Tu futuro comienza con un idioma',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Consulta los cursos y da seguimiento '
                      'a tus procesos de CELEX ESCOM.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              const Text(
                'Mis servicios',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: azulInicio,
                ),
              ),

              const SizedBox(height: 16),

              // Primera fila: Idiomas y solicitudes.
              Row(
                children: [
                  Expanded(
                    child: _TarjetaServicio(
                      icono: Icons.language_rounded,
                      titulo: 'Idiomas y niveles',
                      descripcion: 'Explora los cursos',
                      alPresionar: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const IdiomasNiveles(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _TarjetaServicio(
                      icono: Icons.assignment_outlined,
                      titulo: 'Mis solicitudes',
                      descripcion: 'Consulta su estado',
                      alPresionar: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const HistorialSolicitudes(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Segunda fila: Pagos y calificaciones.
              Row(
                children: [
                  Expanded(
                    child: _TarjetaServicio(
                      icono: Icons.receipt_long_rounded,
                      titulo: 'Pagos',
                      descripcion: 'Consulta tus pagos',
                      alPresionar: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const PagosComprobantes(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _TarjetaServicio(
                      icono: Icons.school_outlined,
                      titulo: 'Calificaciones',
                      descripcion: 'Revisa tus resultados',
                      alPresionar: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const Calificaciones(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              
              // Tercera fila: Horarios y certificado.
              const SizedBox(height: 14),

              Row(
                children: [
                  // Tarjeta de horarios.
                  Expanded(
                    child: _TarjetaServicio(
                      icono: Icons.calendar_month,
                      titulo: 'Mis horarios',
                      descripcion: 'Consulta tus clases',
                      alPresionar: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const Horarios(),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(width: 14),

                  // Tarjeta de certificado.
                  Expanded(
                    child: _TarjetaServicio(
                      icono: Icons.workspace_premium_rounded,
                      titulo: 'Certificado',
                      descripcion: 'Solicita tu certificado',
                      alPresionar: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const SolicitudCertificado(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Aviso importante para los estudiantes.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: azulFondo,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFFD2E0F5),
                  ),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: azulInicio,
                      size: 26,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Aviso importante',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: azulInicio,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Antes de realizar un pago, verifica '
                            'tu solicitud y confirma que el grupo '
                            'haya sido abierto.',
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.5,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

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

// Tarjeta reutilizable para los servicios.
class _TarjetaServicio extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String descripcion;
  final VoidCallback alPresionar;

  const _TarjetaServicio({
    required this.icono,
    required this.titulo,
    required this.descripcion,
    required this.alPresionar,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: azulFondo,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: alPresionar,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(minHeight: 150),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFD2E0F5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icono,
                size: 32,
                color: azulInicio,
              ),
              const SizedBox(height: 14),
              Text(
                titulo,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: azulInicio,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                descripcion,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
