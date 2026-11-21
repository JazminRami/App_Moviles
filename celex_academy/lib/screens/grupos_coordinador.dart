import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GruposCoordinador extends StatefulWidget {
  const GruposCoordinador({super.key});

  @override
  State<GruposCoordinador> createState() => _GruposCoordinadorState();
}

class _GruposCoordinadorState extends State<GruposCoordinador> {
  final supabase = Supabase.instance.client;

  static const Color azul = Color(0xFF023C87);
  static const Color fondo = Color(0xFFEAF1FB);
  static const int minimoEstudiantes = 20;
  static const int maximoEstudiantes = 35;

  bool cargando = true;
  bool cargandoDemanda = false;

  List<Map<String, dynamic>> periodos = [];
  List<Map<String, dynamic>> demanda = [];
  List<Map<String, dynamic>> gruposCreados = [];
  int? periodoSeleccionadoId;

  @override
  void initState() {
    super.initState();
    cargarPeriodos();
  }

  // Carga los periodos y conserva sus fechas para asignarlas a los grupos.
  Future<void> cargarPeriodos() async {
    try {
      final respuesta = await supabase
          .from('periodos')
          .select('id, nombre, fecha_inicio, fecha_fin, estado')
          .order('fecha_inicio', ascending: false);

      if (!mounted) return;

      final periodosCargados = List<Map<String, dynamic>>.from(respuesta);

      // Se selecciona primero el periodo que está en una etapa activa.
      // Si no existe uno, se conserva el más reciente por fecha de inicio.
      const estadosActivos = [
        'Inscripciones',
        'Colocacion',
        'Distribucion',
        'Pagos',
        'En curso',
      ];

      Map<String, dynamic>? periodoActivo;
      for (final periodo in periodosCargados) {
        if (estadosActivos.contains(periodo['estado'])) {
          periodoActivo = periodo;
          break;
        }
      }

      final periodoInicial = periodoActivo ??
          (periodosCargados.isNotEmpty ? periodosCargados.first : null);

      setState(() {
        periodos = periodosCargados;
        periodoSeleccionadoId = periodoInicial == null
            ? null
            : (periodoInicial['id'] as num).toInt();
        cargando = false;
      });

      if (periodoSeleccionadoId != null) {
        await cargarDatos();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => cargando = false);
      mostrarMensaje('Error al cargar periodos: $e');
    }
  }

  Map<String, dynamic>? get periodoSeleccionado {
    for (final periodo in periodos) {
      if ((periodo['id'] as num).toInt() == periodoSeleccionadoId) {
        return periodo;
      }
    }
    return null;
  }

  Future<void> cargarDatos() async {
    await cargarDemanda();
    await cargarGruposCreados();
  }

