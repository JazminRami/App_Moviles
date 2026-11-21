
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Colores principales de CELEX Academy.
const Color azulIdiomas = Color(0xFF023C87);
const Color fondoIdiomas = Color(0xFFEAF1FB);

// Pantalla donde se muestran los idiomas disponibles.
class IdiomasNiveles extends StatefulWidget {
  const IdiomasNiveles({super.key});

  @override
  State<IdiomasNiveles> createState() => _IdiomasNivelesState();
}

class _IdiomasNivelesState extends State<IdiomasNiveles> {
  late Future<List<Map<String, dynamic>>> futureIdiomas;

  @override
  void initState() {
    super.initState();
    cargarIdiomas();
  }

  // Consulta los idiomas activos en Supabase.
  void cargarIdiomas() {
    futureIdiomas = Supabase.instance.client
        .from('idiomas')
        .select('id, nombre')
        .eq('activo', true)
        .order('nombre');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: fondoIdiomas,
      appBar: AppBar(
        title: const Text(
          'Idiomas disponibles',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: azulIdiomas,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: futureIdiomas,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('No se pudieron cargar los idiomas.'),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {
                      setState(cargarIdiomas);
                    },
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }

          final idiomas = snapshot.data ?? [];

          if (idiomas.isEmpty) {
            return const Center(
              child: Text('No hay idiomas disponibles.'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: idiomas.length,
            itemBuilder: (context, index) {
              final idioma = idiomas[index];

              return Card(
                margin: const EdgeInsets.only(bottom: 14),
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: const CircleAvatar(
                    backgroundColor: fondoIdiomas,
                    child: Icon(
                      Icons.language,
                      color: azulIdiomas,
                    ),
                  ),
                  title: Text(
                    idioma['nombre'].toString(),
                    style: const TextStyle(
                      color: azulIdiomas,
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                  subtitle: const Text(
                    'Consultar información y opciones',
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios,
                    color: azulIdiomas,
                    size: 18,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PantallaNiveles(
                          idiomaId: (idioma['id'] as num).toInt(),
                          nombreIdioma: idioma['nombre'].toString(),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// Información del estado académico del estudiante.
class EstadoIdioma {
  final String tipo;
  final Map<String, dynamic>? solicitud;
  final Map<String, dynamic>? nivelActual;
  final Map<String, dynamic>? siguienteNivel;
  final String? nombreIdiomaProceso;
  final String? nombreNivelProceso;

  const EstadoIdioma({
    required this.tipo,
    this.solicitud,
    this.nivelActual,
    this.siguienteNivel,
    this.nombreIdiomaProceso,
    this.nombreNivelProceso,
  });
}

// Pantalla de información y opciones del idioma seleccionado.
class PantallaNiveles extends StatefulWidget {
  final int idiomaId;
  final String nombreIdioma;

  const PantallaNiveles({
    super.key,
    required this.idiomaId,
    required this.nombreIdioma,
  });

  @override
  State<PantallaNiveles> createState() => _PantallaNivelesState();
}

class _PantallaNivelesState extends State<PantallaNiveles> {
  final supabase = Supabase.instance.client;

  late Future<EstadoIdioma> futureEstado;
  bool enviandoSolicitud = false;

  @override
  void initState() {
    super.initState();
    cargarEstado();
  }

  // Completa los nombres del idioma y nivel de un proceso activo.
  Future<Map<String, dynamic>> completarDatosProceso(
    Map<String, dynamic> proceso,
  ) async {
    final idiomaId = proceso['idioma_id'];
    final nivelId = proceso['nivel_id'];

    String nombreIdioma = 'Otro idioma';
    String nombreNivel = 'Por determinar';

    if (idiomaId != null) {
      final idioma = await supabase
          .from('idiomas')
          .select('nombre')
          .eq('id', idiomaId)
          .maybeSingle();

      nombreIdioma = idioma?['nombre']?.toString() ?? nombreIdioma;
    }

    if (nivelId != null) {
      final nivel = await supabase
          .from('niveles')
          .select('nombre')
          .eq('id', nivelId)
          .maybeSingle();

      nombreNivel = nivel?['nombre']?.toString() ?? nombreNivel;
    } else if (proceso['tipo_tramite'] != null) {
      nombreNivel = proceso['tipo_tramite'].toString();
    }

    proceso['_nombre_idioma'] = nombreIdioma;
    proceso['_nombre_nivel'] = nombreNivel;

    return proceso;
  }

  // Busca si el estudiante tiene una solicitud o curso en proceso
  // en CUALQUIER idioma.
  Future<Map<String, dynamic>?> obtenerProcesoActivo(
    String estudianteId,
  ) async {
    // 1. Solicitudes que todavía requieren atención.
    final respuestaPendientes = await supabase
        .from('solicitudes')
        .select('''
          id,
          estudiante_id,
          idioma_id,
          nivel_id,
          tipo_tramite,
          estado,
          fecha_solicitud
        ''')
        .eq('estudiante_id', estudianteId)
        .inFilter('estado', [
          'Pendiente',
          'En revisión',
          'Esperando grupo',
          'Pendiente de pago',
        ])
        .order('fecha_solicitud', ascending: false)
        .limit(1);

    final pendientes =
        List<Map<String, dynamic>>.from(respuestaPendientes);

    if (pendientes.isNotEmpty) {
      final proceso = Map<String, dynamic>.from(pendientes.first);
      proceso['_origen'] = 'solicitud';

      return completarDatosProceso(proceso);
    }

    // 2. Revisar si existe un curso que todavía esté en curso.
    final respuestaCursos = await supabase
        .from('historial_academico')
        .select('''
          id,
          idioma_id,
          nivel_id,
          estado,
          fecha_registro
        ''')
        .eq('estudiante_id', estudianteId)
        .eq('estado', 'En curso')
        .order('fecha_registro', ascending: false)
        .limit(1);

    final cursos = List<Map<String, dynamic>>.from(respuestaCursos);

    if (cursos.isNotEmpty) {
      final proceso = Map<String, dynamic>.from(cursos.first);
      proceso['_origen'] = 'curso';

      return completarDatosProceso(proceso);
    }

    // 3. Revisar solicitudes cuyo pago ya fue confirmado.
    // Se mantienen como proceso activo mientras no exista
    // un resultado finalizado posterior a la solicitud.
    final respuestaPagadas = await supabase
        .from('solicitudes')
        .select('''
          id,
          estudiante_id,
          idioma_id,
          nivel_id,
          tipo_tramite,
          estado,
          fecha_solicitud
        ''')
        .eq('estudiante_id', estudianteId)
        .eq('estado', 'Pago confirmado')
        .order('fecha_solicitud', ascending: false)
        .limit(1);

    final pagadas = List<Map<String, dynamic>>.from(respuestaPagadas);

    if (pagadas.isNotEmpty) {
      final solicitud = Map<String, dynamic>.from(pagadas.first);

      // Buscar el historial más reciente del mismo idioma.
      final respuestaHistorial = await supabase
          .from('historial_academico')
          .select('''
            id,
            nivel_id,
            estado,
            fecha_registro
          ''')
          .eq('estudiante_id', estudianteId)
          .eq('idioma_id', solicitud['idioma_id'])
          .order('fecha_registro', ascending: false)
          .limit(1);

      final historial =
          List<Map<String, dynamic>>.from(respuestaHistorial);

      bool cursoTerminadoDespuesDeSolicitud = false;

      if (historial.isNotEmpty) {
        final ultimo = historial.first;

        final fechaSolicitud =
            DateTime.tryParse(
              solicitud['fecha_solicitud']?.toString() ?? '',
            );

        final fechaRegistro =
            DateTime.tryParse(
              ultimo['fecha_registro']?.toString() ?? '',
            );

        cursoTerminadoDespuesDeSolicitud =
            ultimo['estado'] == 'Finalizado' &&
            fechaSolicitud != null &&
            fechaRegistro != null &&
            fechaRegistro.isAfter(fechaSolicitud);
      }

      // Si el curso todavía no terminó, el pago confirmado
      // sigue representando un proceso activo.
      if (!cursoTerminadoDespuesDeSolicitud) {
        solicitud['_origen'] = 'solicitud';
        return completarDatosProceso(solicitud);
      }
    }

    // No tiene solicitudes pendientes ni cursos en proceso.
    return null;
  }

  // Consulta el estado global y después el historial del idioma.
  Future<EstadoIdioma> consultarEstado() async {
    final usuario = supabase.auth.currentUser;

    if (usuario == null) {
      throw Exception('No hay una sesión iniciada.');
    }

    // Comprobar primero si existe otro proceso activo.
    final proceso = await obtenerProcesoActivo(usuario.id);

    if (proceso != null) {
      final idiomaProceso =
          (proceso['idioma_id'] as num?)?.toInt();

      // Si el proceso pertenece a otro idioma, se bloquea.
      if (idiomaProceso != widget.idiomaId) {
        return EstadoIdioma(
          tipo: 'bloqueado',
          nombreIdiomaProceso:
              proceso['_nombre_idioma']?.toString() ?? 'Otro idioma',
          nombreNivelProceso:
              proceso['_nombre_nivel']?.toString() ?? 'Por determinar',
          solicitud: proceso,
        );
      }

      // Si la solicitud pertenece al mismo idioma,
      // todavía no puede registrar otra.
      if (proceso['_origen'] == 'solicitud') {
        return EstadoIdioma(
          tipo: 'solicitud',
          solicitud: proceso,
        );
      }

      // Si es un curso en proceso del mismo idioma,
      // continuamos para mostrar el nivel correspondiente.
    }

    // Buscar el historial académico más reciente del idioma.
    final respuestaHistorial = await supabase
        .from('historial_academico')
        .select('''
          id,
          idioma_id,
          nivel_id,
          calificacion_final,
          estado,
          fecha_registro
        ''')
        .eq('estudiante_id', usuario.id)
        .eq('idioma_id', widget.idiomaId)
        .order('fecha_registro', ascending: false)
        .limit(1);

    final historial =
        List<Map<String, dynamic>>.from(respuestaHistorial);

    // Si no tiene historial, es alumno de nuevo ingreso.
    if (historial.isEmpty) {
      return const EstadoIdioma(tipo: 'nuevo');
    }

    final ultimoRegistro = historial.first;

    // Consultar los datos del nivel que cursó.
    final respuestaNivel = await supabase
        .from('niveles')
        .select('id, nombre, orden')
        .eq('id', ultimoRegistro['nivel_id'])
        .maybeSingle();

    if (respuestaNivel == null) {
      throw Exception('No se encontró el nivel de tu historial.');
    }

    final nivelActual = Map<String, dynamic>.from(respuestaNivel);

    // Si el estudiante todavía está cursando.
    if (ultimoRegistro['estado'] == 'En curso') {
      return EstadoIdioma(
        tipo: 'curso',
        nivelActual: nivelActual,
      );
    }

    // Si el historial no está finalizado, no permitir avanzar.
    if (ultimoRegistro['estado'] != 'Finalizado') {
      return EstadoIdioma(
        tipo: 'curso',
        nivelActual: nivelActual,
      );
    }

    // Revisar la calificación final.
    final calificacion =
        (ultimoRegistro['calificacion_final'] as num?)?.toDouble();

    if (calificacion == null) {
      return EstadoIdioma(
        tipo: 'curso',
        nivelActual: nivelActual,
      );
    }

    // Si obtuvo menos de 8, debe repetir el nivel.
    if (calificacion < 8) {
      return EstadoIdioma(
        tipo: 'reprobado',
        nivelActual: nivelActual,
      );
    }

    // Si aprobó, buscar el siguiente nivel.
    final ordenActual = (nivelActual['orden'] as num).toInt();

    final respuestaSiguienteNivel = await supabase
        .from('niveles')
        .select('id, nombre, orden')
        .eq('idioma_id', widget.idiomaId)
        .eq('activo', true)
        .eq('orden', ordenActual + 1)
        .maybeSingle();

    if (respuestaSiguienteNivel == null) {
      return EstadoIdioma(
        tipo: 'completo',
        nivelActual: nivelActual,
      );
    }

    return EstadoIdioma(
      tipo: 'aprobado',
      nivelActual: nivelActual,
      siguienteNivel: Map<String, dynamic>.from(
        respuestaSiguienteNivel,
      ),
    );
  }

  // Carga o vuelve a cargar el estado académico.
  void cargarEstado() {
    futureEstado = consultarEstado();
  }

  // Muestra un mensaje en la parte inferior.
  void mostrarMensaje(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje)),
    );
  }

  // Busca automáticamente el periodo con inscripciones abiertas.
  Future<int> obtenerPeriodoDisponible() async {
    final ahora = DateTime.now();

    final fechaActual =
        '${ahora.year}-'
        '${ahora.month.toString().padLeft(2, '0')}-'
        '${ahora.day.toString().padLeft(2, '0')}';

    final respuesta = await supabase
        .from('periodos')
        .select('id, nombre, fecha_inicio, fecha_limite_pago')
        .eq('estado', 'Inscripciones')
        .gte('fecha_limite_pago', fechaActual)
        .order('fecha_inicio', ascending: true)
        .limit(1)
        .maybeSingle();

    if (respuesta == null) {
      throw Exception(
        'No hay periodos con inscripciones abiertas actualmente.',
      );
    }

    return (respuesta['id'] as num).toInt();
  }

  // Confirma y guarda una solicitud real en Supabase.
  Future<void> enviarSolicitud({
    required String tipoTramite,
    int? nivelId,
    required String nombreNivel,
  }) async {
    if (enviandoSolicitud) return;

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(
            Icons.assignment_outlined,
            color: azulIdiomas,
            size: 45,
          ),
          title: const Text('Confirmar solicitud'),
          content: Text(
            'Estás por solicitar el siguiente trámite:\n\n'
            'Idioma: ${widget.nombreIdioma}\n\n'
            'Trámite: $tipoTramite\n\n'
            'Nivel: $nombreNivel\n\n'
            '¿Deseas enviar esta solicitud?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: azulIdiomas,
                foregroundColor: Colors.white,
              ),
              child: const Text('Enviar solicitud'),
            ),
          ],
        );
      },
    );

    if (confirmado != true || !mounted) return;

    setState(() {
      enviandoSolicitud = true;
    });

    try {
      final usuario = supabase.auth.currentUser;

      if (usuario == null) {
        throw Exception(
          'Tu sesión ha terminado. Inicia sesión nuevamente.',
        );
      }

      // SEGUNDA COMPROBACIÓN:
      // Verificamos que no haya comenzado otro proceso
      // mientras el estudiante confirmaba la solicitud.
      final procesoExistente =
          await obtenerProcesoActivo(usuario.id);

      if (procesoExistente != null) {
        final idiomaProceso =
            procesoExistente['_nombre_idioma']?.toString() ??
                'otro idioma';

        final nivelProceso =
            procesoExistente['_nombre_nivel']?.toString() ??
                'Por determinar';

        throw Exception(
          'Actualmente tienes un proceso en $idiomaProceso, '
          'nivel $nivelProceso. Debes concluirlo antes de '
          'registrar otra solicitud.',
        );
      }

      // Obtener automáticamente el periodo disponible.
      final periodoId = await obtenerPeriodoDisponible();

      // Registrar la solicitud.
      await supabase.from('solicitudes').insert({
        'estudiante_id': usuario.id,
        'idioma_id': widget.idiomaId,
        'periodo_id': periodoId,
        'tipo_tramite': tipoTramite,
        'nivel_id': nivelId,
        'estado': 'Pendiente',
      });

      if (!mounted) return;

      setState(() {
        cargarEstado();
      });

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            icon: const Icon(
              Icons.check_circle_outline,
              color: azulIdiomas,
              size: 48,
            ),
            title: const Text('Solicitud registrada'),
            content: const Text(
              'Tu solicitud se guardó correctamente.\n\n'
              'Podrás consultar su estado en el apartado '
              'Historial de solicitudes.\n\n'
              'Espera la confirmación de CELEX antes de '
              'realizar cualquier pago.',
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: azulIdiomas,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Aceptar'),
              ),
            ],
          );
        },
      );
    } catch (error) {
      if (!mounted) return;

      mostrarMensaje(
        error.toString().replaceFirst('Exception: ', ''),
      );

      setState(() {
        cargarEstado();
      });
    } finally {
      if (mounted) {
        setState(() {
          enviandoSolicitud = false;
        });
      }
    }
  }

