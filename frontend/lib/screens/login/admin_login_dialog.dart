import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth_controller.dart';
import '../../core/validators.dart';
import '../../data/auth_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/logo_glass.dart';

/// Modal de "Acceso de administrador": la cuenta de administrador es
/// ÚNICA y la crea el equipo (no hay registro de administrativos), por
/// eso vive separada del login general de chofer en su propio diálogo.
class AdminLoginDialog extends ConsumerStatefulWidget {
  const AdminLoginDialog({super.key});

  static Future<void> show(BuildContext context) {
    return mostrarDialogoApp<void>(
      context,
      builder: (_) => const AdminLoginDialog(),
    );
  }

  @override
  ConsumerState<AdminLoginDialog> createState() => _AdminLoginDialogState();
}

class _AdminLoginDialogState extends ConsumerState<AdminLoginDialog> {
  final _formKey = GlobalKey<FormState>();
  final _usuarioController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _passwordVisible = false;
  bool _cargando = false;
  String? _errorGeneral;

  @override
  void dispose() {
    _usuarioController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _cargando = true;
      _errorGeneral = null;
    });

    try {
      await ref
          .read(authControllerProvider)
          .login(
            usuario: _usuarioController.text.trim(),
            password: _passwordController.text,
          );
      if (mounted) Navigator.of(context).pop();
      // El guard de rutas redirige automáticamente a /administrativo.
    } on AuthException catch (e) {
      setState(() => _errorGeneral = e.mensaje);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AppDialogShell(
      header: Container(
        padding: const EdgeInsets.all(20),
        color: colors.sidebarBackground,
        child: Row(
          children: [
            const IndiLogo(width: 32),
            const SizedBox(width: 8),
            Icon(Icons.shield_outlined, color: colors.sidebarText, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Acceso de administrador',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(color: colors.sidebarText),
              ),
            ),
          ],
        ),
      ),
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _usuarioController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Usuario del administrador',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: Validators.usuario,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: 'Contraseña',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
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
              obscureText: !_passwordVisible,
              validator: Validators.password,
              onFieldSubmitted: (_) => _enviar(),
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
                        : () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _cargando ? null : _enviar,
                    child: _cargando
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Ingresar'),
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