  // La consulta ordena las solicitudes por fecha para asignar primero
  // a quienes realizaron su solicitud antes.
  Future<void> cargarDemanda() async {
    if (periodoSeleccionadoId == null) return;

    setState(() {
      cargandoDemanda = true;
      demanda = [];
    });

    try {
      final respuesta = await supabase
          .from('solicitudes')
          .select('''
            id, estudiante_id, tipo_tramite, estado, idioma_id,
            nivel_id, nivel_asignado_id, grupo_id, fecha_solicitud
          ''')
          .eq('periodo_id', periodoSeleccionadoId!)
          .order('fecha_solicitud', ascending: true);

      final solicitudes = List<Map<String, dynamic>>.from(respuesta);

      final solicitudesValidas = solicitudes.where((s) {
        final estado = (s['estado'] ?? '').toString().toLowerCase();
        return estado != 'cancelada' &&
            estado != 'cancelado' &&
            estado != 'rechazada' &&
            estado != 'rechazado' &&
            estado != 'finalizada' &&
            estado != 'finalizado' &&
            s['grupo_id'] == null;
      }).toList();

      if (solicitudesValidas.isEmpty) {
        if (!mounted) return;
        setState(() => cargandoDemanda = false);
        return;
      }

      final idsSolicitudes =
          solicitudesValidas.map((s) => (s['id'] as num).toInt()).toList();

      final respuestaPagos = await supabase
          .from('pagos')
          .select('solicitud_id')
          .eq('tipo_pago', 'Examen de colocación')
          .eq('estado', 'Confirmado')
          .inFilter('solicitud_id', idsSolicitudes);

      final solicitudesConExamenPagado =
          List<Map<String, dynamic>>.from(respuestaPagos)
              .map((p) => (p['solicitud_id'] as num).toInt())
              .toSet();

      final respuestaInscripciones =
          await supabase.from('inscripciones').select('solicitud_id');

      final solicitudesInscritas =
          List<Map<String, dynamic>>.from(respuestaInscripciones)
              .where((i) => i['solicitud_id'] != null)
              .map((i) => (i['solicitud_id'] as num).toInt())
              .toSet();

      final idsIdiomas = solicitudesValidas
          .map((s) => (s['idioma_id'] as num).toInt())
          .toSet()
          .toList();

      final idsNiveles = <int>{};
      for (final s in solicitudesValidas) {
        final esColocacion = s['tipo_tramite'] == 'Examen de colocación';
        final nivelId = esColocacion ? s['nivel_asignado_id'] : s['nivel_id'];
        if (nivelId != null) idsNiveles.add((nivelId as num).toInt());
      }

      final respuestaIdiomas = await supabase
          .from('idiomas')
          .select('id, nombre')
          .inFilter('id', idsIdiomas);

      final respuestaNiveles = await supabase
          .from('niveles')
          .select('id, nombre, idioma_id, orden')
          .inFilter('id', idsNiveles.toList());

      final idiomas = List<Map<String, dynamic>>.from(respuestaIdiomas);
      final niveles = List<Map<String, dynamic>>.from(respuestaNiveles);

      final mapaIdiomas = {
        for (final i in idiomas)
          (i['id'] as num).toInt(): i['nombre'].toString(),
      };
      final mapaNiveles = {
        for (final n in niveles) (n['id'] as num).toInt(): n,
      };

      final idsEstudiantes = solicitudesValidas
          .map((s) => s['estudiante_id'].toString())
          .toSet()
          .toList();

      final respuestaPerfiles = await supabase
          .from('perfiles_estudiantes')
          .select('id, nombre_completo, categoria')
          .inFilter('id', idsEstudiantes);

      final perfiles = List<Map<String, dynamic>>.from(respuestaPerfiles);
      final mapaPerfiles = {for (final p in perfiles) p['id'].toString(): p};

      final Map<String, Map<String, dynamic>> gruposDemanda = {};

      for (final s in solicitudesValidas) {
        final esColocacion = s['tipo_tramite'] == 'Examen de colocación';
        final solicitudId = (s['id'] as num).toInt();

        if (esColocacion &&
            !solicitudesConExamenPagado.contains(solicitudId)) {
          continue;
        }
        if (solicitudesInscritas.contains(solicitudId)) continue;

        final nivelValor = esColocacion
            ? s['nivel_asignado_id']
            : s['nivel_id'];
        if (nivelValor == null) continue;

        final nivelId = (nivelValor as num).toInt();
        final idiomaId = (s['idioma_id'] as num).toInt();
        final nivel = mapaNiveles[nivelId];
        final idiomaNombre = mapaIdiomas[idiomaId];

        if (nivel == null || idiomaNombre == null) continue;
        if ((nivel['idioma_id'] as num).toInt() != idiomaId) continue;

        final estudianteId = s['estudiante_id'].toString();
        final perfil = mapaPerfiles[estudianteId];
        if (perfil == null) continue;

        final clave = '${idiomaId}_$nivelId';
        gruposDemanda.putIfAbsent(clave, () => {
              'idioma_id': idiomaId,
              'idioma': idiomaNombre,
              'nivel_id': nivelId,
              'nivel': nivel['nombre'].toString(),
              'orden': nivel['orden'],
              'estudiantes': <Map<String, dynamic>>[],
              'estudiantes_ids': <String>{},
            });

        final ids = gruposDemanda[clave]!['estudiantes_ids'] as Set<String>;
        // Evita contar dos veces a la misma persona en el mismo idioma/nivel.
        if (!ids.add(estudianteId)) continue;

        (gruposDemanda[clave]!['estudiantes']
                as List<Map<String, dynamic>>)
            .add({
          'solicitud_id': solicitudId,
          'estudiante_id': estudianteId,
          'nombre': perfil['nombre_completo'].toString(),
          'categoria': perfil['categoria'].toString(),
          'tipo_tramite': s['tipo_tramite'].toString(),
          'fecha_solicitud': s['fecha_solicitud'],
        });
      }

      final resultado = gruposDemanda.values.map((g) {
        final estudiantes =
            g['estudiantes'] as List<Map<String, dynamic>>;
        return {
          'idioma_id': g['idioma_id'],
          'idioma': g['idioma'],
          'nivel_id': g['nivel_id'],
          'nivel': g['nivel'],
          'orden': g['orden'],
          'cantidad_curso': estudiantes
              .where((e) => e['tipo_tramite'] != 'Examen de colocación')
              .length,
          'cantidad_colocacion': estudiantes
              .where((e) => e['tipo_tramite'] == 'Examen de colocación')
              .length,
          'total': estudiantes.length,
          'estudiantes': estudiantes,
        };
      }).toList();

      resultado.sort((a, b) {
        final comparacion =
            a['idioma'].toString().compareTo(b['idioma'].toString());
        if (comparacion != 0) return comparacion;
        return (a['orden'] as num).compareTo(b['orden'] as num);
      });

      if (!mounted) return;
      setState(() {
        demanda = resultado;
        cargandoDemanda = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => cargandoDemanda = false);
      mostrarMensaje('Error al consultar demanda: $e');
    }
  }

  Future<void> cargarGruposCreados() async {
    if (periodoSeleccionadoId == null) return;

    try {
      final respuesta = await supabase
          .from('grupos')
          .select('''
            id, nombre, codigo_grupo, nivel_id, periodo_id, profesor_id,
            fecha_inicio, fecha_fin, horario, cupo_maximo, estado,
            modalidad, publicado, niveles(nombre, idioma_id, idiomas(nombre)),
            profesores(nombre_completo)
          ''')
          .eq('periodo_id', periodoSeleccionadoId!)
          .order('fecha_inicio');

      if (!mounted) return;
      setState(() {
        gruposCreados = List<Map<String, dynamic>>.from(respuesta);
      });
    } catch (e) {
      mostrarMensaje('Error al cargar grupos: $e');
    }
  }

  // Calcula cuántos grupos pueden formarse y cuántos estudiantes se asignan.
  // Si quedan menos de 20 para un segundo grupo, esos estudiantes esperan.
  Map<String, int> calcularDistribucion(int total) {
    if (total < minimoEstudiantes) {
      return {'grupos': 0, 'asignados': 0, 'espera': total};
    }

    int cantidadGrupos = (total / maximoEstudiantes).ceil();

    if (total ~/ cantidadGrupos < minimoEstudiantes) {
      cantidadGrupos = 1;
    }

    final asignados = cantidadGrupos == 1
        ? (total > maximoEstudiantes ? maximoEstudiantes : total)
        : total;

    return {
      'grupos': cantidadGrupos,
      'asignados': asignados,
      'espera': total - asignados,
    };
  }

  List<int> calcularTamanosGrupos(int cantidad) {
    final distribucion = calcularDistribucion(cantidad);
    final grupos = distribucion['grupos']!;
    final asignados = distribucion['asignados']!;
    if (grupos == 0) return [];

    final base = asignados ~/ grupos;
    final sobrantes = asignados % grupos;
    return List.generate(grupos, (i) => base + (i < sobrantes ? 1 : 0));
  }

  String letraGrupo(int indice) {
    // A, B, C... Z, AA, AB...
    var numero = indice + 1;
    var resultado = '';
    while (numero > 0) {
      numero--;
      resultado = String.fromCharCode(65 + (numero % 26)) + resultado;
      numero ~/= 26;
    }
    return resultado;
  }

  Future<void> abrirFormularioGrupo(
    Map<String, dynamic> demandaGrupo,
  ) async {
    try {
      final periodo = periodoSeleccionado;
      if (periodo == null ||
          periodo['fecha_inicio'] == null ||
          periodo['fecha_fin'] == null) {
        mostrarMensaje('El periodo debe tener fecha de inicio y fecha de fin.');
        return;
      }

      final estudiantes =
          demandaGrupo['estudiantes'] as List<Map<String, dynamic>>;
      final tamanos = calcularTamanosGrupos(estudiantes.length);
      if (tamanos.isEmpty) {
        mostrarMensaje('Se necesitan al menos 20 estudiantes.');
        return;
      }

      final respuestaProfesores = await supabase
          .from('profesores')
          .select('id, nombre_completo')
          .eq('activo', true)
          .order('nombre_completo');

      final todosProfesores =
          List<Map<String, dynamic>>.from(respuestaProfesores);

      // Un profesor que ya tiene grupo en este periodo no puede repetirse.
      final profesoresOcupados = gruposCreados
          .where((g) => g['profesor_id'] != null)
          .map((g) => (g['profesor_id'] as num).toInt())
          .toSet();

      final profesoresDisponibles = todosProfesores.where((p) {
        return !profesoresOcupados.contains((p['id'] as num).toInt());
      }).toList();

      if (profesoresDisponibles.length < tamanos.length) {
        mostrarMensaje(
          'Se necesitan ${tamanos.length} profesores disponibles '
          'y solo hay ${profesoresDisponibles.length}.',
        );
        return;
      }

      if (!mounted) return;
      final configuraciones = await showDialog<List<Map<String, dynamic>>>(
        context: context,
        barrierDismissible: false,
        builder: (context) => _FormularioGrupos(
          idioma: demandaGrupo['idioma'].toString(),
          nivel: demandaGrupo['nivel'].toString(),
          tamanos: tamanos,
          profesores: profesoresDisponibles,
        ),
      );

      if (configuraciones == null) return;

      await crearGruposAutomaticamente(
        demandaGrupo: demandaGrupo,
        estudiantes: estudiantes,
        configuraciones: configuraciones,
        periodo: periodo,
      );
      await cargarDatos();
    } catch (e) {
      mostrarMensaje('No fue posible crear los grupos: $e');
    }
  }

  Future<void> crearGruposAutomaticamente({
    required Map<String, dynamic> demandaGrupo,
    required List<Map<String, dynamic>> estudiantes,
    required List<Map<String, dynamic>> configuraciones,
    required Map<String, dynamic> periodo,
  }) async {
    final tamanos = calcularTamanosGrupos(estudiantes.length);
    var posicion = 0;

    try {
      for (int i = 0; i < tamanos.length; i++) {
        final cantidad = tamanos[i];
        final alumnosGrupo = estudiantes.sublist(posicion, posicion + cantidad);
        posicion += cantidad;

        final letra = letraGrupo(i);
        final idioma = demandaGrupo['idioma'].toString();
        final nivel = demandaGrupo['nivel'].toString();
        final periodoId = periodoSeleccionadoId!;

        // El periodo se incluye para evitar repetir códigos entre periodos.
        final codigo =
            'CELEX-${demandaGrupo['idioma_id']}-${demandaGrupo['nivel_id']}-$periodoId-$letra';
        final nombre = '$idioma $nivel $letra - ${periodo['nombre']}';

        final respuesta = await supabase
            .from('grupos')
            .insert({
              'nombre': nombre,
              'codigo_grupo': codigo,
              'nivel_id': demandaGrupo['nivel_id'],
              'periodo_id': periodoId,
              'profesor_id': configuraciones[i]['profesor_id'],
              'fecha_inicio': periodo['fecha_inicio'],
              'fecha_fin': periodo['fecha_fin'],
              // En la columna horario se guarda el intervalo de receso.
              'horario': configuraciones[i]['receso'],
              'cupo_maximo': 35,
              'modalidad': configuraciones[i]['modalidad'],
              'estado': 'Planeado',
              'publicado': false,
            })
            .select('id')
            .single();

        final grupoId = (respuesta['id'] as num).toInt();

        // Crear la inscripción pendiente de pago.
        for (final estudiante in alumnosGrupo) {
          await supabase.from('inscripciones').insert({
            'estudiante_id': estudiante['estudiante_id'],
            'solicitud_id': estudiante['solicitud_id'],
            'grupo_id': grupoId,
            'estado': 'Pendiente de pago',
          });

          // Actualizar también la solicitud con su grupo y estado.
          await supabase
              .from('solicitudes')
              .update({
                'grupo_id': grupoId,
                'estado': 'Pendiente de pago',
              })
              .eq('id', estudiante['solicitud_id']);
        }
      }

      final espera = estudiantes.length - posicion;
      mostrarMensaje(
        espera == 0
            ? 'Se crearon ${tamanos.length} grupos y se asignaron '
                '$posicion estudiantes.'
            : 'Se creó el grupo y se asignaron $posicion estudiantes. '
                '$espera quedan en espera para el siguiente periodo.',
      );
    } catch (e) {
      mostrarMensaje(
        'Ocurrió un error durante la creación. Revisa los grupos e '
        'inscripciones del periodo antes de volver a intentarlo. Detalle: $e',
      );
      rethrow;
    }
  }

  Future<void> editarGrupo(Map<String, dynamic> grupo) async {
    try {
      final respuestaProfesores = await supabase
          .from('profesores')
          .select('id, nombre_completo')
          .eq('activo', true)
          .order('nombre_completo');

      final ocupados = gruposCreados
          .where((g) => g['id'] != grupo['id'] && g['profesor_id'] != null)
          .map((g) => (g['profesor_id'] as num).toInt())
          .toSet();

      final profesores = List<Map<String, dynamic>>.from(respuestaProfesores)
          .where((p) => !ocupados.contains((p['id'] as num).toInt()))
          .toList();

      final profesorActual = grupo['profesores'] as Map<String, dynamic>?;
      final profesorActualId = grupo['profesor_id'] == null
          ? null
          : (grupo['profesor_id'] as num).toInt();

      if (profesorActualId != null &&
          !profesores.any((p) => (p['id'] as num).toInt() == profesorActualId)) {
        profesores.add({
          'id': profesorActualId,
          'nombre_completo':
              profesorActual?['nombre_completo'] ?? 'Profesor actual',
        });
      }

      if (!mounted) return;
      final datos = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => _EditarGrupoDialog(
          grupo: grupo,
          profesores: profesores,
        ),
      );

      if (datos == null) return;

      await supabase.from('grupos').update({
        'profesor_id': datos['profesor_id'],
        'horario': datos['receso'],
        'modalidad': datos['modalidad'],
      }).eq('id', grupo['id']);

      mostrarMensaje('Grupo actualizado correctamente.');
      await cargarGruposCreados();
    } catch (e) {
      mostrarMensaje('Error al editar el grupo: $e');
    }
  }

