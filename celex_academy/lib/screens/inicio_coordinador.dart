
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Importamos las pantallas del coordinador.
import 'solicitudes_coordinador.dart';
import 'verificaciones_ipn_coordinador.dart';
import 'periodos_coordinador.dart';
import 'grupos_coordinador.dart';
import 'pagos_coordinador.dart';
import 'calificaciones_coordinador.dart';
import 'profesores_coordinador.dart';

// Colores institucionales.
const Color azulCoordinador = Color(0xFF023C87);
const Color fondoCoordinador = Color(0xFFEAF1FB);

class InicioCoordinador extends StatelessWidget {
  const InicioCoordinador({super.key});

  // Cerrar sesión del coordinador.
  Future<void> cerrarSesion(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();

    if (!context.mounted) return;

    Navigator.pushNamedAndRemoveUntil(
      context,
      '/',
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: fondoCoordinador,
      appBar: AppBar(
        title: const Text('Panel del coordinador'),
        backgroundColor: azulCoordinador,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () => cerrarSesion(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '¡Bienvenido, coordinador!',
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.bold,
                color: azulCoordinador,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Desde aquí podrás administrar los procesos académicos '
              'de CELEX Academy.',
              style: TextStyle(
                fontSize: 15,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 25),

            // Administración de periodos.
            _crearOpcion(
              context: context,
              icono: Icons.calendar_month_outlined,
              titulo: 'Periodos',
              descripcion:
                  'Crear periodos y configurar su calendario académico.',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PeriodosCoordinador(),
                  ),
                );
              },
            ),

            // Apartado de solicitudes.
            _crearOpcion(
              context: context,
              icono: Icons.assignment_outlined,
              titulo: 'Solicitudes',
              descripcion:
                  'Revisar y gestionar solicitudes de estudiantes.',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SolicitudesCoordinador(),
                  ),
                );
              },
            ),

            // Apartado de verificaciones IPN.
            _crearOpcion(
              context: context,
              icono: Icons.verified_user_outlined,
              titulo: 'Verificaciones IPN',
              descripcion:
                  'Revisar credenciales y horarios de estudiantes.',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        const VerificacionesIpnCoordinador(),
                  ),
                );
              },
            ),

            // Administración de grupos.
            _crearOpcion(
              context: context,
              icono: Icons.groups_outlined,
              titulo: 'Grupos',
              descripcion:
                  'Consultar demanda, distribuir estudiantes y administrar grupos.',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const GruposCoordinador(),
                  ),
                );
              },
            ),

            // Administración de profesores.
            _crearOpcion(
              context: context,
              icono: Icons.people_alt_outlined,
              titulo: 'Profesores',
              descripcion:
                  'Registrar, consultar y administrar profesores de CELEX.',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        const ProfesoresCoordinador(),
                  ),
                );
              },
            ),

            // Apartado independiente de pagos.
            _crearOpcion(
              context: context,
              icono: Icons.receipt_long_outlined,
              titulo: 'Pagos y comprobantes',
              descripcion:
                  'Revisar comprobantes y confirmar o rechazar pagos.',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PagosCoordinador(),
                  ),
                );
              },
            ),

            // Administración de calificaciones.
            _crearOpcion(
              context: context,
              icono: Icons.school_outlined,
              titulo: 'Calificaciones',
              descripcion:
                  'Registrar resultados y avances académicos.',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        const CalificacionesCoordinador(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // Construye cada opción del panel.
  Widget _crearOpcion({
    required BuildContext context,
    required IconData icono,
    required String titulo,
    required String descripcion,
    VoidCallback? onTap,
  }) {
    return Card(
      color: Colors.white,
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Icon(
                icono,
                color: azulCoordinador,
                size: 34,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: azulCoordinador,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      descripcion,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.black45,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