  // Busca el nivel Introductorio del idioma seleccionado.
  Future<void> solicitarIntroductorio() async {
    try {
      final respuesta = await supabase
          .from('niveles')
          .select('id, nombre')
          .eq('idioma_id', widget.idiomaId)
          .eq('nombre', 'Introductorio')
          .eq('activo', true)
          .maybeSingle();

      if (!mounted) return;

      if (respuesta == null) {
        mostrarMensaje(
          'No se encontró el nivel Introductorio para este idioma.',
        );
        return;
      }

      await enviarSolicitud(
        tipoTramite: 'Iniciar desde Introductorio',
        nivelId: (respuesta['id'] as num).toInt(),
        nombreNivel: respuesta['nombre'].toString(),
      );
    } catch (error) {
      if (!mounted) return;

      mostrarMensaje(
        'No se pudo consultar Introductorio: $error',
      );
    }
  }

  // Información general de los niveles.
  Widget construirInformacionNiveles() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Información de los niveles',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: azulIdiomas,
              ),
            ),
            SizedBox(height: 12),
            Text('• Introductorio: nivel inicial para principiantes'),
            SizedBox(height: 8),
            Text('• Básico: niveles 1 al 5'),
            SizedBox(height: 8),
            Text('• Intermedio: niveles 1 al 5'),
            SizedBox(height: 8),
            Text('• Avanzado: niveles 1 al 5'),
          ],
        ),
      ),
    );
  }

  // Botón reutilizable.
  Widget construirBoton({
    required String texto,
    required IconData icono,
    required VoidCallback? accion,
    bool relleno = false,
  }) {
    if (relleno) {
      return ElevatedButton.icon(
        onPressed: accion,
        icon: Icon(icono),
        label: Text(texto),
        style: ElevatedButton.styleFrom(
          backgroundColor: azulIdiomas,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 15),
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: accion,
      icon: Icon(icono),
      label: Text(texto),
      style: OutlinedButton.styleFrom(
        foregroundColor: azulIdiomas,
        side: const BorderSide(color: azulIdiomas),
        padding: const EdgeInsets.symmetric(vertical: 15),
      ),
    );
  }

  // Opciones según el estado académico del estudiante.
  Widget construirOpciones(EstadoIdioma estado) {
    switch (estado.tipo) {
      case 'nuevo':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Alumno de nuevo ingreso',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: azulIdiomas,
              ),
            ),
            const SizedBox(height: 10),
            construirBoton(
              texto: 'Solicitar examen de colocación',
              icono: Icons.assignment,
              relleno: true,
              accion: () {
                enviarSolicitud(
                  tipoTramite: 'Examen de colocación',
                  nivelId: null,
                  nombreNivel: 'Por determinar mediante examen',
                );
              },
            ),
            const SizedBox(height: 10),
            construirBoton(
              texto: 'Iniciar desde Introductorio',
              icono: Icons.school,
              accion: solicitarIntroductorio,
            ),
          ],
        );

      case 'bloqueado':
        return _tarjetaEstado(
          titulo: 'Actualmente tienes otro curso en proceso',
          descripcion:
              'Actualmente estás realizando tu proceso académico '
              'en ${estado.nombreIdiomaProceso}, nivel '
              '${estado.nombreNivelProceso}.\n\n'
              'Como los cursos de los idiomas se desarrollan '
              'durante el mismo periodo, por ahora solo puedes '
              'tener una solicitud o curso en proceso.\n\n'
              'Cuando concluyas este curso y se registre tu '
              'calificación, podrás continuar al siguiente nivel, '
              'repetirlo si es necesario o comenzar con otro idioma.\n\n'
              '¡Gracias por tu comprensión!',
          icono: Icons.lock_outline,
        );

      case 'solicitud':
        final solicitud = estado.solicitud!;

        return _tarjetaEstado(
          titulo: 'Ya tienes una solicitud registrada',
          descripcion:
              'Trámite: ${solicitud['tipo_tramite']}\n'
              'Estado: ${solicitud['estado']}\n\n'
              'Debes esperar a que CELEX complete este proceso. '
              'No necesitas enviar otra solicitud.',
          icono: Icons.hourglass_top,
        );

      case 'curso':
        return _tarjetaEstado(
          titulo: 'Tienes un curso en proceso',
          descripcion:
              'Actualmente tienes registrado el nivel '
              '${estado.nivelActual!['nombre']}.\n\n'
              'Cuando CELEX registre tu calificación final, '
              'podrás continuar al siguiente nivel o repetirlo.',
          icono: Icons.menu_book,
        );

      case 'aprobado':
        final siguiente = estado.siguienteNivel!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _tarjetaEstado(
              titulo: '¡Felicidades, aprobaste!',
              descripcion:
                  'Tu último nivel registrado es '
                  '${estado.nivelActual!['nombre']}.\n\n'
                  'Puedes registrar tu solicitud para continuar '
                  'al siguiente nivel: ${siguiente['nombre']}.\n\n'
                  'Recuerda hacerlo desde esta sección de '
                  'Idiomas y niveles.',
              icono: Icons.emoji_events,
            ),
            const SizedBox(height: 12),
            construirBoton(
              texto: 'Reinscribirme a ${siguiente['nombre']}',
              icono: Icons.trending_up,
              relleno: true,
              accion: () {
                enviarSolicitud(
                  tipoTramite: 'Continuar al siguiente nivel',
                  nivelId: (siguiente['id'] as num).toInt(),
                  nombreNivel: siguiente['nombre'].toString(),
                );
              },
            ),
          ],
        );

      case 'reprobado':
        final actual = estado.nivelActual!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _tarjetaEstado(
              titulo: 'Necesitas repetir este nivel',
              descripcion:
                  'Tu último nivel registrado es '
                  '${actual['nombre']}.\n\n'
                  'Tu calificación fue menor a 8.0, por lo que '
                  'debes volver a cursar este mismo nivel.',
              icono: Icons.replay,
            ),
            const SizedBox(height: 12),
            construirBoton(
              texto: 'Reinscribirme a ${actual['nombre']}',
              icono: Icons.replay,
              relleno: true,
              accion: () {
                enviarSolicitud(
                  tipoTramite: 'Recursar nivel',
                  nivelId: (actual['id'] as num).toInt(),
                  nombreNivel: actual['nombre'].toString(),
                );
              },
            ),
          ],
        );

      case 'completo':
        return _tarjetaEstado(
          titulo: '¡Has completado los niveles!',
          descripcion:
              'Tu último nivel registrado es '
              '${estado.nivelActual!['nombre']}.\n\n'
              'Has completado todos los niveles disponibles '
              'de este idioma. Puedes consultar el apartado '
              'de solicitud de certificado.',
          icono: Icons.workspace_premium,
        );

      default:
        return const Text(
          'No se pudo determinar tu situación académica.',
        );
    }
  }

  // Tarjeta informativa.
  Widget _tarjetaEstado({
    required String titulo,
    required String descripcion,
    required IconData icono,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Icon(
              icono,
              color: azulIdiomas,
              size: 42,
            ),
            const SizedBox(height: 12),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: azulIdiomas,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              descripcion,
              textAlign: TextAlign.center,
              style: const TextStyle(
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: fondoIdiomas,
      appBar: AppBar(
        title: Text(
          widget.nombreIdioma,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: azulIdiomas,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<EstadoIdioma>(
        future: futureEstado,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: azulIdiomas,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No se pudo consultar tu información académica.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 15),
                    ElevatedButton(
                      onPressed: () {
                        setState(cargarEstado);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: azulIdiomas,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            );
          }

          final estado = snapshot.data;

          if (estado == null) {
            return const Center(
              child: Text('No se encontró información.'),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.menu_book,
                  size: 65,
                  color: azulIdiomas,
                ),
                const SizedBox(height: 15),
                Text(
                  'Niveles de ${widget.nombreIdioma}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: azulIdiomas,
                  ),
                ),
                const SizedBox(height: 18),

                construirInformacionNiveles(),

                const SizedBox(height: 25),

                if (enviandoSolicitud)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),

                construirOpciones(estado),

                const SizedBox(height: 25),
                const Divider(),
                const SizedBox(height: 12),

                const Text(
                  'Importante: enviar una solicitud no garantiza '
                  'la apertura de un grupo. Espera la confirmación '
                  'de CELEX antes de realizar cualquier pago.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 13,
                    height: 1.5,
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