  Future<void> publicarGrupo(Map<String, dynamic> grupo) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Publicar grupo'),
        content: Text(
          '¿Deseas publicar "${grupo['nombre']}"?\n\n'
          'Los estudiantes podrán consultar su grupo solamente '
          'después de que su pago sea confirmado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Publicar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      await supabase.from('grupos').update({
        'publicado': true,
        'estado': 'Abierto',
        'fecha_publicacion': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', grupo['id']);

      mostrarMensaje('Grupo publicado correctamente.');
      await cargarGruposCreados();
    } catch (e) {
      mostrarMensaje('Error al publicar el grupo: $e');
    }
  }

  void mostrarMensaje(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: fondo,
      appBar: AppBar(
        title: const Text(
          'Administración de grupos',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: azul,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : periodos.isEmpty
              ? const Center(child: Text('Todavía no hay periodos registrados.'))
              : RefreshIndicator(
                  onRefresh: cargarDatos,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const Text(
                        'Filtrar por periodo',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: azul,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Card(
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 17,
                            vertical: 8,
                          ),
                          child: DropdownButtonFormField<int>(
                            initialValue: periodoSeleccionadoId,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Periodo académico',
                              border: InputBorder.none,
                              prefixIcon: Icon(
                                Icons.calendar_month,
                                color: azul,
                              ),
                            ),
                            items: periodos.map((p) {
                              final id = (p['id'] as num).toInt();
                              return DropdownMenuItem<int>(
                                value: id,
                                child: Text(
                                  '${p['nombre']} (${p['estado']})',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (id) async {
                              if (id == null ||
                                  id == periodoSeleccionadoId) {
                                return;
                              }

                              setState(() {
                                periodoSeleccionadoId = id;
                                demanda = [];
                                gruposCreados = [];
                              });

                              await cargarDatos();
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Demanda por idioma y nivel',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: azul,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Aquí aparecen los estudiantes disponibles para formar grupos.',
                        style: TextStyle(color: Colors.black54),
                      ),
                      const SizedBox(height: 16),
                      if (cargandoDemanda)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(30),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else if (demanda.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'No hay estudiantes disponibles para distribuir en este periodo.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      else
                        ...demanda.map(_tarjetaDemanda),
                      const SizedBox(height: 24),
                      const Text(
                        'Grupos del periodo',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: azul,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Grupos registrados: ${gruposCreados.length}',
                        style: const TextStyle(
                          color: azul,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (gruposCreados.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              'Todavía no se han creado grupos.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      else
                        ...gruposCreados.map(_tarjetaGrupo),
                      const SizedBox(height: 20),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Reglas para crear grupos',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: azul,
                                ),
                              ),
                              SizedBox(height: 12),
                              Text('• Mínimo: 20 estudiantes por grupo.'),
                              Text('• Máximo: 35 estudiantes por grupo.'),
                              Text('• La asignación respeta el orden de solicitud.'),
                              Text('• Cada grupo tiene un profesor diferente en el periodo.'),
                              Text('• El receso se asigna en intervalos de 20 minutos.'),
                              Text('• El estudiante verá su grupo después de que su pago sea confirmado.'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: cargarDatos,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Actualizar información'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: azul,
                          padding: const EdgeInsets.all(14),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _tarjetaDemanda(Map<String, dynamic> grupo) {
    final total = grupo['total'] as int;
    final cursos = grupo['cantidad_curso'] as int;
    final colocacion = grupo['cantidad_colocacion'] as int;
    final distribucion = calcularDistribucion(total);
    final puedeCrear = distribucion['grupos']! > 0;
    final espera = distribucion['espera']!;

    return Card(
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
              children: [
                const Icon(Icons.language, color: azul, size: 25),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    grupo['idioma'].toString(),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: azul,
                    ),
                  ),
                ),
                Text(
                  grupo['nivel'].toString(),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 24),
            _datoFila('Total de estudiantes', '$total'),
            const SizedBox(height: 8),
            _datoFila('Solicitudes de curso', '$cursos'),
            const SizedBox(height: 6),
            _datoFila('Exámenes de colocación', '$colocacion'),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: puedeCrear ? Colors.green.shade50 : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                !puedeCrear
                    ? 'Faltan ${minimoEstudiantes - total} estudiantes para alcanzar el mínimo.'
                    : espera > 0
                        ? 'Se pueden crear ${distribucion['grupos']} grupo(s). '
                            '$espera estudiante(s) quedarán en espera para el siguiente periodo.'
                        : 'Hay estudiantes suficientes para crear ${distribucion['grupos']} grupo(s).',
                style: TextStyle(
                  color: puedeCrear ? Colors.green.shade800 : Colors.orange.shade900,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (puedeCrear) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => abrirFormularioGrupo(grupo),
                  icon: const Icon(Icons.group_add),
                  label: const Text('Crear grupos y asignar estudiantes'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: azul,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(13),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _datoFila(String etiqueta, String valor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(etiqueta),
        Text(valor, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _tarjetaGrupo(Map<String, dynamic> grupo) {
    final nivel = grupo['niveles'] as Map<String, dynamic>?;
    final profesor = grupo['profesores'] as Map<String, dynamic>?;
    final idioma = nivel?['idiomas'] as Map<String, dynamic>?;

    return Card(
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
            Text(
              grupo['nombre'].toString(),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 17,
                color: azul,
              ),
            ),
            const SizedBox(height: 8),
            Text('Código: ${grupo['codigo_grupo'] ?? 'Sin código'}'),
            Text('Idioma: ${idioma?['nombre'] ?? 'No disponible'}'),
            Text('Nivel: ${nivel?['nombre'] ?? 'No disponible'}'),
            Text('Profesor: ${profesor?['nombre_completo'] ?? 'Sin asignar'}'),
            Text('Horario de receso: ${grupo['horario']}'),
            Text('Modalidad: ${grupo['modalidad']}'),
            Text('Cupo máximo: ${grupo['cupo_maximo']}'),
            Text('Estado: ${grupo['estado']}'),
            Text('Publicado: ${grupo['publicado'] == true ? 'Sí' : 'No'}'),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => editarGrupo(grupo),
                icon: const Icon(Icons.edit),
                label: const Text('Editar grupo'),
                style: OutlinedButton.styleFrom(foregroundColor: azul),
              ),
            ),
            if (grupo['publicado'] != true) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => publicarGrupo(grupo),
                  icon: const Icon(Icons.publish),
                  label: const Text('Publicar grupo'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: azul,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Opciones disponibles para el receso, todas de 20 minutos.
const List<String> horariosReceso = [
  '09:00 a 09:20',
  '09:20 a 09:40',
  '09:40 a 10:00',
  '10:00 a 10:20',
  '10:20 a 10:40',
  '10:40 a 11:00',
];

const List<String> modalidadesGrupo = ['Presencial', 'En línea', 'Mixta'];

class _FormularioGrupos extends StatefulWidget {
  final String idioma;
  final String nivel;
  final List<int> tamanos;
  final List<Map<String, dynamic>> profesores;

  const _FormularioGrupos({
    required this.idioma,
    required this.nivel,
    required this.tamanos,
    required this.profesores,
  });

  @override
  State<_FormularioGrupos> createState() => _FormularioGruposState();
}

class _FormularioGruposState extends State<_FormularioGrupos> {
  static const Color azul = Color(0xFF023C87);

  late List<int?> profesoresSeleccionados;
  late List<String> recesosSeleccionados;
  late List<String> modalidadesSeleccionadas;

  @override
  void initState() {
    super.initState();
    profesoresSeleccionados = List<int?>.filled(widget.tamanos.length, null);
    recesosSeleccionados = List<String>.filled(
      widget.tamanos.length,
      horariosReceso.first,
    );
    modalidadesSeleccionadas = List<String>.filled(
      widget.tamanos.length,
      'Presencial',
    );
  }

  List<Map<String, dynamic>>? validarYObtener() {
    if (profesoresSeleccionados.any((id) => id == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un profesor para cada grupo.')),
      );
      return null;
    }

    final ids = profesoresSeleccionados.whereType<int>().toList();
    if (ids.toSet().length != ids.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cada grupo debe tener un profesor diferente.')),
      );
      return null;
    }

    return List.generate(widget.tamanos.length, (i) => {
          'profesor_id': profesoresSeleccionados[i],
          'receso': recesosSeleccionados[i],
          'modalidad': modalidadesSeleccionadas[i],
        });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Crear grupos\n${widget.idioma} - ${widget.nivel}',
        style: const TextStyle(color: azul, fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Los estudiantes se asignarán automáticamente por orden de solicitud.',
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 12),
              ...List.generate(widget.tamanos.length, (i) {
                final letra = String.fromCharCode(65 + i);
                final idsOtros = profesoresSeleccionados
                    .asMap()
                    .entries
                    .where((e) => e.key != i && e.value != null)
                    .map((e) => e.value)
                    .toSet();

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Grupo $letra · ${widget.tamanos[i]} estudiantes',
                          style: const TextStyle(
                            color: azul,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<int>(
                          initialValue: profesoresSeleccionados[i],
                          decoration: const InputDecoration(
                            labelText: 'Profesor',
                            border: OutlineInputBorder(),
                          ),
                          items: widget.profesores
                              .where((p) => !idsOtros.contains((p['id'] as num).toInt()))
                              .map((p) => DropdownMenuItem<int>(
                                    value: (p['id'] as num).toInt(),
                                    child: Text(p['nombre_completo'].toString()),
                                  ))
                              .toList(),
                          onChanged: (id) {
                            setState(() => profesoresSeleccionados[i] = id);
                          },
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          initialValue: recesosSeleccionados[i],
                          decoration: const InputDecoration(
                            labelText: 'Horario de receso',
                            border: OutlineInputBorder(),
                          ),
                          items: horariosReceso
                              .map((h) => DropdownMenuItem(value: h, child: Text(h)))
                              .toList(),
                          onChanged: (valor) {
                            if (valor != null) {
                              setState(() => recesosSeleccionados[i] = valor);
                            }
                          },
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          initialValue: modalidadesSeleccionadas[i],
                          decoration: const InputDecoration(
                            labelText: 'Modalidad',
                            border: OutlineInputBorder(),
                          ),
                          items: modalidadesGrupo
                              .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                              .toList(),
                          onChanged: (valor) {
                            if (valor != null) {
                              setState(() => modalidadesSeleccionadas[i] = valor);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            final resultado = validarYObtener();
            if (resultado != null) Navigator.pop(context, resultado);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: azul,
            foregroundColor: Colors.white,
          ),
          child: const Text('Crear grupos'),
        ),
      ],
    );
  }
}

class _EditarGrupoDialog extends StatefulWidget {
  final Map<String, dynamic> grupo;
  final List<Map<String, dynamic>> profesores;

  const _EditarGrupoDialog({
    required this.grupo,
    required this.profesores,
  });

  @override
  State<_EditarGrupoDialog> createState() => _EditarGrupoDialogState();
}

class _EditarGrupoDialogState extends State<_EditarGrupoDialog> {
  static const Color azul = Color(0xFF023C87);

  int? profesorId;
  late String receso;
  late String modalidad;

  @override
  void initState() {
    super.initState();
    profesorId = widget.grupo['profesor_id'] == null
        ? null
        : (widget.grupo['profesor_id'] as num).toInt();
    receso = horariosReceso.contains(widget.grupo['horario'])
        ? widget.grupo['horario'].toString()
        : horariosReceso.first;
    modalidad = modalidadesGrupo.contains(widget.grupo['modalidad'])
        ? widget.grupo['modalidad'].toString()
        : 'Presencial';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Editar grupo',
        style: TextStyle(color: azul, fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: 450,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<int>(
              initialValue: profesorId,
              decoration: const InputDecoration(
                labelText: 'Profesor',
                border: OutlineInputBorder(),
              ),
              items: widget.profesores.map((p) {
                return DropdownMenuItem<int>(
                  value: (p['id'] as num).toInt(),
                  child: Text(p['nombre_completo'].toString()),
                );
              }).toList(),
              onChanged: (id) => setState(() => profesorId = id),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: receso,
              decoration: const InputDecoration(
                labelText: 'Horario de receso',
                border: OutlineInputBorder(),
              ),
              items: horariosReceso
                  .map((h) => DropdownMenuItem(value: h, child: Text(h)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => receso = v);
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: modalidad,
              decoration: const InputDecoration(
                labelText: 'Modalidad',
                border: OutlineInputBorder(),
              ),
              items: modalidadesGrupo
                  .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => modalidad = v);
              },
            ),
            const SizedBox(height: 10),
            const Text(
              'Las fechas y los días de clase pertenecen al periodo y no se modifican desde aquí.',
              style: TextStyle(color: Colors.black54, fontSize: 12),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: profesorId == null
              ? null
              : () => Navigator.pop(context, {
                    'profesor_id': profesorId,
                    'receso': receso,
                    'modalidad': modalidad,
                  }),
          style: ElevatedButton.styleFrom(
            backgroundColor: azul,
            foregroundColor: Colors.white,
          ),
          child: const Text('Guardar cambios'),
        ),
      ],
    );
  }
}
