import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth_controller.dart';
import '../../core/session_provider.dart';
import '../../core/theme_mode_provider.dart';
import '../../core/validators.dart';
import '../../data/auth_repository.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_elevated_button.dart';
import '../../widgets/aviso_error.dart';
import '../../widgets/confirmar_cerrar_sesion_dialog.dart';
import '../../widgets/grouped_section.dart';
import '../../widgets/responsive_scroll_view.dart';
import '../../widgets/selector_tema_dialog.dart';

/// Datos personales del usuario en sesión (chofer o administrativo) +
/// cambiar contraseña + configuración de tema + cerrar sesión.
class MiPerfilScreen extends ConsumerStatefulWidget {
  const MiPerfilScreen({super.key, this.mostrarComoTab = false});

  /// `true` cuando esta pantalla vive embebida como una pestaña de
  /// [ChoferHomeShell] (sin `AppBar`/botón de volver propios, ya los
  /// da el shell) en vez de empujada como ruta independiente.
  final bool mostrarComoTab;

  @override
  ConsumerState<MiPerfilScreen> createState() => _MiPerfilScreenState();
}

class _MiPerfilScreenState extends ConsumerState<MiPerfilScreen> {
  final _formKey = GlobalKey<FormState>();
  final _actualController = TextEditingController();
  final _nuevaController = TextEditingController();
  final _confirmarController = TextEditingController();

  bool _actualVisible = false;
  bool _nuevaVisible = false;
  bool _cargando = false;
  String? _errorGeneral;
  bool _exito = false;

  @override
  void dispose() {
    _actualController.dispose();
    _nuevaController.dispose();
    _confirmarController.dispose();
    super.dispose();
  }

  Future<void> _cambiarPassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _cargando = true;
      _errorGeneral = null;
      _exito = false;
    });
    try {
      await ref
          .read(authControllerProvider)
          .cambiarPassword(
            passwordActual: _actualController.text,
            passwordNueva: _nuevaController.text,
          );
      _actualController.clear();
      _nuevaController.clear();
      _confirmarController.clear();
      if (mounted) setState(() => _exito = true);
    } on AuthException catch (e) {
      setState(() => _errorGeneral = e.mensaje);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _cerrarSesion() async {
    final confirmado = await confirmarCerrarSesion(context);
    if (confirmado && context.mounted) {
      await ref.read(authControllerProvider).logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final perfil = ref.watch(sessionProvider);
    if (perfil == null) return const SizedBox.shrink();

    final apellidoPaterno = perfil.apellidoPaterno;
    final iniciales =
        '${perfil.nombre.isNotEmpty ? perfil.nombre[0] : ''}'
        '${apellidoPaterno != null && apellidoPaterno.isNotEmpty ? apellidoPaterno[0] : ''}'
            .toUpperCase();

    final bodyContent = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Column(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: colors.primary.withValues(alpha: 0.15),
                child: Text(
                  iniciales,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                perfil.nombreCompleto,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                perfil.esChofer ? 'Chofer' : 'Administrativo',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        GroupedSection(
          header: 'Datos personales',
          children: [
            GroupedRow(
              titulo: 'Usuario',
              subtitulo: perfil.usuario,
              icono: Icons.person_outline,
            ),
            GroupedRow(
              titulo: 'Correo',
              subtitulo: perfil.correo,
              icono: Icons.mail_outline,
            ),
          ],
        ),
        const SizedBox(height: 24),
        GroupedSection(
          header: 'Configuración',
          children: [
            _TemaRow(),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'Cambiar contraseña',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _actualController,
                decoration: InputDecoration(
                  labelText: 'Contraseña actual',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: Semantics(
                    label: _actualVisible
                        ? 'Ocultar contraseña'
                        : 'Mostrar contraseña',
                    button: true,
                    child: IconButton(
                      icon: Icon(
                        _actualVisible
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      tooltip: _actualVisible ? 'Ocultar' : 'Ver',
                      onPressed: () =>
                          setState(() => _actualVisible = !_actualVisible),
                    ),
                  ),
                ),
                obscureText: !_actualVisible,
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Ingresa tu contraseña actual.' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nuevaController,
                decoration: InputDecoration(
                  labelText: 'Contraseña nueva',
                  prefixIcon: const Icon(Icons.lock_reset_outlined),
                  suffixIcon: Semantics(
                    label: _nuevaVisible
                        ? 'Ocultar contraseña'
                        : 'Mostrar contraseña',
                    button: true,
                    child: IconButton(
                      icon: Icon(
                        _nuevaVisible
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      tooltip: _nuevaVisible ? 'Ocultar' : 'Ver',
                      onPressed: () =>
                          setState(() => _nuevaVisible = !_nuevaVisible),
                    ),
                  ),
                ),
                obscureText: !_nuevaVisible,
                validator: Validators.password,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmarController,
                decoration: const InputDecoration(
                  labelText: 'Confirmar contraseña nueva',
                  prefixIcon: Icon(Icons.lock_reset_outlined),
                ),
                obscureText: !_nuevaVisible,
                validator: (v) => Validators.confirmarPassword(
                  v,
                  _nuevaController.text,
                ),
                onFieldSubmitted: (_) => _cambiarPassword(),
              ),
              if (_errorGeneral != null) ...[
                const SizedBox(height: 12),
                AvisoError(mensaje: _errorGeneral!),
              ],
              if (_exito) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 18,
                      color: colors.success,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Contraseña actualizada.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.success,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              AppElevatedButton(
                onPressed: _cambiarPassword,
                cargando: _cargando,
                child: const Text('Guardar nueva contraseña'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        OutlinedButton.icon(
          onPressed: _cerrarSesion,
          style: OutlinedButton.styleFrom(
            foregroundColor: colors.error,
            side: BorderSide(color: colors.error),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: AppRadii.inputRadius,
            ),
          ),
          icon: const Icon(Icons.logout),
          label: const Text(
            'Cerrar sesión',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 40),
      ],
    );

    if (widget.mostrarComoTab) {
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 80),
          child: bodyContent,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi perfil'),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: SafeArea(
        child: ResponsiveScrollView(
          maxWidth: 480,
          child: bodyContent,
        ),
      ),
    );
  }
}

class _TemaRow extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final themeMode = ref.watch(themeModeProvider);

    final (icono, etiqueta) = switch (themeMode) {
      ThemeMode.light => (Icons.light_mode_outlined, 'Claro'),
      ThemeMode.dark => (Icons.dark_mode_outlined, 'Oscuro'),
      ThemeMode.system => (Icons.brightness_auto_outlined, 'Predeterminado del sistema'),
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => SelectorTemaDialog.show(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icono, size: 22, color: colors.textMuted),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tema',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    Text(
                      etiqueta,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: colors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
