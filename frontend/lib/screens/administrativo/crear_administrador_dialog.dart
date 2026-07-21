import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/validators.dart';
import '../../data/auth_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_dialog.dart';

/// Modal para dar de alta a un nuevo usuario administrativo. Formulario
/// simple (nombre, usuario, correo, password) — a diferencia del registro
/// de chofer no pide fecha de nacimiento ni apellidos por separado, ya
/// que el personal administrativo no pasa por el flujo de auto-registro.
class CrearAdministradorDialog extends ConsumerStatefulWidget {
  const CrearAdministradorDialog({super.key});

  static Future<bool?> show(BuildContext context) {
    return mostrarDialogoApp<bool>(
      context,
      builder: (_) => const CrearAdministradorDialog(),
    );
  }

  @override
  ConsumerState<CrearAdministradorDialog> createState() =>
      _CrearAdministradorDialogState();
}

class _CrearAdministradorDialogState
    extends ConsumerState<CrearAdministradorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _usuarioController = TextEditingController();
  final _correoController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _cargando = false;
  String? _errorGeneral;
  bool _passwordVisible = false;

  @override
  void dispose() {
    _nombreController.dispose();
    _usuarioController.dispose();
    _correoController.dispose();
    _passwordController.dispose();
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
          .crearAdministrativo(
            nombre: _nombreController.text.trim(),
            usuario: _usuarioController.text.trim(),
            correo: _correoController.text.trim(),
            password: _passwordController.text,
          );
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
              'Crear administrador',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nombreController,
              decoration: const InputDecoration(
                labelText: 'Nombre',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
              validator: Validators.nombre,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _usuarioController,
              decoration: const InputDecoration(
                labelText: 'Usuario',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: Validators.usuario,
              autocorrect: false,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _correoController,
              decoration: const InputDecoration(
                labelText: 'Correo',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              validator: Validators.correo,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
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
              obscureText: !_passwordVisible,
              validator: Validators.password,
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
                        : const Text('Crear'),
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
