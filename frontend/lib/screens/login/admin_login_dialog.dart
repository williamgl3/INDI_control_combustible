import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth_controller.dart';
import '../../core/validators.dart';
import '../../data/mock_auth_repository.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_theme.dart';

/// Modal de "Acceso de administrador": la cuenta de administrador es
/// ÚNICA y la crea el equipo (no hay registro de administrativos), por
/// eso vive separada del login general de chofer en su propio diálogo.
class AdminLoginDialog extends ConsumerStatefulWidget {
  const AdminLoginDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
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
      await ref.read(authControllerProvider).login(
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

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: AppRadii.cardRadius),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(AppRadii.card),
                    topRight: Radius.circular(AppRadii.card),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: colors.primaryOn.withValues(alpha: 0.15),
                      child: Icon(Icons.admin_panel_settings, color: colors.primaryOn),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Acceso de administrador',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(color: colors.primaryOn),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('USUARIO', style: Theme.of(context).textTheme.labelMedium),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _usuarioController,
                      decoration:
                          const InputDecoration(hintText: 'Usuario del administrador'),
                      validator: Validators.usuario,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Text('CONTRASEÑA', style: Theme.of(context).textTheme.labelMedium),
                        const Spacer(),
                        TextButton(
                          onPressed: () =>
                              setState(() => _passwordVisible = !_passwordVisible),
                          child: Text(_passwordVisible ? 'Ocultar' : 'Ver'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    TextFormField(
                      controller: _passwordController,
                      decoration: const InputDecoration(hintText: '••••••••'),
                      obscureText: !_passwordVisible,
                      validator: Validators.password,
                      onFieldSubmitted: (_) => _enviar(),
                    ),
                    if (_errorGeneral != null) ...[
                      const SizedBox(height: 12),
                      Text(_errorGeneral!, style: TextStyle(color: colors.error)),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed:
                                _cargando ? null : () => Navigator.of(context).pop(),
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
            ],
          ),
        ),
      ),
    );
  }
}
