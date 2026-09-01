import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth_controller.dart';
import '../../core/validators.dart';
import '../../data/auth_repository.dart';
import '../../router/route_paths.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_elevated_button.dart';
import '../../widgets/auth_screen_shell.dart';
import '../../widgets/aviso_error.dart';

class RestablecerPasswordScreen extends ConsumerStatefulWidget {
  const RestablecerPasswordScreen({super.key, required this.token});

  final String token;

  @override
  ConsumerState<RestablecerPasswordScreen> createState() =>
      _RestablecerPasswordScreenState();
}

class _RestablecerPasswordScreenState
    extends ConsumerState<RestablecerPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirmacion = TextEditingController();
  bool _ocultarPassword = true;
  bool _ocultarConfirmacion = true;
  bool _cargando = false;
  bool _completado = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirmacion.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (widget.token.isEmpty || !_formKey.currentState!.validate()) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await ref
          .read(authControllerProvider)
          .restablecerPassword(
            token: widget.token,
            passwordNueva: _password.text,
          );
      if (mounted) setState(() => _completado = true);
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScreenShell(
      onBack: () => context.go(RoutePaths.login),
      titulo: 'Nueva contraseña',
      subtitulo: 'Crea una contraseña nueva para volver a ingresar.',
      mostrarMarca: false,
      centrarContenido: false,
      child: _completado ? _confirmacionExitosa(context) : _formulario(),
    );
  }

  Widget _formulario() {
    if (widget.token.isEmpty) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AvisoError(
            mensaje:
                'El enlace de recuperación está incompleto o ya no es válido.',
          ),
          const SizedBox(height: AppSpacing.xl),
          OutlinedButton(
            onPressed: () => context.go(RoutePaths.recuperarPassword),
            child: const Text('Solicitar otro enlace'),
          ),
        ],
      );
    }
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _password,
            obscureText: _ocultarPassword,
            autofillHints: const [AutofillHints.newPassword],
            decoration: InputDecoration(
              labelText: 'Nueva contraseña',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                onPressed: () =>
                    setState(() => _ocultarPassword = !_ocultarPassword),
                icon: Icon(
                  _ocultarPassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
            validator: Validators.password,
          ),
          const SizedBox(height: AppSpacing.lg),
          TextFormField(
            controller: _confirmacion,
            obscureText: _ocultarConfirmacion,
            autofillHints: const [AutofillHints.newPassword],
            decoration: InputDecoration(
              labelText: 'Confirmar contraseña',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                onPressed: () => setState(
                  () => _ocultarConfirmacion = !_ocultarConfirmacion,
                ),
                icon: Icon(
                  _ocultarConfirmacion
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
            validator: (value) =>
                Validators.confirmarPassword(value, _password.text),
            onFieldSubmitted: (_) => _guardar(),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            AvisoError(mensaje: _error!),
          ],
          const SizedBox(height: AppSpacing.xxl),
          AppElevatedButton(
            onPressed: _guardar,
            cargando: _cargando,
            child: const Text('Guardar nueva contraseña'),
          ),
        ],
      ),
    );
  }

  Widget _confirmacionExitosa(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.check_circle_outline,
          size: 48,
          color: context.colors.success,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Tu contraseña se actualizó. Ya puedes iniciar sesión.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.xxl),
        ElevatedButton(
          onPressed: () => context.go(RoutePaths.login),
          child: const Text('Iniciar sesión'),
        ),
      ],
    );
  }
}
