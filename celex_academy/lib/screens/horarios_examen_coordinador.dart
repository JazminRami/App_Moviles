
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const Color azulHorarios = Color(0xFF023C87);
const Color fondoHorarios = Color(0xFFEAF1FB);

class HorariosExamenCoordinador extends StatefulWidget {
  final int periodoId;
  final String nombrePeriodo;
  final DateTime? fechaExamen;

  const HorariosExamenCoordinador({
    super.key,
    required this.periodoId,
    required this.nombrePeriodo,
    required this.fechaExamen,
  });

  @override
  State<HorariosExamenCoordinador> createState() =>
      _HorariosExamenCoordinadorState();
}

class _HorariosExamenCoordinadorState
    extends State<HorariosExamenCoordinador> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> horarios = [];

  bool cargando = true;
  bool guardando = false;

  @override
  void initState() {
    super.initState();
    cargarHorarios();
  }

  // Consulta los horarios del periodo y cuenta sus alumnos asignados.
  Future<void> cargarHorarios() async {
    try {
      final respuesta = await supabase
          .from('horarios_examen_colocacion')
          .select(
            'id, periodo_id, hora_inicio, hora_fin, cupo_maximo, activo',
          )
          .eq('periodo_id', widget.periodoId)
          .order('hora_inicio');

      final lista = List<Map<String, dynamic>>.from(respuesta);

      for (final horario in lista) {
        final asignaciones = await supabase
            .from('solicitudes')
            .select('id')
            .eq('horario_examen_id', horario['id']);

        horario['alumnos_asignados'] = asignaciones.length;
      }

      if (!mounted) return;

      setState(() {
        horarios = lista;
        cargando = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        cargando = false;
      });

      mostrarMensaje('Error al cargar los horarios: $error');
    }
  }

  // Formulario para crear o editar un horario.
  Future<void> mostrarFormularioHorario({
    Map<String, dynamic>? horario,
  }) async {
    final esEdicion = horario != null;

    TimeOfDay? horaInicio = esEdicion
        ? _convertirHora(horario['hora_inicio'])
        : null;

    TimeOfDay? horaFin = esEdicion
        ? _convertirHora(horario['hora_fin'])
        : null;

    final cupoController = TextEditingController(
      text: esEdicion
          ? horario['cupo_maximo']?.toString() ?? ''
          : '20',
    );

    final formKey = GlobalKey<FormState>();

    try {
      final datos = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (contextDialogo) {
          return StatefulBuilder(
            builder: (contextDialogo, actualizarDialogo) {
              return AlertDialog(
                title: Text(
                  esEdicion ? 'Editar horario' : 'Nuevo horario',
                ),
                content: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _selectorHora(
                          context: contextDialogo,
                          titulo: 'Hora de inicio',
                          hora: horaInicio,
                          alSeleccionar: (hora) {
                            actualizarDialogo(() {
                              horaInicio = hora;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        _selectorHora(
                          context: contextDialogo,
                          titulo: 'Hora de fin',
                          hora: horaFin,
                          alSeleccionar: (hora) {
                            actualizarDialogo(() {
                              horaFin = hora;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: cupoController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Cupo máximo de alumnos',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.people_outline),
                          ),
                          validator: (valor) {
                            final cupo = int.tryParse(valor ?? '');

                            if (cupo == null || cupo <= 0) {
                              return 'Escribe un cupo mayor que cero.';
                            }

                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'El horario se registrará para la fecha de examen '
                          'configurada en el periodo.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(contextDialogo),
                    child: const Text('Cancelar'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      if (!formKey.currentState!.validate()) return;

                      if (horaInicio == null || horaFin == null) {
                        mostrarMensaje(
                          'Selecciona la hora de inicio y de fin.',
                        );
                        return;
                      }

                      final minutosInicio =
                          horaInicio!.hour * 60 + horaInicio!.minute;

                      final minutosFin =
                          horaFin!.hour * 60 + horaFin!.minute;

                      if (minutosFin <= minutosInicio) {
                        mostrarMensaje(
                          'La hora de fin debe ser posterior a la de inicio.',
                        );
                        return;
                      }

                      Navigator.pop(contextDialogo, {
                        'hora_inicio': _horaParaBaseDatos(horaInicio!),
                        'hora_fin': _horaParaBaseDatos(horaFin!),
                        'cupo_maximo': int.parse(cupoController.text),
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: azulHorarios,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(esEdicion ? 'Guardar cambios' : 'Crear horario'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (datos == null) return;

      if (esEdicion) {
        await editarHorario(
          horario: horario,
          datos: datos,
        );
      } else {
        await crearHorario(datos);
      }
    } finally {
      cupoController.dispose();
    }
  }

  // Selector visual de hora.
  Widget _selectorHora({
    required BuildContext context,
    required String titulo,
    required TimeOfDay? hora,
    required ValueChanged<TimeOfDay> alSeleccionar,
  }) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () async {
          final seleccion = await showTimePicker(
            context: context,
            initialTime: hora ?? const TimeOfDay(hour: 9, minute: 0),
          );

          if (seleccion != null) {
            alSeleccionar(seleccion);
          }
        },
        icon: const Icon(Icons.access_time),
        label: Text(
          '$titulo: ${hora == null ? 'Seleccionar' : hora.format(context)}',
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: azulHorarios,
          padding: const EdgeInsets.all(14),
        ),
      ),
    );
  }

  // Registra un horario nuevo en Supabase.
  Future<void> crearHorario(Map<String, dynamic> datos) async {
    if (guardando) return;

    setState(() {
      guardando = true;
    });

    try {
      // Evita registrar horarios que se traslapen.
      final traslapes = horarios.where((existente) {
        if (existente['activo'] != true) return false;

        final inicioExistente =
            _minutosDesdeHora(existente['hora_inicio']);

        final finExistente =
            _minutosDesdeHora(existente['hora_fin']);

        final inicioNuevo =
            _minutosDesdeHora(datos['hora_inicio']);

        final finNuevo =
            _minutosDesdeHora(datos['hora_fin']);

        return inicioNuevo < finExistente &&
            finNuevo > inicioExistente;
      }).toList();

      if (traslapes.isNotEmpty) {
        mostrarMensaje(
          'El horario se traslapa con otro horario activo.',
        );
        return;
      }

      await supabase.from('horarios_examen_colocacion').insert({
        'periodo_id': widget.periodoId,
        'hora_inicio': datos['hora_inicio'],
        'hora_fin': datos['hora_fin'],
        'cupo_maximo': datos['cupo_maximo'],
        'activo': true,
      });

      if (!mounted) return;

      mostrarMensaje('Horario creado correctamente.');
      await cargarHorarios();
    } catch (error) {
      if (!mounted) return;
      mostrarMensaje('No se pudo crear el horario: $error');
    } finally {
      if (mounted) {
        setState(() {
          guardando = false;
        });
      }
    }
  }

  // Modifica un horario existente.
  Future<void> editarHorario({
    required Map<String, dynamic> horario,
    required Map<String, dynamic> datos,
  }) async {
    if (guardando) return;

    final asignados =
        int.tryParse(horario['alumnos_asignados'].toString()) ?? 0;

    final nuevoCupo = datos['cupo_maximo'] as int;

    if (nuevoCupo < asignados) {
      mostrarMensaje(
        'El cupo no puede ser menor a los $asignados alumnos asignados.',
      );
      return;
    }

    final traslapes = horarios.where((existente) {
      if (existente['id'] == horario['id'] ||
          existente['activo'] != true) {
        return false;
      }

      final inicioExistente =
          _minutosDesdeHora(existente['hora_inicio']);

      final finExistente =
          _minutosDesdeHora(existente['hora_fin']);

      final inicioNuevo =
          _minutosDesdeHora(datos['hora_inicio']);

      final finNuevo =
          _minutosDesdeHora(datos['hora_fin']);

      return inicioNuevo < finExistente &&
          finNuevo > inicioExistente;
    }).toList();

    if (traslapes.isNotEmpty) {
      mostrarMensaje(
        'El horario se traslapa con otro horario activo.',
      );
      return;
    }

    setState(() {
      guardando = true;
    });

    try {
      await supabase
          .from('horarios_examen_colocacion')
          .update({
            'hora_inicio': datos['hora_inicio'],
            'hora_fin': datos['hora_fin'],
            'cupo_maximo': nuevoCupo,
          })
          .eq('id', horario['id']);

      if (!mounted) return;

      mostrarMensaje('Horario actualizado correctamente.');
      await cargarHorarios();
    } catch (error) {
      if (!mounted) return;
      mostrarMensaje('No se pudo actualizar el horario: $error');
    } finally {
      if (mounted) {
        setState(() {
          guardando = false;
        });
      }
    }
  }

  // Activa o desactiva un horario.
  Future<void> cambiarEstadoHorario(
    Map<String, dynamic> horario,
  ) async {
    final estaActivo = horario['activo'] == true;

    final asignados =
        int.tryParse(horario['alumnos_asignados'].toString()) ?? 0;

    if (estaActivo && asignados > 0) {
      mostrarMensaje(
        'No puedes desactivar este horario porque tiene '
        '$asignados alumnos asignados.',
      );
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (contextDialogo) {
        return AlertDialog(
          title: Text(
            estaActivo ? 'Desactivar horario' : 'Activar horario',
          ),
          content: Text(
            estaActivo
                ? '¿Deseas desactivar este horario? '
                    'Ya no estará disponible para nuevas asignaciones.'
                : '¿Deseas volver a activar este horario?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(contextDialogo, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(contextDialogo, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: azulHorarios,
                foregroundColor: Colors.white,
              ),
              child: const Text('Confirmar'),
            ),
          ],
        );
      },
    );

    if (confirmar != true || !mounted) return;

    setState(() {
      guardando = true;
    });

    try {
      await supabase
          .from('horarios_examen_colocacion')
          .update({'activo': !estaActivo})
          .eq('id', horario['id']);

      if (!mounted) return;

      mostrarMensaje(
        estaActivo ? 'Horario desactivado.' : 'Horario activado.',
      );

      await cargarHorarios();
    } catch (error) {
      if (!mounted) return;
      mostrarMensaje('No se pudo cambiar el estado: $error');
    } finally {
      if (mounted) {
        setState(() {
          guardando = false;
        });
      }
    }
  }

  TimeOfDay _convertirHora(dynamic valor) {
    final partes = valor.toString().split(':');

    return TimeOfDay(
      hour: int.parse(partes[0]),
      minute: int.parse(partes[1]),
    );
  }

  String _horaParaBaseDatos(TimeOfDay hora) {
    return '${hora.hour.toString().padLeft(2, '0')}:'
        '${hora.minute.toString().padLeft(2, '0')}:00';
  }

  int _minutosDesdeHora(dynamic valor) {
    final hora = _convertirHora(valor);
    return hora.hour * 60 + hora.minute;
  }

  String _formatearHora(dynamic valor) {
    return _convertirHora(valor).format(context);
  }

  String _formatearFecha(DateTime fecha) {
    return '${fecha.day.toString().padLeft(2, '0')}/'
        '${fecha.month.toString().padLeft(2, '0')}/'
        '${fecha.year}';
  }

  void mostrarMensaje(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: fondoHorarios,
      appBar: AppBar(
        title: const Text('Horarios de exámenes'),
        backgroundColor: azulHorarios,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: guardando ? null : () => mostrarFormularioHorario(),
        backgroundColor: azulHorarios,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo horario'),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.nombrePeriodo,
                  style: const TextStyle(
                    color: azulHorarios,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_month,
                      size: 18,
                      color: Colors.black54,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.fechaExamen == null
                          ? 'Fecha del examen sin configurar'
                          : 'Fecha del examen: '
                              '${_formatearFecha(widget.fechaExamen!)}',
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: cargando
                ? const Center(child: CircularProgressIndicator())
                : horarios.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(25),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 60,
                                color: azulHorarios.withValues(alpha: 0.6),
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                'Todavía no hay horarios registrados.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Presiona "Nuevo horario" para agregar '
                                'el primer bloque de examen.',
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: cargarHorarios,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                          itemCount: horarios.length,
                          itemBuilder: (context, indice) {
                            final horario = horarios[indice];

                            final activo = horario['activo'] == true;
                            final asignados =
                                horario['alumnos_asignados'] as int;

                            final cupo =
                                int.tryParse(
                                  horario['cupo_maximo'].toString(),
                                ) ??
                                0;

                            return Card(
                              color: Colors.white,
                              elevation: 2,
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.access_time,
                                          color: azulHorarios,
                                          size: 22,
                                        ),
                                        const SizedBox(width: 9),
                                        Expanded(
                                          child: Text(
                                            '${_formatearHora(horario['hora_inicio'])}'
                                            ' - '
                                            '${_formatearHora(horario['hora_fin'])}',
                                            style: const TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.bold,
                                              color: azulHorarios,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: 'Editar horario',
                                          onPressed: guardando
                                              ? null
                                              : () => mostrarFormularioHorario(
                                                  horario: horario,
                                                ),
                                          icon: const Icon(
                                            Icons.edit_outlined,
                                            color: azulHorarios,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.people_outline,
                                          size: 18,
                                          color: Colors.black54,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Alumnos asignados: $asignados de $cupo',
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: LinearProgressIndicator(
                                        value: cupo <= 0
                                            ? 0
                                            : (asignados / cupo).clamp(0.0, 1.0),
                                        minHeight: 8,
                                        backgroundColor: fondoHorarios,
                                        color: asignados >= cupo
                                            ? Colors.red
                                            : Colors.green,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: activo
                                                ? Colors.green.withValues(
                                                    alpha: 0.12,
                                                  )
                                                : Colors.grey.withValues(
                                                    alpha: 0.15,
                                                  ),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            activo ? 'Activo' : 'Inactivo',
                                            style: TextStyle(
                                              color: activo
                                                  ? Colors.green.shade800
                                                  : Colors.grey.shade700,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const Spacer(),
                                        TextButton.icon(
                                          onPressed: guardando
                                              ? null
                                              : () => cambiarEstadoHorario(
                                                  horario,
                                                ),
                                          icon: Icon(
                                            activo
                                                ? Icons.toggle_off
                                                : Icons.toggle_on,
                                          ),
                                          label: Text(
                                            activo ? 'Desactivar' : 'Activar',
                                          ),
                                          style: TextButton.styleFrom(
                                            foregroundColor: azulHorarios,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
