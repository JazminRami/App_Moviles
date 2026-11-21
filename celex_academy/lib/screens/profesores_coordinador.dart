
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Colores institucionales.
const Color azulProfesores = Color(0xFF023C87);
const Color fondoProfesores = Color(0xFFEAF1FB);

class ProfesoresCoordinador extends StatefulWidget {
  const ProfesoresCoordinador({super.key});

  @override
  State<ProfesoresCoordinador> createState() =>
      _ProfesoresCoordinadorState();
}

class _ProfesoresCoordinadorState extends State<ProfesoresCoordinador> {
  final supabase = Supabase.instance.client;

  bool cargando = true;
  bool guardando = false;

  List<Map<String, dynamic>> profesores = [];

  @override
  void initState() {
    super.initState();
    consultarProfesores();
  }

  // Consultar todos los profesores, activos e inactivos.
  Future<void> consultarProfesores() async {
    setState(() {
      cargando = true;
    });

    try {
      final respuesta = await supabase
          .from('profesores')
          .select(
            'id, nombre_completo, correo, telefono, activo, fecha_registro',
          )
          .order('nombre_completo');

      if (!mounted) return;

      setState(() {
        profesores = List<Map<String, dynamic>>.from(respuesta);
        cargando = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        cargando = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al consultar profesores: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Formulario para registrar o editar profesores.
  Future<void> mostrarFormulario({
    Map<String, dynamic>? profesor,
  }) async {
    final bool editando = profesor != null;

    final nombreController = TextEditingController(
      text: profesor?['nombre_completo']?.toString() ?? '',
    );

    final correoController = TextEditingController(
      text: profesor?['correo']?.toString() ?? '',
    );

    final telefonoController = TextEditingController(
      text: profesor?['telefono']?.toString() ?? '',
    );

    final formKey = GlobalKey<FormState>();

    final resultado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            editando ? 'Editar profesor' : 'Registrar profesor',
            style: const TextStyle(
              color: azulProfesores,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nombreController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nombre completo *',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                    validator: (valor) {
                      if (valor == null || valor.trim().isEmpty) {
                        return 'Ingresa el nombre completo.';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 14),

                  TextFormField(
                    controller: correoController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Correo electrónico',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (valor) {
                      final correo = valor?.trim() ?? '';

                      if (correo.isNotEmpty &&
                          !RegExp(
                            r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                          ).hasMatch(correo)) {
                        return 'Ingresa un correo válido.';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 14),

                  TextFormField(
                    controller: telefonoController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Teléfono',
                      prefixIcon: Icon(Icons.phone_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
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
                backgroundColor: azulProfesores,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(dialogContext, true);
                }
              },
              child: Text(editando ? 'Guardar' : 'Registrar'),
            ),
          ],
        );
      },
    );

    if (resultado == true) {
      await guardarProfesor(
        profesor: profesor,
        nombre: nombreController.text.trim(),
        correo: correoController.text.trim(),
        telefono: telefonoController.text.trim(),
      );
    }

    nombreController.dispose();
    correoController.dispose();
    telefonoController.dispose();
  }

  // Insertar un profesor nuevo o actualizar sus datos.
  Future<void> guardarProfesor({
    Map<String, dynamic>? profesor,
    required String nombre,
    required String correo,
    required String telefono,
  }) async {
    if (guardando) return;

    setState(() {
      guardando = true;
    });

    try {
      final datos = {
        'nombre_completo': nombre,
        'correo': correo.isEmpty ? null : correo,
        'telefono': telefono.isEmpty ? null : telefono,
      };

      if (profesor == null) {
        // El ID se genera automáticamente.
        await supabase.from('profesores').insert(datos);
      } else {
        await supabase
            .from('profesores')
            .update(datos)
            .eq('id', profesor['id']);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            profesor == null
                ? 'Profesor registrado correctamente.'
                : 'Datos del profesor actualizados.',
          ),
          backgroundColor: Colors.green,
        ),
      );

      await consultarProfesores();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar profesor: $error'),
          backgroundColor: Colors.red,
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

  // Activar o desactivar un profesor.
  Future<void> cambiarEstado(
    Map<String, dynamic> profesor,
  ) async {
    final bool activo = profesor['activo'] == true;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            activo ? 'Desactivar profesor' : 'Activar profesor',
          ),
          content: Text(
            activo
                ? '¿Deseas desactivar a ${profesor['nombre_completo']}? '
                    'Ya no aparecerá como opción para nuevos grupos.'
                : '¿Deseas activar a ${profesor['nombre_completo']}? '
                    'Volverá a estar disponible para asignaciones.',
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
                backgroundColor: azulProfesores,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Confirmar'),
            ),
          ],
        );
      },
    );

    if (confirmar != true) return;

    try {
      await supabase
          .from('profesores')
          .update({'activo': !activo})
          .eq('id', profesor['id']);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            activo
                ? 'Profesor desactivado.'
                : 'Profesor activado.',
          ),
          backgroundColor: Colors.green,
        ),
      );

      await consultarProfesores();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cambiar el estado: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Construir la tarjeta de cada profesor.
  Widget tarjetaProfesor(Map<String, dynamic> profesor) {
    final bool activo = profesor['activo'] == true;

    final correo = profesor['correo']?.toString() ?? '';
    final telefono = profesor['telefono']?.toString() ?? '';

    return Card(
      color: Colors.white,
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 13),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(13),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: fondoProfesores,
                  child: Icon(
                    Icons.person,
                    color: activo ? azulProfesores : Colors.grey,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    profesor['nombre_completo'].toString(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: azulProfesores,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Opciones',
                  onSelected: (opcion) {
                    if (opcion == 'editar') {
                      mostrarFormulario(profesor: profesor);
                    } else if (opcion == 'estado') {
                      cambiarEstado(profesor);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'editar',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined),
                          SizedBox(width: 10),
                          Text('Editar datos'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'estado',
                      child: Row(
                        children: [
                          Icon(
                            activo
                                ? Icons.person_off_outlined
                                : Icons.person_outline,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            activo ? 'Desactivar' : 'Activar',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),

            if (correo.isNotEmpty)
              _dato(Icons.email_outlined, correo),

            if (telefono.isNotEmpty) ...[
              const SizedBox(height: 7),
              _dato(Icons.phone_outlined, telefono),
            ],

            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: activo
                    ? Colors.green.withValues(alpha: 0.12)
                    : Colors.grey.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                activo ? 'Activo' : 'Inactivo',
                style: TextStyle(
                  color: activo ? Colors.green : Colors.grey,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Fila de información.
  Widget _dato(IconData icono, String texto) {
    return Row(
      children: [
        Icon(
          icono,
          size: 18,
          color: azulProfesores,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            texto,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black54,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final activos = profesores
        .where((p) => p['activo'] == true)
        .length;

    final inactivos = profesores.length - activos;

    return Scaffold(
      backgroundColor: fondoProfesores,
      appBar: AppBar(
        title: const Text('Profesores'),
        backgroundColor: azulProfesores,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh),
            onPressed: consultarProfesores,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: guardando ? null : () => mostrarFormulario(),
        backgroundColor: azulProfesores,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Agregar profesor'),
      ),
      body: cargando
          ? const Center(
              child: CircularProgressIndicator(
                color: azulProfesores,
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _resumen(
                          'Total',
                          profesores.length,
                          Icons.groups_outlined,
                          azulProfesores,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _resumen(
                          'Activos',
                          activos,
                          Icons.check_circle_outline,
                          Colors.green,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _resumen(
                          'Inactivos',
                          inactivos,
                          Icons.person_off_outlined,
                          Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: profesores.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(25),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.people_outline,
                                  size: 65,
                                  color: Colors.black38,
                                ),
                                const SizedBox(height: 15),
                                const Text(
                                  'Todavía no hay profesores registrados.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: azulProfesores,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Utiliza el botón para registrar '
                                  'al primer profesor.',
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
                          color: azulProfesores,
                          onRefresh: consultarProfesores,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(
                              16,
                              0,
                              16,
                              90,
                            ),
                            itemCount: profesores.length,
                            itemBuilder: (context, index) {
                              return tarjetaProfesor(
                                profesores[index],
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  // Tarjeta pequeña de resumen.
  Widget _resumen(
    String titulo,
    int cantidad,
    IconData icono,
    Color color,
  ) {
    return Card(
      color: Colors.white,
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 13,
          horizontal: 5,
        ),
        child: Column(
          children: [
            Icon(icono, color: color, size: 24),
            const SizedBox(height: 5),
            Text(
              cantidad.toString(),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              titulo,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
