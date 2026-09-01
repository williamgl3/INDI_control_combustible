import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth_controller.dart';
import '../../core/validators.dart';
import '../../data/auth_repository.dart';
import '../../router/route_paths.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_elevated_button.dart';
import '../../widgets/auth_screen_shell.dart';
import '../../widgets/aviso_error.dart';

/// Flujo de "¿Olvidaste tu contraseña?": captura → confirmación.
///
/// Funcional en frontend usando [MockAuthRepository.recuperarPassword].
/// Cuando el backend esté listo, solo se reemplaza esa función mock por
/// la llamada real.
class RecuperarPasswordScreen extends ConsumerStatefulWidget {
  const RecuperarPasswordScreen({super.key});

  @override
  ConsumerState<RecuperarPasswordScreen> createState() =>
      _RecuperarPasswordScreenState();
}

class _RecuperarPasswordScreenState
    extends ConsumerState<RecuperarPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usuarioOCorreoController = TextEditingController();

  bool _cargando = false;
  bool _enviado = false;
  String? _errorGeneral;

  @override
  void dispose() {
    _usuarioOCorreoController.dispose();
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
          .recuperarPassword(
            usuarioOCorreo: _usuarioOCorreoController.text.trim(),
          );
      setState(() => _enviado = true);
    } on AuthException catch (e) {
      setState(() => _errorGeneral = e.mensaje);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScreenShell(
      onBack: () => context.go(RoutePaths.login),
      titulo: 'Recuperar contraseña',
      subtitulo:
          'Ingresa tu usuario o correo y te enviaremos instrucciones '
          'para restablecer tu contraseña.',
      mostrarMarca: false,
      centrarContenido: false,
      child: _enviado ? _buildConfirmacion(context) : _buildFormulario(context),
    );
  }

  Widget _buildFormulario(BuildContext context) {
    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _usuarioOCorreoController,
            decoration: const InputDecoration(
              labelText: 'Usuario o correo',
              prefixIcon: Icon(Icons.person_outline),
            ),
            validator: (v) => Validators.requerido(v, etiqueta: 'Este campo'),
            onFieldSubmitted: (_) => _enviar(),
          ),
          if (_errorGeneral != null) ...[
            const SizedBox(height: 12),
            AvisoError(mensaje: _errorGeneral!),
          ],
          const SizedBox(height: 24),
          AppElevatedButton(
            onPressed: _enviar,
            cargando: _cargando,
            child: const Text('Enviar instrucciones'),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmacion(BuildContext context) {
    final colors = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.mark_email_read_outlined, size: 48, color: colors.success),
        const SizedBox(height: 16),
        Text(
          'Si la cuenta existe, enviamos instrucciones para restablecer '
          'tu contraseña.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () => context.go(RoutePaths.login),
          child: const Text('Volver a iniciar sesión'),
        ),
      ],
    );
  }
}
