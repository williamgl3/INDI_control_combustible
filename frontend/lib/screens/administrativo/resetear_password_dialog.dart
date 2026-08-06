import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/validators.dart';
import '../../data/auth_repository.dart';
import '../../models/perfil.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_dialog.dart';

/// Modal para que un administrativo restablezca la contraseña de otro
/// usuario (chofer o administrativo) — distinto de "Cambiar contraseña"
/// de Mi Perfil, que es para la propia sesión y pide la contraseña
/// actual; aquí, al ser una acción de un administrativo sobre otra
/// cuenta, no se pide la contraseña anterior.
class ResetearPasswordDialog extends ConsumerStatefulWidget {
  const ResetearPasswordDialog({super.key, required this.usuario});

  final Perfil usuario;

  static Future<bool?> show(BuildContext context, {required Perfil usuario}) {
    return mostrarDialogoApp<bool>(
      context,
      builder: (_) => ResetearPasswordDialog(usuario: usuario),
    );
  }

  @override
  ConsumerState<ResetearPasswordDialog> createState() =>
      _ResetearPasswordDialogState();
}

class _ResetearPasswordDialogState
    extends ConsumerState<ResetearPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmarController = TextEditingController();
  bool _cargando = false;
  String? _errorGeneral;
  bool _passwordVisible = false;
  bool _confirmarVisible = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmarController.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _cargando = true;
      _errorGeneral = null;
    });

    try {
      await ref
          .read(authRepositoryProvider)
          .resetearPassword(
            usuarioId: widget.usuario.id,
            passwordNueva: _passwordController.text,
          );
      HapticFeedback.mediumImpact();
      if (mounted) Navigator.of(context).pop(true);
    } on AuthException catch (e) {
      if (mounted) setState(() => _errorGeneral = e.mensaje);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AppDialogShell(
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Resetear contraseña',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              widget.usuario.nombreCompleto,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _passwordController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Contraseña nueva',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: Semantics(
                  label: _passwordVisible
                      ? 'Ocultar contraseña'
                      : 'Mostrar contraseña',
                  button: true,
                  child: IconButton(
                    icon: Icon(
                      _passwordVisible
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                    tooltip: _passwordVisible ? 'Ocultar' : 'Ver',
                    onPressed: () =>
                        setState(() => _passwordVisible = !_passwordVisible),
                  ),
                ),
              ),
              obscureText: !_passwordVisible,
              validator: Validators.password,
              onFieldSubmitted: (_) => _guardar(),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _confirmarController,
              decoration: InputDecoration(
                labelText: 'Confirmar contraseña nueva',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: Semantics(
                  label: _confirmarVisible
                      ? 'Ocultar confirmación de contraseña'
                      : 'Mostrar confirmación de contraseña',
                  button: true,
                  child: IconButton(
                    icon: Icon(
                      _confirmarVisible
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                    tooltip: _confirmarVisible ? 'Ocultar' : 'Ver',
                    onPressed: () => setState(
                      () => _confirmarVisible = !_confirmarVisible,
                    ),
                  ),
                ),
              ),
              obscureText: !_confirmarVisible,
              validator: (v) => Validators.confirmarPassword(
                v,
                _passwordController.text,
              ),
              onFieldSubmitted: (_) => _guardar(),
            ),
            if (_errorGeneral != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorGeneral!,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.error),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _cargando
                        ? null
                        : () => Navigator.of(context).pop(false),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _cargando ? null : _guardar,
                    child: _cargando
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Guardar'),
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
