import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/auth_repository.dart';
import '../../models/perfil.dart';
import '../../widgets/app_dialog.dart';

Future<String?> solicitarMotivo(
  BuildContext context, {
  required String titulo,
  required String mensaje,
  required String accion,
  bool destructivo = false,
}) {
  return mostrarDialogoApp<String>(
    context,
    builder: (_) => _MotivoDialog(
      titulo: titulo,
      mensaje: mensaje,
      accion: accion,
      destructivo: destructivo,
    ),
  );
}

class _MotivoDialog extends StatefulWidget {
  const _MotivoDialog({
    required this.titulo,
    required this.mensaje,
    required this.accion,
    required this.destructivo,
  });
  final String titulo, mensaje, accion;
  final bool destructivo;
  @override
  State<_MotivoDialog> createState() => _MotivoDialogState();
}

class _MotivoDialogState extends State<_MotivoDialog> {
  final form = GlobalKey<FormState>();
  final motivo = TextEditingController();
  @override
  void dispose() {
    motivo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppDialogShell(
    maxWidth: 440,
    child: Form(
      key: form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.titulo, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(widget.mensaje),
          const SizedBox(height: 16),
          TextFormField(
            controller: motivo,
            autofocus: true,
            minLines: 2,
            maxLines: 4,
            maxLength: 500,
            decoration: const InputDecoration(labelText: 'Motivo obligatorio'),
            validator: (v) => (v?.trim().length ?? 0) < 5
                ? 'Escribe al menos 5 caracteres.'
                : null,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    if (form.currentState!.validate()) {
                      Navigator.pop(context, motivo.text.trim());
                    }
                  },
                  style: widget.destructivo
                      ? ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.error,
                        )
                      : null,
                  child: Text(widget.accion),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class EditarChoferDialog extends ConsumerStatefulWidget {
  const EditarChoferDialog({super.key, required this.chofer});
  final Perfil chofer;
  static Future<Perfil?> show(BuildContext context, Perfil p) =>
      mostrarDialogoApp<Perfil>(
        context,
        barrierDismissible: false,
        builder: (_) => EditarChoferDialog(chofer: p),
      );
  @override
  ConsumerState<EditarChoferDialog> createState() => _EditarState();
}

class _EditarState extends ConsumerState<EditarChoferDialog> {
  final form = GlobalKey<FormState>();
  late final nombre = TextEditingController(text: widget.chofer.nombre),
      paterno = TextEditingController(text: widget.chofer.apellidoPaterno),
      materno = TextEditingController(text: widget.chofer.apellidoMaterno),
      correo = TextEditingController(text: widget.chofer.correo),
      usuario = TextEditingController(text: widget.chofer.usuario);
  bool cargando = false;
  String? error;
  bool get cambio =>
      nombre.text.trim() != widget.chofer.nombre ||
      paterno.text.trim() != (widget.chofer.apellidoPaterno ?? '') ||
      materno.text.trim() != (widget.chofer.apellidoMaterno ?? '') ||
      correo.text.trim() != widget.chofer.correo ||
      usuario.text.trim() != widget.chofer.usuario;
  @override
  void dispose() {
    for (final c in [nombre, paterno, materno, correo, usuario]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> guardar() async {
    if (cargando || !cambio || !form.currentState!.validate()) return;
    final cambios = <String, dynamic>{};
    void add(String k, String actual, String nuevo, {bool nullable = false}) {
      if (actual != nuevo) {
        cambios[k] = nullable && nuevo.isEmpty ? null : nuevo;
      }
    }

    add('nombre', widget.chofer.nombre, nombre.text.trim());
    add(
      'apellidoPaterno',
      widget.chofer.apellidoPaterno ?? '',
      paterno.text.trim(),
    );
    add(
      'apellidoMaterno',
      widget.chofer.apellidoMaterno ?? '',
      materno.text.trim(),
      nullable: true,
    );
    add('correo', widget.chofer.correo, correo.text.trim());
    add('usuario', widget.chofer.usuario, usuario.text.trim());
    setState(() => cargando = true);
    try {
      final p = await ref
          .read(authRepositoryProvider)
          .editarChofer(
            usuarioId: widget.chofer.id,
            version: widget.chofer.version,
            cambios: cambios,
          );
      if (mounted) Navigator.pop(context, p);
    } on AuthException catch (e) {
      if (mounted) setState(() => error = e.mensaje);
    } finally {
      if (mounted) setState(() => cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !cambio && !cargando,
    child: AppDialogShell(
      maxWidth: 520,
      child: Form(
        key: form,
        onChanged: () => setState(() {}),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Editar chofer',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              for (final f in [
                (nombre, 'Nombre', false),
                (paterno, 'Apellido paterno', false),
                (materno, 'Apellido materno', false),
                (correo, 'Correo', true),
                (usuario, 'Usuario', false),
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextFormField(
                    controller: f.$1,
                    decoration: InputDecoration(labelText: f.$2),
                    keyboardType: f.$3 ? TextInputType.emailAddress : null,
                    validator: (v) {
                      final x = v?.trim() ?? '';
                      if (f.$1 != materno && x.length < 2) {
                        return 'Campo obligatorio.';
                      }
                      if (f.$1 == correo &&
                          !RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(x)) {
                        return 'Correo inválido.';
                      }
                      if (f.$1 == usuario &&
                          !RegExp(r'^[a-zA-Z0-9._]{3,30}$').hasMatch(x)) {
                        return 'Usuario inválido.';
                      }
                      return null;
                    },
                  ),
                ),
              if (error != null)
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: cargando ? null : () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: cargando || !cambio ? null : guardar,
                      child: cargando
                          ? const CircularProgressIndicator()
                          : const Text('Guardar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class EliminarChoferDialog extends ConsumerStatefulWidget {
  const EliminarChoferDialog({super.key, required this.chofer});
  final Perfil chofer;
  static Future<bool?> show(BuildContext c, Perfil p) =>
      mostrarDialogoApp<bool>(
        c,
        barrierDismissible: false,
        builder: (_) => EliminarChoferDialog(chofer: p),
      );
  @override
  ConsumerState<EliminarChoferDialog> createState() => _EliminarState();
}

class _EliminarState extends ConsumerState<EliminarChoferDialog> {
  final form = GlobalKey<FormState>(),
      confirmacion = TextEditingController(),
      motivo = TextEditingController();
  bool cargando = false;
  String? error;
  @override
  void dispose() {
    confirmacion.dispose();
    motivo.dispose();
    super.dispose();
  }

  Future<void> eliminar() async {
    if (cargando || !form.currentState!.validate()) return;
    setState(() => cargando = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .eliminarChofer(
            usuarioId: widget.chofer.id,
            usuarioConfirmado: confirmacion.text.trim(),
            motivo: motivo.text.trim(),
          );
      if (mounted) Navigator.pop(context, true);
    } on AuthException catch (e) {
      if (mounted) setState(() => error = e.mensaje);
    } finally {
      if (mounted) setState(() => cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppDialogShell(
    maxWidth: 480,
    child: Form(
      key: form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Eliminar definitivamente',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Esta cuenta no tiene actividad relacionada. La eliminación es permanente y no se puede deshacer.',
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: confirmacion,
            decoration: InputDecoration(
              labelText: 'Escribe @${widget.chofer.usuario}',
            ),
            validator: (v) => v?.trim() == '@${widget.chofer.usuario}'
                ? null
                : 'La confirmación no coincide.',
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: motivo,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Motivo'),
            validator: (v) => (v?.trim().length ?? 0) < 5
                ? 'Escribe al menos 5 caracteres.'
                : null,
          ),
          if (error != null)
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: cargando
                      ? null
                      : () => Navigator.pop(context, false),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                  onPressed: cargando ? null : eliminar,
                  child: cargando
                      ? const CircularProgressIndicator()
                      : const Text('Eliminar permanentemente'),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

Future<void> mostrarActividadChofer(
  BuildContext context,
  DetalleChofer detalle,
) => mostrarDialogoApp<void>(
  context,
  builder: (_) => AppDialogShell(
    maxWidth: 480,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Actividad de ${detalle.chofer.nombreCompleto}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        for (final x in [
          ('Solicitudes', detalle.actividad.solicitudes),
          ('Cargas', detalle.actividad.cargas),
          ('Evidencias', detalle.actividad.evidencias),
          ('Incidencias', detalle.actividad.incidencias),
          ('Cierres', detalle.actividad.cierres),
          ('Recorridos', detalle.actividad.recorridos),
          ('Despachos', detalle.actividad.despachos),
        ])
          ListTile(dense: true, title: Text(x.$1), trailing: Text('${x.$2}')),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ),
      ],
    ),
  ),
);
