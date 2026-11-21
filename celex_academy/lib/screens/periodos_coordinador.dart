import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'dias_sin_clases_coordinador.dart';
import 'horarios_examen_coordinador.dart';

// Colores de CELEX Academy.
const Color azulPeriodos = Color(0xFF023C87);
const Color fondoPeriodos = Color(0xFFEAF1FB);

class PeriodosCoordinador extends StatefulWidget {
  const PeriodosCoordinador({super.key});

  @override
  State<PeriodosCoordinador> createState() => _PeriodosCoordinadorState();
}

class _PeriodosCoordinadorState extends State<PeriodosCoordinador> {
  final SupabaseClient supabase = Supabase.instance.client;

  List<Map<String, dynamic>> periodos = [];
  bool cargando = true;
  bool guardando = false;

  @override
  void initState() {
    super.initState();
    cargarPeriodos();
  }

  // Convierte de forma segura los identificadores que llegan de Supabase.
  int? _convertirId(dynamic valor) {
    if (valor == null) return null;
    if (valor is int) return valor;
    return int.tryParse(valor.toString());
  }

  // Convierte de forma segura las fechas que llegan de Supabase.
  DateTime? _convertirFecha(dynamic valor) {
    if (valor == null) return null;
    if (valor is DateTime) {
      return DateTime(valor.year, valor.month, valor.day);
    }
    final fecha = DateTime.tryParse(valor.toString());
    if (fecha == null) return null;
    return DateTime(fecha.year, fecha.month, fecha.day);
  }

  // Evita que showDatePicker reciba una fecha fuera de sus límites.
  DateTime _fechaInicialValida(DateTime? fecha) {
    final minimo = DateTime(2025);
    final maximo = DateTime(2040, 12, 31);
    final candidata = fecha ?? DateTime.now();
    if (candidata.isBefore(minimo)) return minimo;
    if (candidata.isAfter(maximo)) return maximo;
    return candidata;
  }

  Future<void> cargarPeriodos() async {
    try {
      final respuesta = await supabase
          .from('periodos')
          .select(
            'id, nombre, fecha_inicio, fecha_fin, '
            'fecha_examen_colocacion, fecha_limite_pago_examen, '
            'fecha_limite_pago, fecha_publicacion_grupos, '
            'estado, fecha_registro',
          )
          .order('fecha_registro', ascending: false);

      if (!mounted) return;
      setState(() {
        periodos = List<Map<String, dynamic>>.from(respuesta);
        cargando = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => cargando = false);
      mostrarMensaje('Error al cargar los periodos: $error');
    }
  }

  Future<void> administrarDiasSinClases(
    Map<String, dynamic> periodo,
  ) async {
    final fechaInicio = _convertirFecha(periodo['fecha_inicio']);
    final periodoId = _convertirId(periodo['id']);

    if (fechaInicio == null || periodoId == null) {
      mostrarMensaje('El periodo no tiene una fecha de inicio o ID válido.');
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DiasSinClasesCoordinador(
          periodoId: periodoId,
          nombrePeriodo: periodo['nombre']?.toString() ?? 'Periodo',
          fechaInicio: fechaInicio,
        ),
      ),
    );

    if (mounted) await cargarPeriodos();
  }

  Future<void> administrarHorariosExamen(
    Map<String, dynamic> periodo,
  ) async {
    final fechaExamen = _convertirFecha(periodo['fecha_examen_colocacion']);
    final periodoId = _convertirId(periodo['id']);

    if (fechaExamen == null || periodoId == null) {
      mostrarMensaje('Configura la fecha del examen y verifica el ID del periodo.');
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HorariosExamenCoordinador(
          periodoId: periodoId,
          nombrePeriodo: periodo['nombre']?.toString() ?? 'Periodo',
          fechaExamen: fechaExamen,
        ),
      ),
    );

