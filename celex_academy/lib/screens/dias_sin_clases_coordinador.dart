
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DiasSinClasesCoordinador extends StatefulWidget {
  final int periodoId;
  final String nombrePeriodo;
  final DateTime fechaInicio;

  const DiasSinClasesCoordinador({
    super.key,
    required this.periodoId,
    required this.nombrePeriodo,
    required this.fechaInicio,
  });

  @override
  State<DiasSinClasesCoordinador> createState() =>
      _DiasSinClasesCoordinadorState();
}

class _DiasSinClasesCoordinadorState
    extends State<DiasSinClasesCoordinador> {
  final SupabaseClient supabase = Supabase.instance.client;

  List<Map<String, dynamic>> diasRegistrados = [];

  bool cargando = true;
  bool guardando = false;

  final List<String> tipos = [
    'Festivo',
    'Puente',
    'Suspension institucional',
    'Otro',
  ];

  String tipoSeleccionado = 'Festivo';

  final TextEditingController motivoController = TextEditingController();

  DateTime? fechaSeleccionada;

  @override
  void initState() {
    super.initState();
    cargarDiasSinClases();
  }

  @override
  void dispose() {
    motivoController.dispose();
    super.dispose();
  }

  // Formato de fecha DD/MM/AAAA.
  String formatoFecha(DateTime fecha) {
    return '${fecha.day.toString().padLeft(2, '0')}/'
        '${fecha.month.toString().padLeft(2, '0')}/'
        '${fecha.year}';
  }

  // Convierte una fecha a YYYY-MM-DD para Supabase.
  String fechaParaBaseDatos(DateTime fecha) {
    return '${fecha.year}-'
        '${fecha.month.toString().padLeft(2, '0')}-'
        '${fecha.day.toString().padLeft(2, '0')}';
  }

  // Consulta los días registrados para este periodo.
  Future<void> cargarDiasSinClases() async {
    try {
      final respuesta = await supabase
          .from('dias_sin_clases')
          .select()
          .eq('periodo_id', widget.periodoId)
          .order('fecha');

      if (!mounted) return;

      setState(() {
        diasRegistrados = List<Map<String, dynamic>>.from(respuesta);
        cargando = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        cargando = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar los días: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Calcula el primer lunes de un mes.
  DateTime primerLunes(int anio, int mes) {
    DateTime fecha = DateTime(anio, mes, 1);

    while (fecha.weekday != DateTime.monday) {
      fecha = fecha.add(const Duration(days: 1));
    }

    return fecha;
  }

  // Calcula el tercer lunes de un mes.
  DateTime tercerLunes(int anio, int mes) {
    return primerLunes(anio, mes).add(const Duration(days: 14));
  }

  // Genera fechas festivas habituales para sugerir a coordinación.
  // No se registran automáticamente.
  List<Map<String, dynamic>> obtenerFechasSugeridas() {
    final List<Map<String, dynamic>> sugerencias = [];

    final DateTime inicio = widget.fechaInicio;
    final DateTime limite = inicio.add(const Duration(days: 120));

    void agregar(
      DateTime fecha,
      String motivo,
      String tipo,
    ) {
      if (!fecha.isBefore(inicio) && !fecha.isAfter(limite)) {
        sugerencias.add({
          'fecha': fecha,
          'motivo': motivo,
          'tipo': tipo,
        });
      }
    }

    for (int anio = inicio.year; anio <= limite.year; anio++) {
      // Días de descanso oficiales.
      agregar(DateTime(anio, 1, 1), 'Año Nuevo', 'Festivo');

      agregar(
        primerLunes(anio, 2),
        'Día de la Constitución',
        'Festivo',
      );

      agregar(
        tercerLunes(anio, 3),
        'Natalicio de Benito Juárez',
        'Festivo',
      );

      agregar(
        DateTime(anio, 5, 1),
        'Día del Trabajo',
        'Festivo',
      );

      agregar(
        DateTime(anio, 9, 16),
        'Día de la Independencia de México',
        'Festivo',
      );

      agregar(
        tercerLunes(anio, 11),
        'Día de la Revolución Mexicana',
        'Festivo',
      );

      agregar(
        DateTime(anio, 12, 25),
        'Navidad',
        'Festivo',
      );

      // Fechas que conviene revisar en el calendario del IPN.
      agregar(
        DateTime(anio, 5, 5),
        'Conmemoración de la Batalla de Puebla (revisar calendario IPN)',
        'Suspension institucional',
      );

      agregar(
        DateTime(anio, 5, 15),
        'Día de la Maestra y el Maestro (revisar calendario IPN)',
        'Suspension institucional',
      );
    }

    sugerencias.sort(
      (a, b) => (a['fecha'] as DateTime)
          .compareTo(b['fecha'] as DateTime),
    );

    return sugerencias;
  }

  // Abre el formulario para registrar una suspensión.
  Future<void> mostrarFormulario({
    DateTime? fechaInicial,
    String? motivoInicial,
    String? tipoInicial,
  }) async {
    fechaSeleccionada = fechaInicial;
    motivoController.text = motivoInicial ?? '';
    tipoSeleccionado = tipoInicial ?? 'Festivo';

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (contextDialogo, actualizarDialogo) {
            return AlertDialog(
              title: const Text('Registrar día sin clases'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Fecha de suspensión',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),

                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final DateTime? fecha = await showDatePicker(
                            context: contextDialogo,
                            initialDate: fechaSeleccionada ??
                                widget.fechaInicio,
                            firstDate: widget.fechaInicio,
                            lastDate: widget.fechaInicio.add(
                              const Duration(days: 730),
                            ),
                            helpText: 'Selecciona el día sin clases',
                            cancelText: 'Cancelar',
                            confirmText: 'Aceptar',
                          );

                          if (fecha != null) {
                            actualizarDialogo(() {
                              fechaSeleccionada = fecha;
                            });
                          }
                        },
                        icon: const Icon(Icons.calendar_month),
                        label: Text(
                          fechaSeleccionada == null
                              ? 'Seleccionar fecha'
                              : formatoFecha(fechaSeleccionada!),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    const Text(
                      'Tipo de suspensión',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),

                    DropdownButtonFormField<String>(
                      initialValue: tipoSeleccionado,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      items: tipos.map((tipo) {
                        return DropdownMenuItem(
                          value: tipo,
                          child: Text(tipo),
                        );
                      }).toList(),
                      onChanged: (valor) {
                        if (valor != null) {
                          actualizarDialogo(() {
                            tipoSeleccionado = valor;
                          });
                        }
                      },
                    ),

                    const SizedBox(height: 16),

                    const Text(
                      'Motivo o descripción',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),

                    TextField(
                      controller: motivoController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText:
                            'Ej. Bloqueo en las instalaciones de ESCOM',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: guardando
                      ? null
                      : () async {
                          if (fechaSeleccionada == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Selecciona una fecha.'),
                              ),
                            );
                            return;
                          }

                          if (motivoController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Escribe el motivo.'),
                              ),
                            );
                            return;
                          }

                          Navigator.pop(dialogContext);

                          await registrarDiaSinClases();
                        },
                  child: const Text('Guardar y notificar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Guarda el día y ejecuta la función SQL que recalcula y notifica.
  Future<void> registrarDiaSinClases() async {
    if (fechaSeleccionada == null) return;

    setState(() {
      guardando = true;
    });

    try {
      final respuesta = await supabase.rpc(
        'registrar_dia_sin_clases',
        params: {
          'p_periodo_id': widget.periodoId,
          'p_fecha': fechaParaBaseDatos(fechaSeleccionada!),
          'p_motivo': motivoController.text.trim(),
          'p_tipo': tipoSeleccionado,
        },
      );

      if (!mounted) return;

      final resultado = Map<String, dynamic>.from(respuesta);

      final fechaFin = DateTime.parse(
        resultado['fecha_fin'].toString(),
      );

      final notificados =
          resultado['alumnos_notificados'] ?? 0;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Día registrado. Alumnos notificados: $notificados. '
            'Fin del periodo: ${formatoFecha(fechaFin)}.',
          ),
          duration: const Duration(seconds: 5),
        ),
      );

      await cargarDiasSinClases();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo registrar el día: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          guardando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sugerencias = obtenerFechasSugeridas();

    return Scaffold(
      backgroundColor: const Color(0xFFEAF1FB),
      appBar: AppBar(
        title: const Text('Días sin clases'),
        backgroundColor: const Color(0xFF023C87),
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: guardando ? null : () => mostrarFormulario(),
        backgroundColor: const Color(0xFF023C87),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Registrar suspensión'),
      ),
      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: cargarDiasSinClases,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Periodo seleccionado',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            widget.nombrePeriodo,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF023C87),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Inicio de clases: '
                            '${formatoFecha(widget.fechaInicio)}',
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    'Días registrados',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  if (diasRegistrados.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(18),
                        child: Text(
                          'Todavía no hay días sin clases registrados '
                          'para este periodo.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  else
                    ...diasRegistrados.map((dia) {
                      final fecha = DateTime.parse(
                        dia['fecha'].toString(),
                      );

                      return Card(
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFEAF1FB),
                            child: Icon(
                              Icons.event_busy,
                              color: Color(0xFF023C87),
                            ),
                          ),
                          title: Text(
                            formatoFecha(fecha),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            '${dia['motivo']}\nTipo: ${dia['tipo']}',
                          ),
                          isThreeLine: true,
                        ),
                      );
                    }),

                  const SizedBox(height: 24),

                  const Text(
                    'Fechas festivas sugeridas',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),

                  const Text(
                    'Son fechas de referencia. Revisa el calendario '
                    'oficial del IPN y selecciona únicamente las que '
                    'realmente impliquen suspensión en ESCOM.',
                    style: TextStyle(color: Colors.black54),
                  ),

                  const SizedBox(height: 10),

                  if (sugerencias.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'No hay fechas sugeridas dentro del periodo '
                          'y los siguientes cuatro meses.',
                        ),
                      ),
                    )
                  else
                    ...sugerencias.map((sugerencia) {
                      final fecha =
                          sugerencia['fecha'] as DateTime;

                      final yaRegistrada = diasRegistrados.any(
                        (dia) =>
                            dia['fecha'].toString() ==
                            fechaParaBaseDatos(fecha),
                      );

                      return Card(
                        child: ListTile(
                          leading: const Icon(
                            Icons.event,
                            color: Color(0xFF023C87),
                          ),
                          title: Text(
                            sugerencia['motivo'].toString(),
                          ),
                          subtitle: Text(
                            formatoFecha(fecha),
                          ),
                          trailing: yaRegistrada
                              ? const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                )
                              : IconButton(
                                  tooltip: 'Registrar esta fecha',
                                  icon: const Icon(
                                    Icons.add_circle_outline,
                                    color: Color(0xFF023C87),
                                  ),
                                  onPressed: guardando
                                      ? null
                                      : () {
                                          mostrarFormulario(
                                            fechaInicial: fecha,
                                            motivoInicial:
                                                sugerencia['motivo']
                                                    .toString(),
                                            tipoInicial:
                                                sugerencia['tipo']
                                                    .toString(),
                                          );
                                        },
                                ),
                        ),
                      );
                    }),

                  const SizedBox(height: 90),
                ],
              ),
            ),
    );
  }
}
