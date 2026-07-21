import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth_controller.dart';
import '../../core/validators.dart';
import '../../data/auth_repository.dart';
import '../../router/route_paths.dart';
import '../../theme/app_theme.dart';
import '../../widgets/auth_screen_shell.dart';

/// Registro de chofer: SOLO datos personales. El vehículo ya no se
/// captura aquí — se elige del catálogo compartido en cada solicitud/
/// comprobación de carga, porque distintos choferes pueden usar
/// distintas unidades en días distintos (ver /chofer/solicitar).
class RegistroChoferScreen extends ConsumerStatefulWidget {
  const RegistroChoferScreen({super.key});

  @override
  ConsumerState<RegistroChoferScreen> createState() =>
      _RegistroChoferScreenState();
}

class _RegistroChoferScreenState extends ConsumerState<RegistroChoferScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nombreController = TextEditingController();
  final _apellidoPaternoController = TextEditingController();
  final _apellidoMaternoController = TextEditingController();
  final _correoController = TextEditingController();
  final _usuarioController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmarPasswordController = TextEditingController();

  DateTime? _fechaNacimiento;
  bool _cargando = false;
  String? _errorGeneral;
  bool _passwordVisible = false;
  bool _confirmarPasswordVisible = false;

  @override
  void dispose() {
    _nombreController.dispose();
    _apellidoPaternoController.dispose();
    _apellidoMaternoController.dispose();
    _correoController.dispose();
    _usuarioController.dispose();
    _passwordController.dispose();
    _confirmarPasswordController.dispose();
    super.dispose();
  }

  static const _mesesLargo = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];

  Future<void> _elegirFechaNacimiento() async {
    final hoy = DateTime.now();
    final elegida = await showDatePicker(
      context: context,
      initialDate:
          _fechaNacimiento ?? DateTime(hoy.year - 25, hoy.month, hoy.day),
      firstDate: DateTime(hoy.year - 100),
      lastDate: DateTime(hoy.year - Validators.edadMin, hoy.month, hoy.day),
      helpText: 'Fecha de nacimiento',
      // Arranca en modo "escribir la fecha" — el calendario queda como
      // opción secundaria (ícono de calendario en el diálogo), no como
      // default. Con muchos años de por medio entre hoy y el rango
      // válido (18-100 años atrás), navegar el calendario mes por mes es
      // más lento que simplemente teclear la fecha.
      initialEntryMode: DatePickerEntryMode.input,
      errorFormatText: 'Formato inválido',
      errorInvalidText: 'Fuera del rango permitido',
      fieldLabelText: 'Fecha de nacimiento',
      fieldHintText: 'dd/mm/aaaa',
    );
    if (elegida != null) setState(() => _fechaNacimiento = elegida);
  }

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) return;
    final errorFecha = Validators.fechaNacimiento(_fechaNacimiento);
    if (errorFecha != null) {
      setState(() => _errorGeneral = errorFecha);
      return;
    }

    setState(() {
      _cargando = true;
      _errorGeneral = null;
    });

    try {
      await ref
          .read(authControllerProvider)
          .registrarChofer(
            nombre: _nombreController.text.trim(),
            apellidoPaterno: _apellidoPaternoController.text.trim(),
            apellidoMaterno: _apellidoMaternoController.text.trim().isEmpty
                ? null
                : _apellidoMaternoController.text.trim(),
            fechaNacimiento: _fechaNacimiento!,
            correo: _correoController.text.trim(),
            usuario: _usuarioController.text.trim(),
            password: _passwordController.text,
          );
      // El guard de rutas redirige automáticamente a /chofer al detectar la sesión.
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
      onBack: () => context.go(RoutePaths.login),
      titulo: 'Regístrate',
      subtitulo:
          'El vehículo que uses lo eliges cada vez que solicites '
          'combustible, no se registra aquí.',
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nombreController,
              decoration: const InputDecoration(
                labelText: 'Nombre(s)',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
              validator: Validators.nombre,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _apellidoPaternoController,
              decoration: const InputDecoration(
                labelText: 'Apellido paterno',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
              validator: Validators.nombre,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _apellidoMaternoController,
              decoration: const InputDecoration(
                labelText: 'Apellido materno (opcional)',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
            ),
            const SizedBox(height: 16),
            Semantics(
              button: true,
              label: 'Elegir fecha de nacimiento',
              child: InkWell(
                onTap: _elegirFechaNacimiento,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  isEmpty: _fechaNacimiento == null,
                  decoration: const InputDecoration(
                    labelText: 'Fecha de nacimiento',
                    prefixIcon: Icon(Icons.cake_outlined),
                    suffixIcon: Icon(Icons.calendar_today_outlined),
                  ),
                  child: _fechaNacimiento == null
                      ? null
                      : Text(
                          '${_fechaNacimiento!.day} de '
                          '${_mesesLargo[_fechaNacimiento!.month - 1]} de '
                          '${_fechaNacimiento!.year}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _correoController,
              decoration: const InputDecoration(
                labelText: 'Correo',
                prefixIcon: Icon(Icons.mail_outline),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: Validators.correo,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _usuarioController,
              decoration: const InputDecoration(
                labelText: 'Usuario',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: Validators.usuario,
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
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirmarPasswordController,
              decoration: InputDecoration(
                labelText: 'Confirmar contraseña',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: Semantics(
                  label: _confirmarPasswordVisible
                      ? 'Ocultar confirmación de contraseña'
                      : 'Mostrar confirmación de contraseña',
                  button: true,
                  child: IconButton(
                    icon: Icon(
                      _confirmarPasswordVisible
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                    tooltip: _confirmarPasswordVisible ? 'Ocultar' : 'Ver',
                    onPressed: () => setState(
                      () => _confirmarPasswordVisible =
                          !_confirmarPasswordVisible,
                    ),
                  ),
                ),
              ),
              obscureText: !_confirmarPasswordVisible,
              validator: (v) =>
                  Validators.confirmarPassword(v, _passwordController.text),
            ),
            if (_errorGeneral != null) ...[
              const SizedBox(height: 16),
              Text(
                _errorGeneral!,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.error),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _cargando ? null : _enviar,
              child: _cargando
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Crear cuenta'),
            ),
          ],
        ),
      ),
    );
  }
}
