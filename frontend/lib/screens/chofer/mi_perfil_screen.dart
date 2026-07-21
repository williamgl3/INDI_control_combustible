import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth_controller.dart';
import '../../core/session_provider.dart';
import '../../core/validators.dart';
import '../../data/auth_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/grouped_section.dart';
import '../../widgets/responsive_scroll_view.dart';

/// Datos personales del usuario en sesión (chofer o administrativo) +
/// cambiar contraseña — antes de esto, una vez logueado no había forma
/// de ver los propios datos ni cambiar la contraseña (solo existía
/// "olvidé mi contraseña" antes de entrar).
class MiPerfilScreen extends ConsumerStatefulWidget {
  const MiPerfilScreen({super.key});

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi perfil'),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: SafeArea(
        child: ResponsiveScrollView(
          maxWidth: 480,
          child: Column(
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
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
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
                  if (perfil.fechaNacimiento != null)
                    GroupedRow(
                      titulo: 'Fecha de nacimiento',
                      subtitulo:
                          '${perfil.fechaNacimiento!.day.toString().padLeft(2, '0')}/'
                          '${perfil.fechaNacimiento!.month.toString().padLeft(2, '0')}/'
                          '${perfil.fechaNacimiento!.year} (${perfil.edad} años)',
                      icono: Icons.cake_outlined,
                    ),
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
                            onPressed: () => setState(
                              () => _actualVisible = !_actualVisible,
                            ),
                          ),
                        ),
                      ),
                      obscureText: !_actualVisible,
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'Ingresa tu contraseña actual.'
                          : null,
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
                            onPressed: () => setState(
                              () => _nuevaVisible = !_nuevaVisible,
                            ),
                          ),
                        ),
                      ),
                      obscureText: !_nuevaVisible,
                      validator: Validators.password,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmarController,
                      decoration: InputDecoration(
                        labelText: 'Confirmar contraseña nueva',
                        prefixIcon: const Icon(Icons.lock_reset_outlined),
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
                      Text(
                        _errorGeneral!,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: colors.error),
                      ),
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
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colors.success),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _cargando ? null : _cambiarPassword,
                      child: _cargando
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Guardar nueva contraseña'),
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
