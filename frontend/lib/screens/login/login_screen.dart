import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth_controller.dart';
import '../../core/validators.dart';
import '../../data/auth_repository.dart';
import '../../router/route_paths.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_elevated_button.dart';
import '../../widgets/auth_screen_shell.dart';
import '../../widgets/aviso_error.dart';
import 'admin_login_dialog.dart';

/// Login de chofer (flujo principal). El acceso de administrador vive en
/// [AdminLoginDialog]: hay una única cuenta de administrador, creada por
/// el equipo, así que no comparte formulario con el registro de choferes.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usuarioController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocusNode = FocusNode();

  bool _passwordVisible = false;
  bool _cargando = false;
  String? _errorGeneral;

  @override
  void dispose() {
    _usuarioController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
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
      // El guard de rutas redirige automáticamente al detectar la sesión.
    } on AuthException catch (e) {
      setState(() => _errorGeneral = e.mensaje);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AuthScreenShell(
      subtitulo: null,
      centrarContenido: false,
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Iniciar sesión',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _usuarioController,
                decoration: const InputDecoration(
                  labelText: 'Usuario',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                autofillHints: const [AutofillHints.username],
                validator: Validators.usuario,
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) => _passwordFocusNode.requestFocus(),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _passwordController,
                focusNode: _passwordFocusNode,
                decoration: InputDecoration(
                  labelText: 'Contraseña',
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
                autofillHints: const [AutofillHints.password],
                obscureText: !_passwordVisible,
                validator: Validators.password,
                onFieldSubmitted: (_) => _enviar(),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => context.go(RoutePaths.recuperarPassword),
                  child: const Text('¿Olvidaste tu contraseña?'),
                ),
              ),
              if (_errorGeneral != null) ...[
                const SizedBox(height: AppSpacing.sm),
                AvisoError(mensaje: _errorGeneral!),
              ],
              const SizedBox(height: AppSpacing.md),
              AppElevatedButton(
                onPressed: _enviar,
                cargando: _cargando,
                child: const Text('Ingresar'),
              ),
              const SizedBox(height: 18),
              _EnlaceRegistro(
                onTap: () => context.go(RoutePaths.registroChofer),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Usa tu cuenta para acceder al panel de trabajo.',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
              ),
              const SizedBox(height: AppSpacing.xxl),
              _AccesoAdministradorButton(
                onTap: () => AdminLoginDialog.show(context),
              ),
              const SizedBox(height: AppSpacing.xxl),
              const _TextoLegal(),
            ],
          ),
        ),
      ),
    );
  }
}

/// "¿No tienes cuenta? Regístrate" — acceso rápido justo debajo del botón
/// de login, navega a la pantalla de registro de chofer.
class _EnlaceRegistro extends StatelessWidget {
  const _EnlaceRegistro({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final estiloBase = Theme.of(context).textTheme.bodyMedium;

    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: Text.rich(
          TextSpan(
            style: estiloBase?.copyWith(color: colors.textMuted),
            children: [
              const TextSpan(text: '¿No tienes cuenta? '),
              TextSpan(
                text: 'Regístrate',
                style: estiloBase?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.underline,
                  decorationColor: colors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Aviso legal al pie del login — "Términos de servicio"/"Política de
/// privacidad" quedan como placeholders hasta que se defina a dónde
/// deben abrir (navegación interna o `url_launcher` a una página real).
class _TextoLegal extends StatefulWidget {
  const _TextoLegal();

  @override
  State<_TextoLegal> createState() => _TextoLegalState();
}

class _TextoLegalState extends State<_TextoLegal> {
  // `TapGestureRecognizer` necesita disposal manual — por eso este
  // widget es Stateful en vez de crearlos sueltos dentro de `build`
  // (StatelessWidget los recrearía y nunca los liberaría).
  late final TapGestureRecognizer _tapTerminos = TapGestureRecognizer()
    ..onTap = _abrirTerminos;
  late final TapGestureRecognizer _tapPrivacidad = TapGestureRecognizer()
    ..onTap = _abrirPrivacidad;

  void _abrirTerminos() {
    // TODO: navegar/abrir con url_launcher a la página real cuando exista.
  }

  void _abrirPrivacidad() {
    // TODO: navegar/abrir con url_launcher a la página real cuando exista.
  }

  @override
  void dispose() {
    _tapTerminos.dispose();
    _tapPrivacidad.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final estiloBase = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: colors.textMuted, fontSize: 11.5);
    final estiloLink = estiloBase?.copyWith(
      color: colors.info,
      decoration: TextDecoration.underline,
      decorationColor: colors.info,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Text.rich(
        TextSpan(
          style: estiloBase,
          children: [
            const TextSpan(text: 'Al continuar, aceptas los '),
            TextSpan(
              text: 'Términos de servicio',
              style: estiloLink,
              recognizer: _tapTerminos,
            ),
            const TextSpan(text: ' y la '),
            TextSpan(
              text: 'Política de privacidad',
              style: estiloLink,
              recognizer: _tapPrivacidad,
            ),
            const TextSpan(
              text:
                  ', y recibir correos electrónicos periódicos con '
                  'actualizaciones.',
            ),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _AccesoAdministradorButton extends StatelessWidget {
  const _AccesoAdministradorButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        shape: RoundedRectangleBorder(borderRadius: AppRadii.navButtonRadius),
      ),
      icon: Icon(Icons.shield_outlined, color: colors.textSecondary),
      label: Text(
        'Entrar como administrador',
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(color: colors.textSecondary),
      ),
    );
  }
}
