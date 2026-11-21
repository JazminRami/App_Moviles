
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

// Colores institucionales de CELEX Academy.
const Color azulPagosCoord = Color(0xFF023C87);
const Color fondoPagosCoord = Color(0xFFEAF1FB);

class PagosCoordinador extends StatefulWidget {
  const PagosCoordinador({super.key});

  @override
  State<PagosCoordinador> createState() => _PagosCoordinadorState();
}

class _PagosCoordinadorState extends State<PagosCoordinador> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> periodos = [];
  int? periodoSeleccionado;

  late Future<List<Map<String, dynamic>>> futurosPagos;

  final List<String> estadosActivos = [
    'Inscripciones',
    'Colocacion',
    'Distribucion',
    'Pagos',
    'En curso',
  ];

  @override
  void initState() {
    super.initState();
    futurosPagos = cargarDatosIniciales();
  }

  // Cargar los periodos y seleccionar automáticamente el correspondiente.
  Future<List<Map<String, dynamic>>> cargarDatosIniciales() async {
    final respuestaPeriodos = await supabase
        .from('periodos')
        .select('id, nombre, fecha_inicio, estado')
        .order('fecha_inicio', ascending: false);

    periodos = List<Map<String, dynamic>>.from(respuestaPeriodos);

    if (periodos.isEmpty) {
      periodoSeleccionado = null;
      return [];
    }

    final periodoActivo = periodos.cast<Map<String, dynamic>?>().firstWhere(
      (periodo) =>
          periodo != null &&
          estadosActivos.contains(periodo['estado']?.toString()),
      orElse: () => null,
    );

    periodoSeleccionado = periodoActivo != null
        ? int.tryParse(periodoActivo['id'].toString())
        : int.tryParse(periodos.first['id'].toString());

    return obtenerPagos();
  }

  // Consultar todos los pagos del periodo seleccionado.
  // Se conservan para poder mostrar pendientes, confirmados y rechazados.
  Future<List<Map<String, dynamic>>> obtenerPagos() async {
    if (periodoSeleccionado == null) return [];

    final respuestaSolicitudes = await supabase
        .from('solicitudes')
        .select('id')
        .eq('periodo_id', periodoSeleccionado!);

    final solicitudes =
        List<Map<String, dynamic>>.from(respuestaSolicitudes);

    if (solicitudes.isEmpty) return [];

    final idsSolicitudes =
        solicitudes.map((solicitud) => solicitud['id']).toList();

    final respuesta = await supabase
        .from('pagos')
        .select('''
          id,
          estudiante_id,
          solicitud_id,
          tipo_pago,
          monto,
          comprobante_url,
          estado,
          fecha_pago,
          fecha_registro,
          notas_coordinador,
          solicitudes!pagos_solicitud_id_fkey(
            id,
            tipo_tramite,
            estado,
            idioma_id,
            nivel_id,
            idiomas(nombre),
            nivel_solicitado:niveles!solicitudes_nivel_id_fkey(
              nombre,
              orden
            )
          ),
          perfiles_estudiantes!pagos_estudiante_id_fkey(
            nombre_completo,
            correo
          )
        ''')
        .inFilter('solicitud_id', idsSolicitudes)
        .order('fecha_registro', ascending: false);

    return List<Map<String, dynamic>>.from(respuesta);
  }

  // Actualizar la lista de pagos.
  Future<void> actualizarPagos() async {
    setState(() {
      futurosPagos = obtenerPagos();
    });

    await futurosPagos;
  }

  // Cambiar el periodo consultado.
  void cambiarPeriodo(int? nuevoPeriodo) {
    if (nuevoPeriodo == null || nuevoPeriodo == periodoSeleccionado) {
      return;
    }

    setState(() {
      periodoSeleccionado = nuevoPeriodo;
      futurosPagos = obtenerPagos();
    });
  }

  String obtenerNombrePeriodo() {
    final periodo = periodos.where(
      (p) => p['id'].toString() == periodoSeleccionado.toString(),
    );

    if (periodo.isEmpty) return 'Periodo no disponible';

    return periodo.first['nombre']?.toString() ?? 'Periodo';
  }

  String nombreEstadoPago(String estado) {
    if (estado == 'Pendiente de revisión') {
      return 'Pendiente de confirmar';
    }

    return estado;
  }

  Color obtenerColorEstado(String estado) {
    switch (estado) {
      case 'Confirmado':
        return Colors.green;
      case 'Rechazado':
        return Colors.red;
      case 'Pendiente de revisión':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String formatearFecha(dynamic fecha) {
    if (fecha == null) return 'Sin fecha';

    final date = DateTime.tryParse(fecha.toString());
    if (date == null) return 'Sin fecha';

    final local = date.toLocal();

    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year}';
  }

  String formatearMonto(dynamic monto) {
    if (monto == null) return 'No disponible';

    return '\$${(monto as num).toStringAsFixed(2)} MXN';
  }

  Map<String, dynamic> obtenerRelacion(dynamic relacion) {
    if (relacion is Map) {
      return Map<String, dynamic>.from(relacion);
    }

    if (relacion is List && relacion.isNotEmpty) {
      return Map<String, dynamic>.from(relacion.first);
    }

    return {};
  }

  Map<String, dynamic> obtenerSolicitud(Map<String, dynamic> pago) {
    return obtenerRelacion(pago['solicitudes']);
  }

  Map<String, dynamic> obtenerEstudiante(Map<String, dynamic> pago) {
    return obtenerRelacion(pago['perfiles_estudiantes']);
  }

  bool esPagoExamen(Map<String, dynamic> pago) {
    return pago['tipo_pago'] == 'Examen de colocación';
  }

  String obtenerIdioma(Map<String, dynamic> pago) {
    final solicitud = obtenerSolicitud(pago);
    final idioma = obtenerRelacion(solicitud['idiomas']);

    return idioma['nombre']?.toString() ?? 'Idioma no disponible';
  }

  String obtenerNivel(Map<String, dynamic> pago) {
    final solicitud = obtenerSolicitud(pago);
    final nivel = obtenerRelacion(solicitud['nivel_solicitado']);

    return nivel['nombre']?.toString() ?? 'Sin nivel especificado';
  }

  int obtenerOrdenNivel(Map<String, dynamic> pago) {
    final solicitud = obtenerSolicitud(pago);
    final nivel = obtenerRelacion(solicitud['nivel_solicitado']);

    return (nivel['orden'] as num?)?.toInt() ?? 999;
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

  // Abrir el comprobante almacenado en Supabase Storage.
  Future<void> verComprobante(Map<String, dynamic> pago) async {
    try {
      final ruta = pago['comprobante_url']?.toString();

      if (ruta == null || ruta.isEmpty) {
        mostrarMensaje(
          'Este pago no tiene un comprobante registrado.',
          error: true,
        );
        return;
      }

      final url = await supabase.storage
          .from('comprobantes')
          .createSignedUrl(ruta, 600);

      final extension = ruta.split('.').last.toLowerCase();

      if (extension == 'jpg' ||
          extension == 'jpeg' ||
          extension == 'png') {
        if (!mounted) return;

        await showDialog(
          context: context,
          builder: (dialogContext) {
            return Dialog(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppBar(
                    title: const Text('Comprobante de pago'),
                    backgroundColor: azulPagosCoord,
                    foregroundColor: Colors.white,
                    automaticallyImplyLeading: false,
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          Navigator.pop(dialogContext);
                        },
                      ),
                    ],
                  ),
                  Flexible(
                    child: InteractiveViewer(
                      child: Image.network(
                        url,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return const Padding(
                            padding: EdgeInsets.all(25),
                            child: Text('No se pudo cargar la imagen.'),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      } else if (extension == 'pdf') {
        final uri = Uri.parse(url);

        final abierto = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );

        if (!abierto) {
          mostrarMensaje(
            'No se pudo abrir el comprobante PDF.',
            error: true,
          );
        }
      } else {
        mostrarMensaje(
          'El formato del comprobante no es compatible.',
          error: true,
        );
      }
    } catch (e) {
      mostrarMensaje(
        'No se pudo consultar el comprobante: $e',
        error: true,
      );
    }
  }

  // Confirmar un pago mediante la función SQL transaccional.
  Future<void> confirmarPago(Map<String, dynamic> pago) async {
    try {
      final pagoId = (pago['id'] as num).toInt();
      final tipoPago = pago['tipo_pago']?.toString();

      if (pago['estado'] != 'Pendiente de revisión') {
        mostrarMensaje(
          'Este pago ya fue revisado.',
          error: true,
        );
        return;
      }

      final esCurso = tipoPago == 'Curso';
      final esExamen = tipoPago == 'Examen de colocación';

      if (!esCurso && !esExamen) {
        mostrarMensaje(
          'El tipo de pago no es válido.',
          error: true,
        );
        return;
      }

      final confirmar = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text(
              'Confirmar pago',
              style: TextStyle(
                color: azulPagosCoord,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(
              esCurso
                  ? '¿Confirmas que el comprobante fue revisado '
                      'y que el pago del curso es correcto? '
                      'La inscripción pasará a estar activa.'
                  : '¿Confirmas que el comprobante fue revisado '
                      'y que el pago del examen es correcto?',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext, false);
                },
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  Navigator.pop(dialogContext, true);
                },
                child: const Text('Confirmar pago'),
              ),
            ],
          );
        },
      );

      if (confirmar != true) return;

      final usuario = supabase.auth.currentUser;

      if (usuario == null) {
        mostrarMensaje(
          'No se pudo identificar al coordinador.',
          error: true,
        );
        return;
      }

      await supabase.rpc(
        'confirmar_pago_celex',
        params: {
          'p_pago_id': pagoId,
        },
      );

      mostrarMensaje(
        esCurso
            ? 'Pago confirmado. La inscripción ahora está activa.'
            : 'Pago del examen de colocación confirmado.',
      );

      await actualizarPagos();
    } catch (e) {
      mostrarMensaje(
        'No se pudo completar la confirmación: $e',
        error: true,
      );
    }
  }

  // Rechazar un pago y registrar el motivo mediante la función SQL.
  Future<void> rechazarPago(Map<String, dynamic> pago) async {
    final motivoController = TextEditingController();

    try {
      final motivo = await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text(
              'Rechazar comprobante',
              style: TextStyle(
                color: azulPagosCoord,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Escribe el motivo por el que se rechaza '
                  'el comprobante. El estudiante deberá '
                  'corregirlo y enviarlo nuevamente.',
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: motivoController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Motivo del rechazo...',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                },
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  final texto = motivoController.text.trim();

                  if (texto.isEmpty) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Debes escribir el motivo del rechazo.',
                        ),
                      ),
                    );
                    return;
                  }

                  Navigator.pop(dialogContext, texto);
                },
                child: const Text('Rechazar pago'),
              ),
            ],
          );
        },
      );

      if (motivo == null) return;

      final pagoId = (pago['id'] as num).toInt();

      if (pago['estado'] != 'Pendiente de revisión') {
        mostrarMensaje(
          'Este pago ya fue revisado.',
          error: true,
        );
        return;
      }

      await supabase.rpc(
        'rechazar_pago_celex',
        params: {
          'p_pago_id': pagoId,
          'p_motivo': motivo,
        },
      );

      mostrarMensaje(
        'Comprobante rechazado. Se guardó el motivo.',
      );

      await actualizarPagos();
    } catch (e) {
      mostrarMensaje(
        'No se pudo rechazar el pago: $e',
        error: true,
      );
    } finally {
      motivoController.dispose();
    }
  }

  // Crear la tarjeta individual de cada pago.
  Widget construirPago(Map<String, dynamic> pago) {
    final estudiante = obtenerEstudiante(pago);

    final estado = pago['estado']?.toString() ?? 'Sin estado';
    final id = pago['id'];

    final nombre = estudiante['nombre_completo']?.toString() ??
        'Nombre no disponible';

    final correo = estudiante['correo']?.toString() ??
        'Correo no disponible';

    final pendiente = estado == 'Pendiente de revisión';

    return Card(
      color: Colors.white,
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'PAG-${id.toString().padLeft(4, '0')}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: azulPagosCoord,
                    fontSize: 15,
                  ),
                ),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: obtenerColorEstado(estado)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      nombreEstadoPago(estado),
                      style: TextStyle(
                        color: obtenerColorEstado(estado),
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const Divider(height: 22),

            const Text(
              'Estudiante',
              style: TextStyle(
                color: azulPagosCoord,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 5),
            Text(nombre),
            Text(
              correo,
              style: const TextStyle(color: Colors.black54),
            ),

            const SizedBox(height: 12),

            const Text(
              'Información del pago',
              style: TextStyle(
                color: azulPagosCoord,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 5),

            Text('Tipo de pago: ${pago['tipo_pago'] ?? 'No disponible'}'),
            Text(
              'Monto: ${formatearMonto(pago['monto'])}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'Fecha de envío: ${formatearFecha(pago['fecha_registro'])}',
            ),

            if (estado == 'Rechazado' &&
                pago['notas_coordinador'] != null &&
                pago['notas_coordinador'].toString().trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text(
                'Motivo del rechazo:',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(pago['notas_coordinador'].toString()),
            ],

            const SizedBox(height: 14),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => verComprobante(pago),
                icon: const Icon(Icons.visibility_outlined),
                label: const Text('Ver comprobante'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: azulPagosCoord,
                  side: const BorderSide(color: azulPagosCoord),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),

            if (pendiente) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => confirmarPago(pago),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Confirmar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => rechazarPago(pago),
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Rechazar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Apartado independiente para pagos de exámenes.
  Widget construirApartadoExamenes(
    List<Map<String, dynamic>> examenes, {
    required String titulo,
    required Color color,
  }) {
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: ExpansionTile(
        initiallyExpanded: false,
        leading: Icon(
          Icons.assignment_turned_in_outlined,
          color: color,
          size: 30,
        ),
        title: Text(
          titulo,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        subtitle: Text('${examenes.length} pagos'),
        childrenPadding: const EdgeInsets.all(12),
        children: examenes.map(construirPago).toList(),
      ),
    );
  }

  // Agrupar pagos de cursos por idioma y nivel.
  Widget construirApartadoCursos(
    List<Map<String, dynamic>> cursos, {
    required String titulo,
    required Color color,
  }) {
    final Map<String, List<Map<String, dynamic>>> porIdioma = {};

    for (final pago in cursos) {
      final idioma = obtenerIdioma(pago);
      porIdioma.putIfAbsent(idioma, () => []);
      porIdioma[idioma]!.add(pago);
    }

    final idiomasOrdenados = porIdioma.keys.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12, top: 5),
          child: Text(
            titulo,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),

        ...idiomasOrdenados.map((idioma) {
          final pagosIdioma = porIdioma[idioma]!;

          final Map<String, List<Map<String, dynamic>>> porNivel = {};

          for (final pago in pagosIdioma) {
            final nivel = obtenerNivel(pago);
            porNivel.putIfAbsent(nivel, () => []);
            porNivel[nivel]!.add(pago);
          }

          final nivelesOrdenados = porNivel.keys.toList();

          nivelesOrdenados.sort((a, b) {
            final ordenA = porNivel[a]!
                .map(obtenerOrdenNivel)
                .reduce((x, y) => x < y ? x : y);

            final ordenB = porNivel[b]!
                .map(obtenerOrdenNivel)
                .reduce((x, y) => x < y ? x : y);

            return ordenA.compareTo(ordenB);
          });

          return Card(
            color: Colors.white,
            margin: const EdgeInsets.only(bottom: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: ExpansionTile(
              initiallyExpanded: false,
              leading: Icon(
                Icons.language,
                color: color,
                size: 30,
              ),
              title: Text(
                idioma,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontSize: 15,
                ),
              ),
              subtitle: Text('${pagosIdioma.length} pagos'),
              childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              children: nivelesOrdenados.map((nivel) {
                final pagosNivel = porNivel[nivel]!;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: fondoPagosCoord,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ExpansionTile(
                    initiallyExpanded: false,
                    leading: Icon(
                      Icons.school_outlined,
                      color: color,
                    ),
                    title: Text(
                      nivel,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    subtitle: Text('${pagosNivel.length} pagos'),
                    childrenPadding: const EdgeInsets.all(10),
                    children: pagosNivel.map(construirPago).toList(),
                  ),
                );
              }).toList(),
            ),
          );
        }),
      ],
    );
  }

  // Selector del periodo.
  Widget construirSelectorPeriodo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Periodo académico',
            style: TextStyle(
              color: azulPagosCoord,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            initialValue: periodoSeleccionado,
            isExpanded: true,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
            hint: const Text('Selecciona un periodo'),
            items: periodos.map((periodo) {
              final id = int.parse(periodo['id'].toString());

              return DropdownMenuItem<int>(
                value: id,
                child: Text(
                  periodo['nombre']?.toString() ?? 'Periodo $id',
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: cambiarPeriodo,
          ),
          const SizedBox(height: 6),
          Text(
            'Mostrando pagos de: ${obtenerNombrePeriodo()}',
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // Resumen con los tres estados.
  Widget construirResumen(
    List<Map<String, dynamic>> pagos,
  ) {
    final pendientes = pagos
        .where((p) => p['estado'] == 'Pendiente de revisión')
        .length;

    final confirmados = pagos
        .where((p) => p['estado'] == 'Confirmado')
        .length;

    final rechazados = pagos
        .where((p) => p['estado'] == 'Rechazado')
        .length;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Text(
            'Estado de los pagos',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: azulPagosCoord,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _crearResumen(
                'Por revisar',
                pendientes,
                Colors.orange,
              ),
              _crearResumen(
                'Confirmados',
                confirmados,
                Colors.green,
              ),
              _crearResumen(
                'Rechazados',
                rechazados,
                Colors.red,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Indicador individual del resumen.
  Widget _crearResumen(
    String titulo,
    int cantidad,
    Color color,
  ) {
    return Column(
      children: [
        Text(
          cantidad.toString(),
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          titulo,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.black54,
          ),
        ),
      ],
    );
  }

  // Sección de pagos por estado.
  Widget construirSeccionEstado({
    required String titulo,
    required List<Map<String, dynamic>> pagos,
    required Color color,
    required IconData icono,
  }) {
    final examenes = pagos.where(esPagoExamen).toList();
    final cursos = pagos.where((p) => !esPagoExamen(p)).toList();

    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: ExpansionTile(
        initiallyExpanded: false,
        leading: Icon(icono, color: color, size: 28),
        title: Text(
          titulo,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        subtitle: Text('${pagos.length} pagos'),
        childrenPadding: const EdgeInsets.all(12),
        children: [
          if (pagos.isEmpty)
            const Padding(
              padding: EdgeInsets.all(15),
              child: Text(
                'No hay pagos en este apartado.',
                style: TextStyle(color: Colors.black54),
              ),
            ),
          if (examenes.isNotEmpty)
            construirApartadoExamenes(
              examenes,
              titulo: 'Exámenes de colocación',
              color: color,
            ),
          if (cursos.isNotEmpty)
            construirApartadoCursos(
              cursos,
              titulo: 'Pagos de cursos',
              color: color,
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: fondoPagosCoord,
      appBar: AppBar(
        title: const Text('Pagos y comprobantes'),
        backgroundColor: azulPagosCoord,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: actualizarPagos,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar pagos',
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: futurosPagos,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: azulPagosCoord,
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 45,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No se pudieron cargar los pagos.',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 15),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          futurosPagos = cargarDatosIniciales();
                        });
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            );
          }

          final listaPagos = snapshot.data ?? [];

          // Separar los pagos según su estado.
          final pendientes = listaPagos
              .where((p) => p['estado'] == 'Pendiente de revisión')
              .toList();

          final confirmados = listaPagos
              .where((p) => p['estado'] == 'Confirmado')
              .toList();

          final rechazados = listaPagos
              .where((p) => p['estado'] == 'Rechazado')
              .toList();

          final examenesPendientes =
              pendientes.where(esPagoExamen).toList();

          final cursosPendientes =
              pendientes.where((p) => !esPagoExamen(p)).toList();

          return RefreshIndicator(
            color: azulPagosCoord,
            onRefresh: actualizarPagos,
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                construirSelectorPeriodo(),

                const SizedBox(height: 18),

                const Text(
                  'Resumen de pagos',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: azulPagosCoord,
                  ),
                ),

                const SizedBox(height: 12),

                construirResumen(listaPagos),

                const SizedBox(height: 22),

                // Solo los pagos que necesitan revisión aparecen aquí.
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Pagos pendientes de confirmar',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: azulPagosCoord,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.13),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${pendientes.length}',
                        style: const TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                if (pendientes.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Column(
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 48,
                          color: Colors.green,
                        ),
                        SizedBox(height: 10),
                        Text(
                          'No hay pagos pendientes de revisión.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.black54,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),

                if (examenesPendientes.isNotEmpty)
                  construirApartadoExamenes(
                    examenesPendientes,
                    titulo: 'Exámenes por revisar',
                    color: Colors.orange,
                  ),

                if (cursosPendientes.isNotEmpty)
                  construirApartadoCursos(
                    cursosPendientes,
                    titulo: 'Cursos por revisar',
                    color: azulPagosCoord,
                  ),

                const SizedBox(height: 18),

                const Text(
                  'Historial de pagos revisados',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: azulPagosCoord,
                  ),
                ),

                const SizedBox(height: 12),

                // Los confirmados y rechazados quedan separados abajo.
                construirSeccionEstado(
                  titulo: 'Pagos confirmados',
                  pagos: confirmados,
                  color: Colors.green,
                  icono: Icons.check_circle_outline,
                ),

                construirSeccionEstado(
                  titulo: 'Pagos rechazados',
                  pagos: rechazados,
                  color: Colors.red,
                  icono: Icons.cancel_outlined,
                ),

                if (listaPagos.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      'No hay pagos registrados en este periodo.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black54),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
