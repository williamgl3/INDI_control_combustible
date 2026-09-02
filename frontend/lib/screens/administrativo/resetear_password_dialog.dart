import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/auth_repository.dart';
import '../../models/perfil.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_dialog.dart';

/// Registra una solicitud administrativa de recuperación. No permite al
/// administrador conocer ni reemplazar la contraseña del chofer.
class ResetearPasswordDialog extends ConsumerStatefulWidget {
  const ResetearPasswordDialog({super.key, required this.usuario});
  final Perfil usuario;

  static Future<bool?> show(BuildContext context, {required Perfil usuario}) =>
      mostrarDialogoApp<bool>(
        context,
        builder: (_) => ResetearPasswordDialog(usuario: usuario),
      );

  @override
  ConsumerState<ResetearPasswordDialog> createState() => _State();
}

class _State extends ConsumerState<ResetearPasswordDialog> {
  final _form = GlobalKey<FormState>();
  final _motivo = TextEditingController();
  bool _cargando = false;
  String? _error;

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (_cargando || !_form.currentState!.validate()) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .resetearPassword(
            usuarioId: widget.usuario.id,
            motivo: _motivo.text.trim(),
          );
      HapticFeedback.mediumImpact();
      if (mounted) Navigator.of(context).pop(true);
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppDialogShell(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Solicitar restablecimiento',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'No podrás ver la contraseña actual ni establecer una nueva. La solicitud quedará auditada. El envío automático todavía no está configurado.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _motivo,
              autofocus: true,
              maxLength: 500,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Motivo',
                prefixIcon: Icon(Icons.notes),
              ),
              validator: (v) => (v?.trim().length ?? 0) < 5
                  ? 'Escribe un motivo de al menos 5 caracteres.'
                  : null,
            ),
            if (_error != null)
              Text(_error!, style: TextStyle(color: colors.error)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _cargando
                        ? null
                        : () => Navigator.pop(context, false),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _cargando ? null : _enviar,
                    child: _cargando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Registrar solicitud'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