    if (mounted) await cargarPeriodos();
  }

  // El coordinador abre las inscripciones; las demás etapas se controlan en Supabase.
  Future<void> abrirInscripciones(Map<String, dynamic> periodo) async {
    if (guardando) return;

    final periodoId = _convertirId(periodo['id']);
    if (periodoId == null) {
      mostrarMensaje('No se pudo identificar el periodo seleccionado.');
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Abrir inscripciones'),
        content: Text(
          '¿Deseas abrir las inscripciones del periodo '
          '"${periodo['nombre'] ?? 'Sin nombre'}"?\n\n'
          'Después de esta acción, las siguientes etapas se actualizarán '
          'automáticamente según las fechas y los procesos correspondientes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: azulPeriodos,
              foregroundColor: Colors.white,
            ),
            child: const Text('Abrir inscripciones'),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;
    setState(() => guardando = true);

    try {
      await supabase.rpc(
        'abrir_inscripciones_periodo',
        params: {'p_periodo_id': periodoId},
      );

      if (!mounted) return;
      mostrarMensaje('Las inscripciones se abrieron correctamente.');
      await cargarPeriodos();
    } catch (error) {
      if (mounted) mostrarMensaje('No se pudieron abrir las inscripciones: $error');
    } finally {
      if (mounted) setState(() => guardando = false);
    }
  }

  Future<void> mostrarFormularioNuevoPeriodo() async {
    if (guardando) return;

    final nombreController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    DateTime? fechaExamen;

    try {
      final datos = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, actualizarDialogo) => AlertDialog(
            title: const Text('Nuevo periodo'),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nombreController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Nombre del periodo',
                        hintText: 'Ej. Enero - Marzo 2027',
                        border: OutlineInputBorder(),
                      ),
                      validator: (valor) => valor == null || valor.trim().isEmpty
                          ? 'Escribe el nombre del periodo.'
                          : null,
                    ),
                    const SizedBox(height: 18),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final seleccion = await showDatePicker(
                          context: dialogContext,
                          initialDate: _fechaInicialValida(fechaExamen),
                          firstDate: DateTime(2025),
                          lastDate: DateTime(2040, 12, 31),
                        );
                        if (seleccion != null && dialogContext.mounted) {
                          actualizarDialogo(() => fechaExamen = seleccion);
                        }
                      },
                      icon: const Icon(Icons.calendar_month),
                      label: Text(
                        fechaExamen == null
                            ? 'Seleccionar sábado del examen'
                            : 'Examen: ${formatearFecha(fechaExamen!)}',
                      ),
                    ),
                    if (fechaExamen == null)
                      const Padding(
                        padding: EdgeInsets.only(top: 5),
                        child: Text(
                          'Selecciona el sábado del examen de colocación.',
                          style: TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: fondoPeriodos,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        '¿Cómo funciona el inicio del periodo?\n\n'
                        'El periodo comienza con el sábado del examen de colocación. '
                        'Las clases regulares comienzan el sábado siguiente.\n\n'
                        'La aplicación propone automáticamente el inicio de clases '
                        'una semana después del examen.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (!(formKey.currentState?.validate() ?? false)) return;
                  if (fechaExamen == null) {
                    actualizarDialogo(() {});
                    return;
                  }
                  if (fechaExamen!.weekday != DateTime.saturday) {
                    mostrarMensaje('El examen de colocación debe ser en sábado.');
                    return;
                  }
                  Navigator.pop(dialogContext, {
                    'nombre': nombreController.text.trim(),
                    'fecha_examen': fechaExamen,
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: azulPeriodos,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Crear periodo'),
              ),
            ],
          ),
        ),
      );

      if (datos != null && mounted) {
        final nombre = datos['nombre'];
        final examen = datos['fecha_examen'];
        if (nombre is String && examen is DateTime) {
          await crearPeriodo(nombre: nombre, fechaExamen: examen);
        } else {
          mostrarMensaje('Los datos del nuevo periodo no son válidos.');
        }
      }
    } catch (error) {
      if (mounted) mostrarMensaje('No se pudo abrir el formulario: $error');
    } finally {
      nombreController.dispose();
    }
  }

  Future<void> crearPeriodo({
    required String nombre,
    required DateTime fechaExamen,
  }) async {
    if (guardando) return;
    setState(() => guardando = true);

    try {
      final fechaInicio = fechaExamen.add(const Duration(days: 7));
      await supabase.from('periodos').insert({
        'nombre': nombre,
        'fecha_inicio': fechaParaBaseDatos(fechaInicio),
        'estado': 'Planeacion',
      });

      if (!mounted) return;
      mostrarMensaje(
        'Periodo creado. El inicio de clases será ${formatearFecha(fechaInicio)}. '
        'Ahora configura el calendario completo.',
      );
      await cargarPeriodos();
    } catch (error) {
      if (mounted) mostrarMensaje('No se pudo crear el periodo: $error');
    } finally {
      if (mounted) setState(() => guardando = false);
    }
  }

  Future<void> configurarCalendario(Map<String, dynamic> periodo) async {
    final id = _convertirId(periodo['id']);
    if (id == null) {
      mostrarMensaje('No se pudo identificar el periodo seleccionado.');
      return;
    }

    DateTime fechaInicio = _convertirFecha(periodo['fecha_inicio']) ??
        DateTime.now().add(const Duration(days: 7));
    DateTime? fechaExamen = _convertirFecha(periodo['fecha_examen_colocacion']) ??
        fechaInicio.subtract(const Duration(days: 7));
    DateTime? fechaLimitePagoExamen =
        _convertirFecha(periodo['fecha_limite_pago_examen']) ??
            fechaExamen.subtract(const Duration(days: 1));
    DateTime? fechaPublicacion =
        _convertirFecha(periodo['fecha_publicacion_grupos']) ??
            fechaInicio.subtract(const Duration(days: 2));
    DateTime? fechaLimitePago =
        _convertirFecha(periodo['fecha_limite_pago']) ??
            fechaInicio.subtract(const Duration(days: 1));
    DateTime? fechaFin = _convertirFecha(periodo['fecha_fin']) ??
        fechaInicio.add(const Duration(days: 49));

    final datos = await showDialog<Map<String, DateTime>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, actualizarDialogo) => AlertDialog(
          title: Text('Calendario: ${periodo['nombre'] ?? 'Periodo'}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Configura las fechas del periodo. El orden de los pagos y '
                  'las actividades se respeta automáticamente.',
                ),
                const SizedBox(height: 18),
                _botonFecha(
                  context: dialogContext,
                  titulo: 'Fecha límite de pago del examen',
                  fecha: fechaLimitePagoExamen,
                  alSeleccionar: (fecha) => actualizarDialogo(
                    () => fechaLimitePagoExamen = fecha,
                  ),
                ),
                const SizedBox(height: 12),
                _botonFecha(
                  context: dialogContext,
                  titulo: 'Sábado del examen de colocación',
                  fecha: fechaExamen,
                  alSeleccionar: (fecha) => actualizarDialogo(
                    () => fechaExamen = fecha,
                  ),
                ),
                const SizedBox(height: 12),
                _botonFecha(
                  context: dialogContext,
                  titulo: 'Publicación de grupos',
                  fecha: fechaPublicacion,
                  alSeleccionar: (fecha) => actualizarDialogo(
                    () => fechaPublicacion = fecha,
                  ),
                ),
                const SizedBox(height: 12),
                _botonFecha(
                  context: dialogContext,
                  titulo: 'Fecha límite de pago del curso',
                  fecha: fechaLimitePago,
                  alSeleccionar: (fecha) => actualizarDialogo(
                    () => fechaLimitePago = fecha,
                  ),
                ),
                const SizedBox(height: 12),
                _botonFecha(
                  context: dialogContext,
                  titulo: 'Inicio de clases regulares',
                  fecha: fechaInicio,
                  alSeleccionar: (fecha) => actualizarDialogo(() {
                    fechaInicio = fecha;
                    fechaPublicacion = fecha.subtract(const Duration(days: 2));
                    fechaLimitePago = fecha.subtract(const Duration(days: 1));
                    fechaFin = fecha.add(const Duration(days: 49));
                  }),
                ),
                const SizedBox(height: 8),
                const Text(
                  'El inicio se propone para el sábado siguiente al examen. '
                  'Si ocurre algún imprevisto, puedes cambiarlo aquí.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 16),
                _botonFecha(
                  context: dialogContext,
                  titulo: 'Finalización estimada del curso',
                  fecha: fechaFin,
                  alSeleccionar: (fecha) => actualizarDialogo(
                    () => fechaFin = fecha,
                  ),
                ),
                const SizedBox(height: 15),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: fondoPeriodos,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'La fecha final considera ocho sábados de clases, contando el inicio.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                if (fechaLimitePagoExamen == null ||
                    fechaExamen == null ||
                    fechaPublicacion == null ||
                    fechaLimitePago == null ||
                    fechaFin == null) {
                  mostrarMensaje('Debes seleccionar todas las fechas.');
                  return;
                }
                if (fechaExamen!.weekday != DateTime.saturday) {
                  mostrarMensaje('El examen de colocación debe ser sábado.');
                  return;
                }
                if (fechaInicio.weekday != DateTime.saturday) {
                  mostrarMensaje('El inicio de clases debe ser sábado.');
                  return;
                }
                if (fechaFin!.weekday != DateTime.saturday ||
                    fechaFin!.isBefore(fechaInicio)) {
                  mostrarMensaje(
                    'La fecha final debe ser un sábado posterior al inicio.',
                  );
                  return;
                }
                if (!fechaLimitePagoExamen!.isBefore(fechaExamen!)) {
                  mostrarMensaje(
                    'El límite de pago del examen debe ser anterior al examen.',
                  );
                  return;
                }
                if (!fechaExamen!.isBefore(fechaPublicacion!)) {
                  mostrarMensaje(
                    'El examen debe ser anterior a la publicación de grupos.',
                  );
                  return;
                }
                if (!fechaPublicacion!.isBefore(fechaLimitePago!)) {
                  mostrarMensaje(
                    'Los grupos deben publicarse antes del límite de pago del curso.',
                  );
                  return;
                }
                if (!fechaLimitePago!.isBefore(fechaInicio)) {
                  mostrarMensaje(
                    'El límite de pago del curso debe ser anterior al inicio de clases.',
                  );
                  return;
                }
                Navigator.pop(dialogContext, {
                  'fecha_limite_pago_examen': fechaLimitePagoExamen!,
                  'fecha_examen_colocacion': fechaExamen!,
                  'fecha_publicacion_grupos': fechaPublicacion!,
                  'fecha_limite_pago': fechaLimitePago!,
                  'fecha_inicio': fechaInicio,
                  'fecha_fin': fechaFin!,
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: azulPeriodos,
                foregroundColor: Colors.white,
              ),
              child: const Text('Guardar calendario'),
            ),
          ],
        ),
      ),
    );

    if (datos == null || !mounted) return;
    await guardarCalendario(id, datos);
  }

  Widget _botonFecha({
    required BuildContext context,
    required String titulo,
    required DateTime? fecha,
    required ValueChanged<DateTime> alSeleccionar,
  }) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () async {
          final seleccion = await showDatePicker(
            context: context,
            initialDate: _fechaInicialValida(fecha),
            firstDate: DateTime(2025),
            lastDate: DateTime(2040, 12, 31),
          );
          if (seleccion != null && context.mounted) {
            alSeleccionar(seleccion);
          }
        },
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.all(13),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titulo,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                const Icon(Icons.calendar_month, size: 18, color: azulPeriodos),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    fecha == null ? 'Seleccionar fecha' : formatearFecha(fecha),
                    style: const TextStyle(
                      color: azulPeriodos,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> guardarCalendario(
    int periodoId,
    Map<String, DateTime> fechas,
  ) async {
    if (guardando) return;

    const camposObligatorios = [
      'fecha_limite_pago_examen',
      'fecha_examen_colocacion',
      'fecha_publicacion_grupos',
      'fecha_limite_pago',
      'fecha_inicio',
      'fecha_fin',
    ];
    for (final campo in camposObligatorios) {
      if (fechas[campo] == null) {
        mostrarMensaje('Falta una fecha del calendario: $campo.');
        return;
      }
    }

    setState(() => guardando = true);
    try {
      await supabase.from('periodos').update({
        'fecha_limite_pago_examen': fechaParaBaseDatos(fechas['fecha_limite_pago_examen']!),
        'fecha_examen_colocacion': fechaParaBaseDatos(fechas['fecha_examen_colocacion']!),
        'fecha_publicacion_grupos': fechaParaBaseDatos(fechas['fecha_publicacion_grupos']!),
        'fecha_limite_pago': fechaParaBaseDatos(fechas['fecha_limite_pago']!),
        'fecha_inicio': fechaParaBaseDatos(fechas['fecha_inicio']!),
        'fecha_fin': fechaParaBaseDatos(fechas['fecha_fin']!),
      }).eq('id', periodoId);

      if (!mounted) return;
      mostrarMensaje('Calendario guardado correctamente.');
      await cargarPeriodos();
    } catch (error) {
      if (mounted) mostrarMensaje('No se pudo guardar el calendario: $error');
    } finally {
      if (mounted) setState(() => guardando = false);
    }
  }

  String fechaParaBaseDatos(DateTime fecha) {
    return '${fecha.year}-'
        '${fecha.month.toString().padLeft(2, '0')}-'
        '${fecha.day.toString().padLeft(2, '0')}';
  }

  String formatearFecha(DateTime fecha) {
    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    return '$dia/$mes/${fecha.year}';
  }

  Color colorEstado(String estado) {
    switch (estado) {
      case 'Planeacion':
        return Colors.orange;
      case 'Inscripciones':
        return Colors.green;
      case 'Colocacion':
        return Colors.blue;
      case 'Distribucion':
        return Colors.deepPurple;
      case 'Pagos':
        return Colors.teal;
      case 'En curso':
        return Colors.indigo;
      case 'Finalizado':
        return Colors.grey;
      case 'Cancelado':
        return Colors.red;
      default:
        return Colors.black54;
    }
  }

  void mostrarMensaje(String mensaje) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(SnackBar(content: Text(mensaje)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: fondoPeriodos,
      appBar: AppBar(
        title: const Text('Administración de periodos'),
        backgroundColor: azulPeriodos,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: guardando ? null : mostrarFormularioNuevoPeriodo,
        backgroundColor: azulPeriodos,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo periodo'),
      ),
      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : periodos.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(25),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.calendar_month_outlined,
                          size: 65,
                          color: azulPeriodos.withValues(alpha:0.6),
                        ),
                        const SizedBox(height: 15),
                        const Text(
                          'Todavía no hay periodos registrados.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Presiona "Nuevo periodo" para comenzar.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: cargarPeriodos,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
                    itemCount: periodos.length,
                    itemBuilder: (context, indice) {
                      final periodo = periodos[indice];
                      final nombre = periodo['nombre']?.toString() ?? 'Sin nombre';
                      final estado = periodo['estado']?.toString() ?? 'Sin estado';
                      final fechaInicio = _convertirFecha(periodo['fecha_inicio']);
                      final fechaExamen = _convertirFecha(periodo['fecha_examen_colocacion']);
                      final fechaLimiteExamen = _convertirFecha(periodo['fecha_limite_pago_examen']);
                      final fechaPublicacion = _convertirFecha(periodo['fecha_publicacion_grupos']);
                      final fechaLimiteCurso = _convertirFecha(periodo['fecha_limite_pago']);
                      final fechaFin = _convertirFecha(periodo['fecha_fin']);

                      final calendarioCompleto = fechaExamen != null &&
                          fechaLimiteExamen != null &&
                          fechaPublicacion != null &&
                          fechaLimiteCurso != null &&
                          fechaFin != null &&
                          fechaInicio != null;

                      return Card(
                        color: Colors.white,
                        elevation: 1,
                        margin: const EdgeInsets.only(bottom: 7),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Theme(
                          data: Theme.of(context).copyWith(
                            dividerColor: Colors.transparent,
                          ),
                          child: ExpansionTile(
                            tilePadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 2),
                            childrenPadding: const EdgeInsets.fromLTRB(15, 0, 15, 15),
                            initiallyExpanded: false,
                            iconColor: azulPeriodos,
                            collapsedIconColor: azulPeriodos,
                            title: Text(
                              nombre,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: azulPeriodos,
                              ),
                            ),
                            children: [
                              const Divider(height: 1),
                              const SizedBox(height: 12),
                              _filaFecha(
                                icono: Icons.assignment_outlined,
                                texto: 'Límite de pago del examen',
                                fecha: fechaLimiteExamen,
                              ),
                              const SizedBox(height: 7),
                              _filaFecha(
                                icono: Icons.event,
                                texto: 'Examen de colocación',
                                fecha: fechaExamen,
                              ),
                              const SizedBox(height: 7),
                              _filaFecha(
                                icono: Icons.groups_outlined,
                                texto: 'Publicación de grupos',
                                fecha: fechaPublicacion,
                              ),
                              const SizedBox(height: 7),
                              _filaFecha(
                                icono: Icons.payments_outlined,
                                texto: 'Límite de pago del curso',
                                fecha: fechaLimiteCurso,
                              ),
                              const SizedBox(height: 7),
                              _filaFecha(
                                icono: Icons.calendar_today,
                                texto: 'Inicio de clases',
                                fecha: fechaInicio,
                              ),
                              const SizedBox(height: 7),
                              _filaFecha(
                                icono: Icons.event_available,
                                texto: 'Fin del periodo',
                                fecha: fechaFin,
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: colorEstado(estado).withValues(alpha:0.12),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      estado,
                                      style: TextStyle(
                                        color: colorEstado(estado),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  if (calendarioCompleto)
                                    const Text(
                                      'Calendario configurado',
                                      style: TextStyle(
                                        color: Colors.green,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  else
                                    const Text(
                                      'Falta configurar calendario',
                                      style: TextStyle(
                                        color: Colors.deepOrange,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: guardando ? null : () => configurarCalendario(periodo),
                                  icon: const Icon(Icons.edit_calendar),
                                  label: Text(calendarioCompleto ? 'Editar calendario' : 'Configurar calendario'),
                                  style: OutlinedButton.styleFrom(foregroundColor: azulPeriodos),
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: fechaInicio == null || guardando
                                      ? null
                                      : () => administrarDiasSinClases(periodo),
                                  icon: const Icon(Icons.event_busy),
                                  label: const Text('Días sin clases'),
                                  style: OutlinedButton.styleFrom(foregroundColor: azulPeriodos),
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: guardando ? null : () => administrarHorariosExamen(periodo),
                                  icon: const Icon(Icons.access_time),
                                  label: const Text('Horarios de exámenes'),
                                  style: OutlinedButton.styleFrom(foregroundColor: azulPeriodos),
                                ),
                              ),
                              if (estado == 'Planeacion') ...[
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: guardando || !calendarioCompleto
                                        ? null
                                        : () => abrirInscripciones(periodo),
                                    icon: const Icon(Icons.play_arrow),
                                    label: const Text('Abrir inscripciones'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: azulPeriodos,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 13),
                                    ),
                                  ),
                                ),
                                if (!calendarioCompleto)
                                  const Padding(
                                    padding: EdgeInsets.only(top: 6),
                                    child: Text(
                                      'Configura todas las fechas antes de abrir las inscripciones.',
                                      style: TextStyle(color: Colors.deepOrange, fontSize: 12),
                                    ),
                                  ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _filaFecha({
    required IconData icono,
    required String texto,
    required DateTime? fecha,
  }) {
    return Row(
      children: [
        Icon(icono, size: 17, color: Colors.black54),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '$texto: ${fecha == null ? 'Sin configurar' : formatearFecha(fecha)}',
          ),
        ),
      ],
    );
  }
}
