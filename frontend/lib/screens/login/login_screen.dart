import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth_controller.dart';
import '../../core/validators.dart';
import '../../data/auth_repository.dart';
import '../../router/route_paths.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_theme.dart';
import '../../widgets/brand_header.dart';
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

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header estilo "large title" de iOS: mismo fondo que la
                  // pantalla, sin banda de color — el logo + título llevan
                  // toda la presencia visual.
                  BrandHeader(
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: AppRadii.inputRadius,
                          child: Image.asset(
                            'assets/images/logo_indi.jpeg',
                            width: 52,
                            height: 52,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'INDI Combustible',
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(color: colors.textPrimary),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Control de combustible en obra',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: colors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextFormField(
                            controller: _usuarioController,
                            decoration: const InputDecoration(
                              labelText: 'Usuario',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            validator: Validators.usuario,
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 16),
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
                                onPressed: () => setState(
                                  () => _passwordVisible = !_passwordVisible,
                                ),
                              ),
                            ),
                            obscureText: !_passwordVisible,
                            validator: Validators.password,
                            onFieldSubmitted: (_) => _enviar(),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () =>
                                  context.go(RoutePaths.recuperarPassword),
                              child: const Text('¿Olvidaste tu contraseña?'),
                            ),
                          ),
                          if (_errorGeneral != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              _errorGeneral!,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: colors.error),
                            ),
                          ],
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: _cargando ? null : _enviar,
                            child: _cargando
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Ingresar'),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(child: Divider(color: colors.border)),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: Text(
                                  'o',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(color: colors.textMuted),
                                ),
                              ),
                              Expanded(child: Divider(color: colors.border)),
                            ],
                          ),
                          const SizedBox(height: 24),
                          _AccesoAdministradorButton(
                            onTap: () => AdminLoginDialog.show(context),
                          ),
                          const SizedBox(height: 16),
                          _RegistroChoferButton(
                            onTap: () => context.go(RoutePaths.registroChofer),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
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

    return Material(
      color: Colors.transparent,
      borderRadius: AppRadii.cardRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.cardRadius,
        hoverColor: colors.surfaceAlt,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: AppRadii.cardRadius,
            color: colors.surface,
            boxShadow: context.shadows.card,
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: colors.sidebarBackground,
                child: Icon(Icons.shield_outlined, color: colors.sidebarText),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Acceso de administrador',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: colors.textPrimary),
                ),
              ),
              Icon(Icons.chevron_right, color: colors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _RegistroChoferButton extends StatelessWidget {
  const _RegistroChoferButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Material(
      color: Colors.transparent,
      borderRadius: AppRadii.cardRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.cardRadius,
        hoverColor: colors.primaryHover.withValues(alpha: 0.15),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: colors.primary,
            borderRadius: AppRadii.cardRadius,
            boxShadow: context.shadows.card,
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: colors.primaryOn.withValues(alpha: 0.15),
                child: Icon(Icons.person_add_alt_1, color: colors.primaryOn),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '¿Eres chofer y no tienes cuenta?',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colors.primaryOn,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Regístrate en un minuto',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.primaryOn.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward, color: colors.primaryOn),
            ],
          ),
        ),
      ),
    );
  }
}
