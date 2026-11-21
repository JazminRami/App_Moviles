
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

const Color azulVerificaciones = Color(0xFF023C87);
const Color fondoVerificaciones = Color(0xFFEAF1FB);

class VerificacionesIpnCoordinador extends StatefulWidget {
  const VerificacionesIpnCoordinador({super.key});

  @override
  State<VerificacionesIpnCoordinador> createState() =>
      _VerificacionesIpnCoordinadorState();
}

class _VerificacionesIpnCoordinadorState
    extends State<VerificacionesIpnCoordinador> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> verificaciones = [];
  bool cargando = true;
  String? errorCarga;
  int? verificandoId;

  @override
  void initState() {
    super.initState();
    cargarVerificaciones();
  }

  Future<void> cargarVerificaciones() async {
    if (mounted) {
      setState(() {
        cargando = true;
        errorCarga = null;
      });
    }

    try {
      final respuesta = await supabase
          .from('verificaciones_ipn_periodo')
          .select('''
            id,
            estudiante_id,
            periodo_id,
            categoria_solicitada,
            estado,
            documento_path,
            tipo_documento,
            fecha_registro,
            observaciones,
            perfiles_estudiantes(nombre_completo, correo),
            periodos(nombre)
          ''')
          .eq('estado', 'Pendiente')
          .order('fecha_registro', ascending: true);

      final lista = List<Map<String, dynamic>>.from(respuesta);

      if (!mounted) return;

      setState(() {
        verificaciones = lista;
        cargando = false;
        errorCarga = null;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        cargando = false;
        errorCarga = error.toString();
      });
    }
  }

  String formatearFecha(dynamic fecha) {
    if (fecha == null) return 'Sin fecha';

    final date = DateTime.parse(fecha.toString()).toLocal();

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  Future<String> obtenerUrlDocumento(String ruta) async {
    return supabase.storage
        .from('documentos-ipn')
        .createSignedUrl(ruta, 600);
  }

  Future<void> abrirDocumento(
    Map<String, dynamic> verificacion,
  ) async {
    try {
      final ruta = verificacion['documento_path']?.toString();

      if (ruta == null || ruta.isEmpty) {
        throw Exception('No se encontró la ruta del documento.');
      }

      final url = await obtenerUrlDocumento(ruta);

      if (!mounted) return;

      final tipo = verificacion['tipo_documento']?.toString() ?? '';

      if (tipo == 'PDF de credencial' ||
          tipo == 'PDF de horario') {
        final uri = Uri.parse(url);
        final abierto = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );

        if (!abierto) {
          throw Exception('No se pudo abrir el PDF.');
        }
      } else {
        await showDialog<void>(
          context: context,
          builder: (dialogContext) {
            return Dialog(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Documento del estudiante',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: azulVerificaciones,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 450),
                      child: InteractiveViewer(
                        child: Image.network(
                          url,
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return const Padding(
                              padding: EdgeInsets.all(30),
                              child: CircularProgressIndicator(
                                color: azulVerificaciones,
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return const Padding(
                              padding: EdgeInsets.all(20),
                              child: Text(
                                'No se pudo mostrar la fotografía.',
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () =>
                          Navigator.of(dialogContext).pop(),
                      child: const Text('Cerrar'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }
    } catch (error) {
      mostrarMensaje(
        'No se pudo abrir el documento: $error',
        error: true,
      );
    }
  }

  Future<String?> solicitarObservaciones() {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _DialogoMotivoRechazo(),
    );
  }

  void mostrarMensaje(String mensaje, {bool error = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: error ? Colors.red : Colors.green,
      ),
    );
  }

  Future<void> resolverVerificacion({
    required int id,
    required String resultado,
    String? observaciones,
  }) async {
    if (verificandoId != null) return;

    setState(() {
      verificandoId = id;
    });

    try {
      await supabase.rpc(
        'resolver_verificacion_ipn',
        params: {
          'p_verificacion_id': id,
          'p_resultado': resultado,
          'p_observaciones': observaciones,
        },
      );

      if (!mounted) return;

      setState(() {
        verificaciones.removeWhere(
          (elemento) => (elemento['id'] as num).toInt() == id,
        );
        verificandoId = null;
      });

      mostrarMensaje(
        resultado == 'Verificada'
            ? 'Documentación aprobada correctamente.'
            : 'Documentación rechazada correctamente.',
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        verificandoId = null;
      });

      mostrarMensaje(
        'No se pudo resolver la verificación: $error',
        error: true,
      );
    }
  }

  Future<void> rechazar(int id) async {
    final motivo = await solicitarObservaciones();

    if (!mounted || motivo == null || motivo.trim().isEmpty) {
      return;
    }

    await resolverVerificacion(
      id: id,
      resultado: 'Rechazada',
      observaciones: motivo.trim(),
    );
  }

  Widget construirVerificacion(
    Map<String, dynamic> verificacion,
  ) {
    final estudiante =
        verificacion['perfiles_estudiantes'] as Map<String, dynamic>? ?? {};

    final periodo =
        verificacion['periodos'] as Map<String, dynamic>? ?? {};

    final id = (verificacion['id'] as num).toInt();
    final nombre = estudiante['nombre_completo'] ?? 'Nombre no disponible';
    final correo = estudiante['correo'] ?? 'Correo no disponible';
    final categoria =
        verificacion['categoria_solicitada'] ?? 'Sin categoría';
    final tipoDocumento =
        verificacion['tipo_documento'] ?? 'Documento no especificado';
    final periodoNombre = periodo['nombre'] ?? 'Periodo no disponible';

    final estaProcesando = verificandoId == id;
    final hayProcesoActivo = verificandoId != null;

    return Card(
      color: Colors.white,
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'VER-${id.toString().padLeft(4, '0')}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: azulVerificaciones,
                    fontSize: 16,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Pendiente',
                    style: TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 25),
            const Text(
              'Datos del estudiante',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: azulVerificaciones,
              ),
            ),
            const SizedBox(height: 6),
            Text(nombre),
            Text(correo, style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 15),
            const Text(
              'Información de la verificación',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: azulVerificaciones,
              ),
            ),
            const SizedBox(height: 6),
            Text('Categoría solicitada: $categoria'),
            Text('Periodo: $periodoNombre'),
            Text('Tipo de documento: $tipoDocumento'),
            Text(
              'Fecha de envío: ${formatearFecha(verificacion['fecha_registro'])}',
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: hayProcesoActivo
                  ? null
                  : () => abrirDocumento(verificacion),
              icon: const Icon(Icons.visibility_outlined),
              label: const Text('Ver documento'),
              style: OutlinedButton.styleFrom(
                foregroundColor: azulVerificaciones,
                minimumSize: const Size(double.infinity, 45),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: hayProcesoActivo
                        ? null
                        : () => resolverVerificacion(
                              id: id,
                              resultado: 'Verificada',
                            ),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Aprobar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 45),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: hayProcesoActivo ? null : () => rechazar(id),
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Rechazar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 45),
                    ),
                  ),
                ),
              ],
            ),
            if (estaProcesando) ...[
              const SizedBox(height: 12),
              const Center(
                child: CircularProgressIndicator(
                  color: azulVerificaciones,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: fondoVerificaciones,
      appBar: AppBar(
        title: const Text('Verificaciones IPN'),
        backgroundColor: azulVerificaciones,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: cargando ? null : cargarVerificaciones,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: cargando
          ? const Center(
              child: CircularProgressIndicator(
                color: azulVerificaciones,
              ),
            )
          : errorCarga != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 55,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No se pudieron cargar las verificaciones.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(errorCarga!, textAlign: TextAlign.center),
                        const SizedBox(height: 15),
                        ElevatedButton.icon(
                          onPressed: cargarVerificaciones,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  color: azulVerificaciones,
                  onRefresh: cargarVerificaciones,
                  child: verificaciones.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const [
                            SizedBox(height: 150),
                            Icon(
                              Icons.verified_user_outlined,
                              size: 70,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 15),
                            Center(
                              child: Text(
                                'No hay verificaciones pendientes.',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.black54,
                                ),
                              ),
                            ),
                            SizedBox(height: 20),
                            Center(
                              child: Text(
                                'Desliza hacia abajo para actualizar.',
                                style: TextStyle(color: Colors.black45),
                              ),
                            ),
                          ],
                        )
                      : ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(18),
                          children: [
                            Text(
                              'Verificaciones pendientes: ${verificaciones.length}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: azulVerificaciones,
                              ),
                            ),
                            const SizedBox(height: 15),
                            ...verificaciones.map(construirVerificacion),
                          ],
                        ),
                ),
    );
  }
}

// El controlador vive y se destruye dentro del propio diálogo.
class _DialogoMotivoRechazo extends StatefulWidget {
  const _DialogoMotivoRechazo();

  @override
  State<_DialogoMotivoRechazo> createState() =>
      _DialogoMotivoRechazoState();
}

class _DialogoMotivoRechazoState extends State<_DialogoMotivoRechazo> {
  final TextEditingController controlador = TextEditingController();

  @override
  void dispose() {
    controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rechazar documentación'),
      content: TextField(
        controller: controlador,
        maxLines: 3,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Motivo del rechazo',
          hintText: 'Explica por qué se rechaza el documento.',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            final motivo = controlador.text.trim();
            if (motivo.isEmpty) return;
            Navigator.of(context).pop(motivo);
          },
          child: const Text('Continuar'),
        ),
      ],
    );
  }
}
