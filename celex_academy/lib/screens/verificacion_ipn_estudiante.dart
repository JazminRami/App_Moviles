
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VerificacionIpnEstudiante extends StatefulWidget {
  const VerificacionIpnEstudiante({super.key});

  @override
  State<VerificacionIpnEstudiante> createState() =>
      _VerificacionIpnEstudianteState();
}

class _VerificacionIpnEstudianteState
    extends State<VerificacionIpnEstudiante> {
  final supabase = Supabase.instance.client;

  final Color azul = const Color(0xFF023C87);
  final Color fondo = const Color(0xFFEAF1FB);

  String categoria = 'Comunidad IPN';
  String tipoDocumento = 'PDF de credencial';

  int? periodoId;
  String? nombrePeriodo;

  PlatformFile? archivoSeleccionado;
  int? tamanoArchivo;

  Map<String, dynamic>? verificacionExistente;

  bool cargando = true;
  bool enviando = false;

  @override
  void initState() {
    super.initState();
    cargarInformacion();
  }

  // Busca el periodo activo y la verificación del estudiante.
  Future<void> cargarInformacion() async {
    try {
      final respuesta = await supabase
          .from('periodos')
          .select('id, nombre, estado')
          .order('fecha_registro', ascending: false)
          .limit(20);

      final periodos = List<Map<String, dynamic>>.from(respuesta);

      const estadosActivos = [
        'Inscripciones',
        'Colocacion',
        'Distribucion',
        'Pagos',
        'En curso',
      ];

      Map<String, dynamic>? periodoActual;

      for (final periodo in periodos) {
        if (estadosActivos.contains(
          periodo['estado']?.toString().trim(),
        )) {
          periodoActual = periodo;
          break;
        }
      }

      if (periodoActual == null) {
        if (!mounted) return;

        setState(() {
          periodoId = null;
          nombrePeriodo = null;
          verificacionExistente = null;
          cargando = false;
        });
        return;
      }

      final nuevoPeriodoId =
          int.tryParse(periodoActual['id'].toString());

      if (nuevoPeriodoId == null) {
        throw Exception('El identificador del periodo no es válido.');
      }

      final usuario = supabase.auth.currentUser;

      if (usuario == null) {
        throw Exception('No hay una sesión iniciada.');
      }

      final existente = await supabase
          .from('verificaciones_ipn_periodo')
          .select(
            'id, categoria_solicitada, categoria_aplicada, '
            'estado, observaciones, fecha_registro, '
            'documento_path, tipo_documento',
          )
          .eq('estudiante_id', usuario.id)
          .eq('periodo_id', nuevoPeriodoId)
          .maybeSingle();

      if (!mounted) return;

      setState(() {
        periodoId = nuevoPeriodoId;
        nombrePeriodo = periodoActual!['nombre']?.toString();
        verificacionExistente = existente;

        categoria =
            existente?['categoria_solicitada']?.toString() ??
            'Comunidad IPN';

        archivoSeleccionado = null;
        tamanoArchivo = null;
        cargando = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        cargando = false;
      });

      mostrarMensaje('Error al cargar información: $error');
    }
  }

  // Selecciona el archivo localmente. No lo sube a Supabase.
  Future<void> seleccionarArchivo() async {
    try {
      final archivo = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      );

      if (archivo == null) return;

      final tamano = await archivo.length();

      if (tamano == null) {
        mostrarMensaje('No se pudo determinar el tamaño del archivo.');
        return;
      }

      if (tamano > 5 * 1024 * 1024) {
        mostrarMensaje('El archivo no debe superar los 5 MB.');
        return;
      }

      final extension = archivo.extension?.toLowerCase();

      if (!['jpg', 'jpeg', 'png', 'pdf'].contains(extension)) {
        mostrarMensaje('Selecciona una imagen JPG, PNG o un PDF.');
        return;
      }

      if (!mounted) return;

      setState(() {
        archivoSeleccionado = archivo;
        tamanoArchivo = tamano;
        tipoDocumento = extension == 'pdf'
            ? 'PDF de credencial'
            : 'Fotografía de credencial';
      });

      mostrarMensaje('Documento seleccionado. Aún no se ha enviado.');
    } catch (error) {
      if (mounted) {
        mostrarMensaje('No se pudo seleccionar el archivo: $error');
      }
    }
  }

  // Cambia la verificación rechazada a Público general mediante RPC.
  Future<void> cambiarAPublicoGeneral(
    Map<String, dynamic> existente,
  ) async {
    final id = int.tryParse(existente['id'].toString());

    if (id == null) {
      throw Exception('El ID de la verificación no es válido.');
    }

    await supabase.rpc(
      'cambiar_verificacion_a_publico_general',
      params: {
        'p_verificacion_id': id,
      },
    );

    if (!mounted) return;

    setState(() {
      archivoSeleccionado = null;
      tamanoArchivo = null;
    });

    await cargarInformacion();

    if (!mounted) return;

    mostrarMensaje(
      'Tu categoría cambió a Público general. '
      'Ya no necesitas verificar tu pertenencia al IPN.',
    );
  }

  // Registra una solicitud nueva o reenvía una rechazada.
  Future<void> enviarVerificacion() async {
    if (enviando) return;

    if (periodoId == null) {
      mostrarMensaje('No hay un periodo disponible.');
      return;
    }

    final usuario = supabase.auth.currentUser;

    if (usuario == null) {
      mostrarMensaje('Debes iniciar sesión nuevamente.');
      return;
    }

    final existente = verificacionExistente;
    final estadoExistente = existente?['estado']?.toString();

    // Una verificación existente solo se puede modificar si fue rechazada.
    if (existente != null && estadoExistente != 'Rechazada') {
      mostrarMensaje('Tu verificación ya está registrada.');
      return;
    }

    setState(() {
      enviando = true;
    });

    String? rutaArchivoNuevo;
    bool archivoSubido = false;
    bool registroGuardado = false;

    try {
      // Caso 1: el alumno rechazado decide cambiar a Público general.
      if (existente != null && categoria == 'Público general') {
        await cambiarAPublicoGeneral(existente);
        return;
      }

      // Caso 2: registro nuevo de Público general, sin documento.
      if (existente == null && categoria == 'Público general') {
        final respuesta = await supabase
            .from('verificaciones_ipn_periodo')
            .insert({
              'estudiante_id': usuario.id,
              'periodo_id': periodoId,
              'categoria_solicitada': 'Público general',
              'categoria_aplicada': 'Público general',
              'estado': 'No aplica',
              'documento_path': null,
              'tipo_documento': null,
              'observaciones': null,
              'verificado_por': null,
              'fecha_verificacion': null,
            })
            .select('id')
            .single();

        registroGuardado = true;

        debugPrint(
          'Categoría Público general registrada. '
          'ID: ${respuesta['id']}',
        );

        if (!mounted) return;

        await cargarInformacion();

        if (!mounted) return;

        mostrarMensaje(
          'Tu categoría quedó registrada como Público general.',
        );
        return;
      }

      // Caso 3: Comunidad IPN. Se necesita un documento.
      if (categoria == 'Comunidad IPN' &&
          archivoSeleccionado == null) {
        mostrarMensaje('Debes adjuntar tu documento.');
        return;
      }

      final archivo = archivoSeleccionado!;
      final extension = archivo.extension!.toLowerCase();

      final nombreArchivo =
          'documento_${DateTime.now().microsecondsSinceEpoch}.$extension';

      rutaArchivoNuevo = '${usuario.id}/$periodoId/$nombreArchivo';

      final tipoContenido = extension == 'pdf'
          ? 'application/pdf'
          : extension == 'png'
              ? 'image/png'
              : 'image/jpeg';

      // El archivo se sube solamente al pulsar el botón de envío.
      await supabase.storage
          .from('documentos-ipn')
          .uploadBinary(
            rutaArchivoNuevo,
            await archivo.readAsBytes(),
            fileOptions: FileOptions(
              contentType: tipoContenido,
              upsert: false,
            ),
          );

      archivoSubido = true;

      final datos = {
        'estudiante_id': usuario.id,
        'periodo_id': periodoId,
        'categoria_solicitada': 'Comunidad IPN',
        'categoria_aplicada': 'Público general',
        'estado': 'Pendiente',
        'documento_path': rutaArchivoNuevo,
        'tipo_documento': tipoDocumento,
        'observaciones': null,
        'verificado_por': null,
        'fecha_verificacion': null,
      };

      if (existente != null) {
        // Actualiza la misma fila rechazada. No crea otra verificación.
        final respuesta = await supabase
            .from('verificaciones_ipn_periodo')
            .update(datos)
            .eq('id', existente['id'])
            .select('id, estado, documento_path')
            .maybeSingle();

        if (respuesta == null ||
            respuesta['estado'] != 'Pendiente' ||
            respuesta['documento_path'] != rutaArchivoNuevo) {
          throw Exception(
            'Supabase no confirmó la actualización. '
            'Verifica que hayas creado la política UPDATE.',
          );
        }

        debugPrint(
          'Verificación rechazada actualizada. '
          'Se conservó el ID: ${respuesta['id']}',
        );
      } else {
        // Primera solicitud de Comunidad IPN.
        // No enviar id: Supabase lo genera automáticamente.
        final respuesta = await supabase
            .from('verificaciones_ipn_periodo')
            .insert(datos)
            .select('id')
            .single();

        debugPrint(
          'Verificación IPN registrada. '
          'ID generado por Supabase: ${respuesta['id']}',
        );
      }

      registroGuardado = true;
      archivoSubido = false;

      if (!mounted) return;

      setState(() {
        archivoSeleccionado = null;
        tamanoArchivo = null;
      });

      await cargarInformacion();

      if (!mounted) return;

      mostrarMensaje(
        existente != null
            ? 'Tu documento fue reenviado. Está pendiente de revisión.'
            : 'Tu documento fue enviado. Espera la revisión del coordinador.',
      );
    } catch (error) {
      // Si el archivo se subió pero no se guardó la fila,
      // eliminamos únicamente ese archivo nuevo.
      if (archivoSubido &&
          !registroGuardado &&
          rutaArchivoNuevo != null) {
        try {
          await supabase.storage
              .from('documentos-ipn')
              .remove([rutaArchivoNuevo]);
        } catch (errorStorage) {
          debugPrint(
            'No se pudo eliminar el archivo temporal: $errorStorage',
          );
        }
      }

      if (mounted) {
        mostrarMensaje('No se pudo enviar la verificación: $error');
      }
    } finally {
      if (mounted) {
        setState(() {
          enviando = false;
        });
      }
    }
  }

  void mostrarMensaje(String mensaje) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  String textoEstado(String estado) {
    switch (estado) {
      case 'Pendiente':
        return 'Tu documento está pendiente de revisión. '
            'No puedes realizar el pago hasta que sea revisado.';
      case 'Verificada':
        return 'Tu pertenencia a Comunidad IPN fue verificada.';
      case 'Rechazada':
        return 'Tu documento fue rechazado. Puedes reenviarlo '
            'o cambiar voluntariamente a Público general.';
      case 'No aplica':
        return 'Tu categoría es Público general.';
      default:
        return estado;
    }
  }

  @override
  Widget build(BuildContext context) {
    final estado =
        verificacionExistente?['estado']?.toString() ?? '';

    final mostrarFormulario =
        verificacionExistente == null || estado == 'Rechazada';

    return Scaffold(
      backgroundColor: fondo,
      appBar: AppBar(
        title: const Text(
          'Verificación IPN',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: azul,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : periodoId == null
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Actualmente no hay un periodo disponible '
                      'para registrar tu categoría.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : mostrarFormulario
                  ? construirFormulario(estado)
                  : construirEstado(),
    );
  }

  // Muestra el estado cuando no se necesita mostrar el formulario.
  Widget construirEstado() {
    final verificacion = verificacionExistente!;
    final estado = verificacion['estado']?.toString() ?? '';

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Icon(
                  estado == 'Verificada'
                      ? Icons.verified
                      : estado == 'No aplica'
                          ? Icons.person
                          : Icons.hourglass_top,
                  color: azul,
                  size: 55,
                ),
                const SizedBox(height: 15),
                const Text(
                  'Tu verificación está registrada',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text('Periodo: ${nombrePeriodo ?? ''}'),
                const SizedBox(height: 8),
                Text(
                  'Categoría: ${verificacion['categoria_solicitada']}',
                ),
                const SizedBox(height: 8),
                Text(
                  'Estado: $estado',
                  style: TextStyle(
                    color: azul,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  textoEstado(estado),
                  textAlign: TextAlign.center,
                ),
                if (verificacion['observaciones'] != null &&
                    verificacion['observaciones'].toString().isNotEmpty) ...[
                  const SizedBox(height: 15),
                  const Text(
                    'Observaciones del coordinador:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    verificacion['observaciones'].toString(),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: cargando
                      ? null
                      : () async {
                          setState(() {
                            cargando = true;
                          });
                          await cargarInformacion();
                        },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Actualizar estado'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Formulario para solicitudes nuevas o verificaciones rechazadas.
  Widget construirFormulario(String estado) {
    final fueRechazada = estado == 'Rechazada';
    final esPublico = categoria == 'Público general';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Selecciona tu categoría',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text('Periodo: ${nombrePeriodo ?? ''}'),

              if (fueRechazada) ...[
                const SizedBox(height: 15),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Tu documento fue rechazado. Puedes adjuntar uno nuevo '
                    'o cambiar voluntariamente a Público general.',
                    style: TextStyle(color: Colors.orange.shade900),
                  ),
                ),
                if (verificacionExistente?['observaciones'] != null &&
                    verificacionExistente!['observaciones']
                        .toString()
                        .isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Observaciones del coordinador:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 5),
                  Text(verificacionExistente!['observaciones'].toString()),
                ],
              ],

              const SizedBox(height: 18),

              DropdownButtonFormField<String>(
                key: ValueKey(categoria),
                initialValue: categoria,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Categoría',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'Comunidad IPN',
                    child: Text('Comunidad IPN'),
                  ),
                  DropdownMenuItem(
                    value: 'Público general',
                    child: Text('Público general'),
                  ),
                ],
                onChanged: enviando ||
                        (verificacionExistente != null && !fueRechazada)
                    ? null
                    : (valor) {
                        if (valor == null) return;

                        setState(() {
                          categoria = valor;
                          archivoSeleccionado = null;
                          tamanoArchivo = null;
                          tipoDocumento = 'PDF de credencial';
                        });
                      },
              ),

              const SizedBox(height: 20),

              if (!esPublico) ...[
                const Text(
                  'Documento para comprobar tu pertenencia al IPN',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Puedes adjuntar una fotografía de tu credencial, '
                  'un PDF de tu credencial o un PDF de tu horario vigente.',
                ),
                const SizedBox(height: 15),
                OutlinedButton.icon(
                  onPressed: enviando ? null : seleccionarArchivo,
                  icon: const Icon(Icons.attach_file),
                  label: const Text('Seleccionar documento'),
                ),
                if (archivoSeleccionado != null) ...[
                  const SizedBox(height: 10),
                  ListTile(
                    leading: Icon(Icons.insert_drive_file, color: azul),
                    title: Text(
                      archivoSeleccionado!.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${((tamanoArchivo ?? 0) / 1024).toStringAsFixed(1)} KB',
                    ),
                  ),
                ],
                if (archivoSeleccionado?.extension?.toLowerCase() == 'pdf') ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: ValueKey('tipo-$tipoDocumento'),
                    initialValue: tipoDocumento,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de documento PDF',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'PDF de credencial',
                        child: Text('PDF de credencial'),
                      ),
                      DropdownMenuItem(
                        value: 'PDF de horario',
                        child: Text('PDF de horario'),
                      ),
                    ],
                    onChanged: enviando
                        ? null
                        : (valor) {
                            if (valor != null) {
                              setState(() {
                                tipoDocumento = valor;
                              });
                            }
                          },
                  ),
                ],
                const SizedBox(height: 12),
                const Text(
                  'Formato permitido: JPG, PNG o PDF. Tamaño máximo: 5 MB.',
                  style: TextStyle(fontSize: 12),
                ),
              ] else ...[
                const Text(
                  'Al confirmar, tu categoría cambiará a Público general. '
                  'No necesitarás adjuntar documentos. Solo el costo cambia',
                ),
              ],

              const SizedBox(height: 25),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: enviando ? null : enviarVerificacion,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: azul,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: enviando
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          esPublico
                              ? 'Cambiar a Público general'
                              : fueRechazada
                                  ? 'Reenviar documento'
                                  : 'Enviar información',
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
