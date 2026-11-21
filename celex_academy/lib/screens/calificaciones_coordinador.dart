
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Colores institucionales.
const Color azulCalificaciones = Color(0xFF023C87);
const Color fondoCalificaciones = Color(0xFFEAF1FB);

class CalificacionesCoordinador extends StatefulWidget {
  const CalificacionesCoordinador({super.key});

  @override
  State<CalificacionesCoordinador> createState() =>
      _CalificacionesCoordinadorState();
}

class _CalificacionesCoordinadorState
    extends State<CalificacionesCoordinador> {
  final supabase = Supabase.instance.client;

  bool cargando = true;
  bool guardando = false;

  // Periodos académicos.
  List<Map<String, dynamic>> periodos = [];
  int? periodoId;

  // Alumnos inscritos en el periodo.
  List<Map<String, dynamic>> alumnos = [];

  // Controladores de calificaciones.
  final Map<int, TextEditingController> controladores = {};

  // Historial académico por inscripción.
  final Map<int, Map<String, dynamic>> historial = {};

  @override
  void initState() {
    super.initState();
    cargarPeriodos();
  }

  @override
  void dispose() {
    for (final controlador in controladores.values) {
      controlador.dispose();
    }
    super.dispose();
  }

  // Convierte un identificador a entero.
  int convertirId(dynamic valor) {
    return int.parse(valor.toString());
  }

  // Comprueba si una inscripción ya tiene calificación registrada.
  bool tieneCalificacion(int idInscripcion) {
    final registro = historial[idInscripcion];

    return registro != null &&
        registro['estado'] == 'Finalizado' &&
        registro['calificacion_final'] != null;
  }

  // Libera los controladores anteriores al cambiar de periodo.
  void limpiarControladores() {
    for (final controlador in controladores.values) {
      controlador.dispose();
    }

    controladores.clear();
  }

  // Ordena primero los alumnos pendientes y después los calificados.
  void ordenarAlumnos() {
    alumnos.sort((a, b) {
      final idA = convertirId(a['inscripcion_id']);
      final idB = convertirId(b['inscripcion_id']);

      final calificadoA = tieneCalificacion(idA);
      final calificadoB = tieneCalificacion(idB);

      if (calificadoA != calificadoB) {
        return calificadoA ? 1 : -1;
      }

      final idiomaA = a['idioma']['nombre'].toString();
      final idiomaB = b['idioma']['nombre'].toString();

      final comparacionIdioma = idiomaA.compareTo(idiomaB);

      if (comparacionIdioma != 0) {
        return comparacionIdioma;
      }

      final nivelA = a['nivel']['nombre'].toString();
      final nivelB = b['nivel']['nombre'].toString();

      final comparacionNivel = nivelA.compareTo(nivelB);

      if (comparacionNivel != 0) {
        return comparacionNivel;
      }

      return a['estudiante']['nombre_completo']
          .toString()
          .compareTo(
            b['estudiante']['nombre_completo'].toString(),
          );
    });
  }

  // Consulta los periodos y selecciona el actual.
  Future<void> cargarPeriodos() async {
    try {
      final respuesta = await supabase
          .from('periodos')
          .select('id, nombre, fecha_inicio, estado')
          .order('fecha_inicio', ascending: false);

      final lista = List<Map<String, dynamic>>.from(respuesta);

      const estadosActivos = [
        'Inscripciones',
        'Colocacion',
        'Distribucion',
        'Pagos',
        'En curso',
      ];

      final periodoActual = lista.firstWhere(
        (periodo) => estadosActivos.contains(periodo['estado']),
        orElse: () => lista.isNotEmpty
            ? lista.first
            : <String, dynamic>{},
      );

      if (!mounted) return;

      setState(() {
        periodos = lista;
        periodoId = periodoActual.isEmpty
            ? null
            : convertirId(periodoActual['id']);
      });

      await consultarAlumnos();
    } catch (error) {
      if (!mounted) return;

      setState(() {
        cargando = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al consultar los periodos: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Cambia el periodo seleccionado.
  Future<void> cambiarPeriodo(int? nuevoPeriodoId) async {
    if (nuevoPeriodoId == null || nuevoPeriodoId == periodoId) {
      return;
    }

    setState(() {
      periodoId = nuevoPeriodoId;
    });

    await consultarAlumnos();
  }

  // Selector del periodo académico.
  Widget construirSelectorPeriodo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(15, 15, 15, 12),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Periodo académico',
            style: TextStyle(
              color: azulCalificaciones,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 7),
          DropdownButtonFormField<int>(
            key: ValueKey(periodoId),
            initialValue: periodoId,
            isExpanded: true,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              isDense: true,
              prefixIcon: const Icon(
                Icons.calendar_month_outlined,
                color: azulCalificaciones,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFFD2E0F5),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFFD2E0F5),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: azulCalificaciones,
                  width: 1.5,
                ),
              ),
            ),
            hint: const Text('Selecciona un periodo'),
            items: periodos.map((periodo) {
              return DropdownMenuItem<int>(
                value: convertirId(periodo['id']),
                child: Text(
                  periodo['nombre']?.toString() ?? 'Periodo',
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: cargando || guardando
                ? null
                : cambiarPeriodo,
          ),
          if (periodos.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'No hay periodos registrados.',
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Consulta alumnos, grupos, niveles, idiomas e historiales.
  Future<void> consultarAlumnos() async {
    if (mounted) {
      setState(() {
        cargando = true;
      });
    }

    limpiarControladores();

    try {
      if (periodoId == null) {
        if (!mounted) return;

        setState(() {
          alumnos = [];
          historial.clear();
          cargando = false;
        });

        return;
      }

      // Consultamos las inscripciones activas.
      final respuestaInscripciones = await supabase
          .from('inscripciones')
          .select('id, estudiante_id, grupo_id, estado')
          .eq('estado', 'Activa');

      final inscripciones =
          List<Map<String, dynamic>>.from(
        respuestaInscripciones,
      );

      if (inscripciones.isEmpty) {
        if (!mounted) return;

        setState(() {
          alumnos = [];
          historial.clear();
          cargando = false;
        });

        return;
      }

      // Identificadores de los grupos.
      final idsGrupos = inscripciones
          .map((i) => convertirId(i['grupo_id']))
          .toSet()
          .toList();

      // Grupos del periodo seleccionado.
      final respuestaGrupos = await supabase
          .from('grupos')
          .select(
            'id, nombre, codigo_grupo, nivel_id, periodo_id, '
            'fecha_inicio, fecha_fin, profesor_id',
          )
          .inFilter('id', idsGrupos)
          .eq('periodo_id', periodoId!);

      final Map<int, Map<String, dynamic>> mapaGrupos = {};

      for (final grupo in respuestaGrupos) {
        final dato = Map<String, dynamic>.from(grupo);
        mapaGrupos[convertirId(dato['id'])] = dato;
      }

      // Inscripciones que pertenecen al periodo.
      final inscripcionesPeriodo = inscripciones.where(
        (inscripcion) {
          final idGrupo = convertirId(inscripcion['grupo_id']);
          return mapaGrupos.containsKey(idGrupo);
        },
      ).toList();

      if (inscripcionesPeriodo.isEmpty) {
        if (!mounted) return;

        setState(() {
          alumnos = [];
          historial.clear();
          cargando = false;
        });

        return;
      }

      final idsEstudiantes = inscripcionesPeriodo
          .map((i) => i['estudiante_id'].toString())
          .toSet()
          .toList();

      final idsInscripciones = inscripcionesPeriodo
          .map((i) => convertirId(i['id']))
          .toList();

      // Niveles de los grupos.
      final idsNiveles = mapaGrupos.values
          .map((g) => convertirId(g['nivel_id']))
          .toSet()
          .toList();

      final respuestaNiveles = await supabase
          .from('niveles')
          .select('id, nombre, idioma_id, orden')
          .inFilter('id', idsNiveles);

      final Map<int, Map<String, dynamic>> mapaNiveles = {};

      for (final nivel in respuestaNiveles) {
        final dato = Map<String, dynamic>.from(nivel);
        mapaNiveles[convertirId(dato['id'])] = dato;
      }

      // Idiomas correspondientes a los niveles.
      final idsIdiomas = mapaNiveles.values
          .map((n) => convertirId(n['idioma_id']))
          .toSet()
          .toList();

      final respuestaIdiomas = await supabase
          .from('idiomas')
          .select('id, nombre')
          .inFilter('id', idsIdiomas);

      final Map<int, Map<String, dynamic>> mapaIdiomas = {};

      for (final idioma in respuestaIdiomas) {
        final dato = Map<String, dynamic>.from(idioma);
        mapaIdiomas[convertirId(dato['id'])] = dato;
      }

      // Datos personales de los estudiantes.
      final respuestaEstudiantes = await supabase
          .from('perfiles_estudiantes')
          .select('id, nombre_completo, correo')
          .inFilter('id', idsEstudiantes);

      final Map<String, Map<String, dynamic>> mapaEstudiantes = {};

      for (final estudiante in respuestaEstudiantes) {
        final dato = Map<String, dynamic>.from(estudiante);
        mapaEstudiantes[dato['id'].toString()] = dato;
      }

      // Historiales académicos existentes.
      final respuestaHistorial = await supabase
          .from('historial_academico')
          .select(
            'id, inscripcion_id, calificacion_final, estado',
          )
          .inFilter('inscripcion_id', idsInscripciones);

      final Map<int, Map<String, dynamic>> mapaHistorial = {};

      for (final registro in respuestaHistorial) {
        final dato = Map<String, dynamic>.from(registro);

        if (dato['inscripcion_id'] != null) {
          mapaHistorial[
            convertirId(dato['inscripcion_id'])
          ] = dato;
        }
      }

      // Relacionamos los datos de cada inscripción.
      final List<Map<String, dynamic>> resultado = [];

      for (final inscripcion in inscripcionesPeriodo) {
        final idGrupo = convertirId(inscripcion['grupo_id']);
        final idInscripcion = convertirId(inscripcion['id']);
        final idEstudiante = inscripcion['estudiante_id'].toString();

        final grupo = mapaGrupos[idGrupo];

        if (grupo == null) continue;

        final nivel = mapaNiveles[
          convertirId(grupo['nivel_id'])
        ];

        if (nivel == null) continue;

        final idioma = mapaIdiomas[
          convertirId(nivel['idioma_id'])
        ];

        if (idioma == null) continue;

        final estudiante = mapaEstudiantes[idEstudiante];

        if (estudiante == null) continue;

        final registro = mapaHistorial[idInscripcion];

        // Si ya tiene calificación, la colocamos en su campo.
        final calificacion = registro?['calificacion_final'];

        controladores[idInscripcion] = TextEditingController(
          text: calificacion == null
              ? ''
              : double.parse(
                  calificacion.toString(),
                ).toStringAsFixed(1),
        );

        resultado.add({
          'inscripcion_id': idInscripcion,
          'estudiante_id': idEstudiante,
          'grupo_id': idGrupo,
          'grupo': grupo,
          'nivel': nivel,
          'idioma': idioma,
          'estudiante': estudiante,
        });
      }

      if (!mounted) return;

      setState(() {
        alumnos = resultado;

        historial
          ..clear()
          ..addAll(mapaHistorial);

        ordenarAlumnos();
        cargando = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        cargando = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al consultar alumnos: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Obtiene y valida la calificación escrita.
  double? validarCalificacion(
    int idInscripcion, {
    bool mostrarError = true,
  }) {
    final texto = controladores[idInscripcion]
            ?.text
            .trim()
            .replaceAll(',', '.') ??
        '';

    final formatoValido = RegExp(
      r'^\d{1,2}(\.\d)?$',
    ).hasMatch(texto);

    if (!formatoValido) {
      if (mostrarError) {
        mostrarMensaje(
          'Ingresa una calificación válida con máximo un decimal.',
          Colors.orange,
        );
      }

      return null;
    }

    final calificacion = double.tryParse(texto);

    if (calificacion == null ||
        calificacion < 0 ||
        calificacion > 10) {
      if (mostrarError) {
        mostrarMensaje(
          'La calificación debe estar entre 0.0 y 10.0.',
          Colors.orange,
        );
      }

      return null;
    }

    return double.parse(calificacion.toStringAsFixed(1));
  }

  // Prepara los datos para guardar el historial.
  Map<String, dynamic> prepararDatos(
    Map<String, dynamic> alumno,
    double calificacion,
  ) {
    final grupo = alumno['grupo'];
    final nivel = alumno['nivel'];

    final Map<String, dynamic> datos = {
      'estudiante_id': alumno['estudiante_id'],
      'idioma_id': convertirId(alumno['idioma']['id']),
      'nivel_id': convertirId(nivel['id']),
      'calificacion_final': calificacion,
      'estado': 'Finalizado',
      'inscripcion_id': alumno['inscripcion_id'],
      'grupo_id': alumno['grupo_id'],
    };

    if (grupo['fecha_inicio'] != null) {
      datos['fecha_inicio'] = grupo['fecha_inicio'];
    }

    if (grupo['fecha_fin'] != null) {
      datos['fecha_fin'] = grupo['fecha_fin'];
    }

    if (grupo['profesor_id'] != null) {
      datos['profesor_id'] = grupo['profesor_id'];
    }

    return datos;
  }

  // Guarda la calificación de un solo estudiante.
  Future<void> guardarCalificacion(
    Map<String, dynamic> alumno,
  ) async {
    if (guardando) return;

    final idInscripcion = convertirId(
      alumno['inscripcion_id'],
    );

    final calificacion = validarCalificacion(idInscripcion);

    if (calificacion == null) return;

    setState(() {
      guardando = true;
    });

    try {
      final datos = prepararDatos(alumno, calificacion);

      await supabase
          .from('historial_academico')
          .upsert(
            datos,
            onConflict: 'inscripcion_id',
          );

      if (!mounted) return;

      // Actualizamos la pantalla sin volver a consultar la base.
      setState(() {
        historial[idInscripcion] = {
          'calificacion_final': calificacion,
          'estado': 'Finalizado',
        };

        ordenarAlumnos();
      });

      mostrarMensaje(
        'Calificación guardada correctamente.',
        Colors.green,
      );
    } catch (error) {
      if (!mounted) return;

      mostrarMensaje(
        'Error al guardar la calificación: $error',
        Colors.red,
      );
    } finally {
      if (mounted) {
        setState(() {
          guardando = false;
        });
      }
    }
  }

  // Guarda en una sola operación todas las calificaciones pendientes
  // que tengan un valor escrito.
  Future<void> guardarPendientes() async {
    if (guardando) return;

    final List<Map<String, dynamic>> datosParaGuardar = [];
    final Map<int, double> calificacionesGuardadas = {};

    for (final alumno in alumnos) {
      final idInscripcion = convertirId(
        alumno['inscripcion_id'],
      );

      // No incluimos alumnos que ya tienen calificación.
      if (tieneCalificacion(idInscripcion)) continue;

      // Si el campo está vacío, lo dejamos pendiente.
      final texto = controladores[idInscripcion]?.text.trim() ?? '';

      if (texto.isEmpty) continue;

      final calificacion = validarCalificacion(
        idInscripcion,
        mostrarError: false,
      );

      if (calificacion == null) {
        mostrarMensaje(
          'Revisa la calificación de '
          '${alumno['estudiante']['nombre_completo']}.',
          Colors.orange,
        );
        return;
      }

      datosParaGuardar.add(
        prepararDatos(alumno, calificacion),
      );

      calificacionesGuardadas[idInscripcion] = calificacion;
    }

    if (datosParaGuardar.isEmpty) {
      mostrarMensaje(
        'Escribe al menos una calificación pendiente.',
        Colors.orange,
      );
      return;
    }

    setState(() {
      guardando = true;
    });

    try {
      // Una sola operación para guardar todos los alumnos.
      await supabase
          .from('historial_academico')
          .upsert(
            datosParaGuardar,
            onConflict: 'inscripcion_id',
          );

      if (!mounted) return;

      // Actualizamos los alumnos localmente.
      setState(() {
        for (final entrada in calificacionesGuardadas.entries) {
          historial[entrada.key] = {
            'calificacion_final': entrada.value,
            'estado': 'Finalizado',
          };
        }

        ordenarAlumnos();
      });

      mostrarMensaje(
        '${datosParaGuardar.length} calificación(es) guardada(s).',
        Colors.green,
      );
    } catch (error) {
      if (!mounted) return;

      mostrarMensaje(
        'Error al guardar las calificaciones: $error',
        Colors.red,
      );
    } finally {
      if (mounted) {
        setState(() {
          guardando = false;
        });
      }
    }
  }

  // Muestra mensajes al coordinador.
  void mostrarMensaje(String mensaje, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: color,
      ),
    );
  }

  // Cuenta las calificaciones pendientes que ya tienen un valor escrito.
  int contarPendientesCapturados() {
    int cantidad = 0;

    for (final alumno in alumnos) {
      final id = convertirId(alumno['inscripcion_id']);

      if (tieneCalificacion(id)) continue;

      final texto = controladores[id]?.text.trim() ?? '';

      if (texto.isNotEmpty) {
        cantidad++;
      }
    }

    return cantidad;
  }

  // Organiza los alumnos por idioma.
  Map<String, List<Map<String, dynamic>>> agruparPorIdioma() {
    final Map<String, List<Map<String, dynamic>>> resultado = {};

    for (final alumno in alumnos) {
      final idioma = alumno['idioma']['nombre'].toString();

      resultado.putIfAbsent(idioma, () => []);
      resultado[idioma]!.add(alumno);
    }

    return resultado;
  }

  // Organiza los alumnos por nivel.
  Map<String, List<Map<String, dynamic>>> agruparPorNivel(
    List<Map<String, dynamic>> lista,
  ) {
    final Map<String, List<Map<String, dynamic>>> resultado = {};

    for (final alumno in lista) {
      final nivel = alumno['nivel']['nombre'].toString();

      resultado.putIfAbsent(nivel, () => []);
      resultado[nivel]!.add(alumno);
    }

    return resultado;
  }

  // Tarjeta de cada estudiante.
  Widget crearTarjetaAlumno(
    Map<String, dynamic> alumno,
  ) {
    final idInscripcion = convertirId(
      alumno['inscripcion_id'],
    );

    final controlador = controladores[idInscripcion]!;

    final registro = historial[idInscripcion];

    final finalizado = tieneCalificacion(idInscripcion);

    final nombre =
        alumno['estudiante']['nombre_completo']?.toString() ??
            'Estudiante';

    final correo =
        alumno['estudiante']['correo']?.toString() ?? '';

    final grupo = alumno['grupo'];

    final nombreGrupo =
        grupo['codigo_grupo']?.toString().isNotEmpty == true
            ? grupo['codigo_grupo'].toString()
            : grupo['nombre'].toString();

    return Card(
      color: Colors.white,
      elevation: 2,
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
              children: [
                CircleAvatar(
                  backgroundColor: finalizado
                      ? const Color(0xFFE3F5E8)
                      : fondoCalificaciones,
                  child: Icon(
                    finalizado
                        ? Icons.check
                        : Icons.person,
                    color: finalizado
                        ? Colors.green
                        : azulCalificaciones,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nombre,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: azulCalificaciones,
                        ),
                      ),
                      if (correo.isNotEmpty)
                        Text(
                          correo,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                    ],
                  ),
                ),
                if (finalizado)
                  const Text(
                    'Registrada',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  )
                else
                  const Text(
                    'Pendiente',
                    style: TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                const Icon(
                  Icons.groups_outlined,
                  size: 18,
                  color: azulCalificaciones,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'Grupo: $nombreGrupo',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: controlador,
                    enabled: !guardando,
                    keyboardType:
                        const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) {
                      setState(() {});
                    },
                    decoration: InputDecoration(
                      labelText: 'Calificación',
                      hintText: 'Ej. 8.5',
                      suffixText: '/ 10',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      filled: finalizado,
                      fillColor: finalizado
                          ? const Color(0xFFF3F7FC)
                          : Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: guardando
                      ? null
                      : () => guardarCalificacion(alumno),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: azulCalificaciones,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 15,
                    ),
                  ),
                  child: Text(
                    finalizado ? 'Actualizar' : 'Guardar',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 9),

            Row(
              children: [
                Icon(
                  finalizado
                      ? Icons.check_circle
                      : Icons.pending_outlined,
                  size: 17,
                  color: finalizado
                      ? Colors.green
                      : Colors.orange,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    finalizado
                        ? 'Calificación registrada: '
                            '${double.parse(registro!['calificacion_final'].toString()).toStringAsFixed(1)}'
                        : 'Calificación pendiente',
                    style: TextStyle(
                      fontSize: 12,
                      color: finalizado
                          ? Colors.green
                          : Colors.orange,
                      fontWeight: FontWeight.w600,
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

  // Resumen de alumnos pendientes y registrados.
  Widget construirResumen() {
    final registrados = alumnos
        .where(
          (alumno) => tieneCalificacion(
            convertirId(alumno['inscripcion_id']),
          ),
        )
        .length;

    final pendientes = alumnos.length - registrados;

    final capturados = contarPendientesCapturados();

    return Card(
      color: Colors.white,
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Avance de calificaciones',
                        style: TextStyle(
                          color: azulCalificaciones,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '$registrados registrados · $pendientes pendientes',
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: guardando || capturados == 0
                      ? null
                      : guardarPendientes,
                  icon: const Icon(Icons.save_outlined),
                  label: Text('Guardar ($capturados)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: azulCalificaciones,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
            if (guardando) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(
                color: azulCalificaciones,
                backgroundColor: fondoCalificaciones,
              ),
              const SizedBox(height: 5),
              const Text(
                'Guardando calificaciones...',
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 12,
                ),
              ),
            ] else if (capturados > 0) ...[
              const SizedBox(height: 7),
              Text(
                'Tienes $capturados calificación(es) lista(s) para guardar juntas.',
                style: const TextStyle(
                  color: azulCalificaciones,
                  fontSize: 12,
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
    final idiomasAgrupados = agruparPorIdioma();

    return Scaffold(
      backgroundColor: fondoCalificaciones,
      appBar: AppBar(
        title: const Text('Calificaciones'),
        backgroundColor: azulCalificaciones,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Actualizar calificaciones',
            icon: const Icon(Icons.refresh),
            onPressed: cargando || guardando
                ? null
                : consultarAlumnos,
          ),
        ],
      ),
      body: Column(
        children: [
          construirSelectorPeriodo(),
          Expanded(
            child: cargando
                ? const Center(
                    child: CircularProgressIndicator(
                      color: azulCalificaciones,
                    ),
                  )
                : periodoId == null
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(25),
                          child: Text(
                            'Selecciona un periodo académico para consultar las calificaciones.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      )
                    : alumnos.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(25),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.school_outlined,
                                    size: 65,
                                    color: Colors.black38,
                                  ),
                                  const SizedBox(height: 15),
                                  const Text(
                                    'No hay alumnos disponibles para calificar.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: azulCalificaciones,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Aquí aparecerán los alumnos con inscripción activa, organizados por idioma y nivel.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            color: azulCalificaciones,
                            onRefresh: consultarAlumnos,
                            child: ListView(
                              padding: const EdgeInsets.all(15),
                              children: [
                                const Text(
                                  'Registro de calificaciones',
                                  style: TextStyle(
                                    fontSize: 21,
                                    fontWeight: FontWeight.bold,
                                    color: azulCalificaciones,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Captura las calificaciones y guárdalas individualmente o todas juntas.',
                                  style: TextStyle(
                                    color: Colors.black54,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 15),

                                construirResumen(),

                                // Alumnos agrupados por idioma.
                                ...idiomasAgrupados.entries.map(
                                  (entradaIdioma) {
                                    final nivelesAgrupados =
                                        agruparPorNivel(
                                      entradaIdioma.value,
                                    );

                                    return Card(
                                      color: Colors.white,
                                      margin: const EdgeInsets.only(
                                        bottom: 13,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(13),
                                      ),
                                      child: ExpansionTile(
                                        leading: const Icon(
                                          Icons.language,
                                          color: azulCalificaciones,
                                        ),
                                        title: Text(
                                          entradaIdioma.key,
                                          style: const TextStyle(
                                            color: azulCalificaciones,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        subtitle: Text(
                                          '${entradaIdioma.value.length} alumnos',
                                        ),
                                        children: [
                                          ...nivelesAgrupados.entries.map(
                                            (entradaNivel) {
                                              final registrados =
                                                  entradaNivel.value
                                                      .where(
                                                (alumno) =>
                                                    tieneCalificacion(
                                                  convertirId(
                                                    alumno['inscripcion_id'],
                                                  ),
                                                ),
                                              ).length;

                                              final pendientes =
                                                  entradaNivel.value.length -
                                                      registrados;

                                              return Padding(
                                                padding:
                                                    const EdgeInsets.only(
                                                  left: 10,
                                                  right: 10,
                                                  bottom: 8,
                                                ),
                                                child: Card(
                                                  color:
                                                      fondoCalificaciones,
                                                  elevation: 0,
                                                  child: ExpansionTile(
                                                    leading: const Icon(
                                                      Icons.menu_book_outlined,
                                                      color:
                                                          azulCalificaciones,
                                                    ),
                                                    title: Text(
                                                      entradaNivel.key,
                                                      style:
                                                          const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color:
                                                            azulCalificaciones,
                                                      ),
                                                    ),
                                                    subtitle: Text(
                                                      '$pendientes pendientes · $registrados registrados',
                                                    ),
                                                    children: [
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .all(10),
                                                        child: Column(
                                                          children:
                                                              entradaNivel
                                                                  .value
                                                                  .map(
                                                            crearTarjetaAlumno,
                                                          ).toList(),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}
