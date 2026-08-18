import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth_controller.dart';
import '../../core/validators.dart';
import '../../data/auth_repository.dart';
import '../../router/route_paths.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_elevated_button.dart';
import '../../widgets/auth_screen_shell.dart';
import '../../widgets/aviso_error.dart';

/// Registro de chofer, en dos pasos: datos personales → cuenta. Un
/// formulario largo de un jalón se siente pesado y es fácil perder el
/// hilo de qué falta; partirlo en pasos cortos con progreso visible da
/// una sensación de avance y permite validar cada bloque por separado.
///
/// El vehículo NO se captura aquí — se elige del catálogo compartido en
/// cada solicitud/comprobación de carga, porque distintos choferes pueden
/// usar distintas unidades en días distintos (ver /chofer/solicitar).
class RegistroChoferScreen extends ConsumerStatefulWidget {
  const RegistroChoferScreen({super.key});

  @override
  ConsumerState<RegistroChoferScreen> createState() =>
      _RegistroChoferScreenState();
}

class _RegistroChoferScreenState extends ConsumerState<RegistroChoferScreen> {
  final _formKeyPaso1 = GlobalKey<FormState>();
  final _formKeyPaso2 = GlobalKey<FormState>();

  final _nombreController = TextEditingController();
  final _apellidoPaternoController = TextEditingController();
  final _apellidoMaternoController = TextEditingController();
  final _correoController = TextEditingController();
  final _usuarioController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmarPasswordController = TextEditingController();

  int _paso = 0;
  bool _cargando = false;
  String? _errorGeneral;
  bool _passwordVisible = false;
  bool _confirmarPasswordVisible = false;
  String _fuerzaPassword = '';

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_actualizarFuerzaPassword);
  }

  @override
  void dispose() {
    _passwordController.removeListener(_actualizarFuerzaPassword);
    _nombreController.dispose();
    _apellidoPaternoController.dispose();
    _apellidoMaternoController.dispose();
    _correoController.dispose();
    _usuarioController.dispose();
    _passwordController.dispose();
    _confirmarPasswordController.dispose();
    super.dispose();
  }

  void _actualizarFuerzaPassword() {
    setState(() => _fuerzaPassword = _calcularFuerza(_passwordController.text));
  }

  /// Solo cosmético (guía visual) — la regla real de validez sigue siendo
  /// [Validators.password] (mínimo 8 caracteres).
  static String _calcularFuerza(String v) {
    if (v.isEmpty) return '';
    var puntos = 0;
    if (v.length >= 8) puntos++;
    if (v.length >= 12) puntos++;
    if (RegExp(r'[A-Z]').hasMatch(v) && RegExp(r'[a-z]').hasMatch(v)) puntos++;
    if (RegExp(r'[0-9]').hasMatch(v)) puntos++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(v)) puntos++;
    if (puntos <= 1) return 'Débil';
    if (puntos <= 3) return 'Media';
    return 'Fuerte';
  }

  void _irAPaso2() {
    if (!_formKeyPaso1.currentState!.validate()) return;
    setState(() {
      _paso = 1;
      _errorGeneral = null;
    });
  }

  void _volverAPaso1() {
    setState(() {
      _paso = 0;
      _errorGeneral = null;
    });
  }

  Future<void> _enviar() async {
    if (!_formKeyPaso2.currentState!.validate()) return;

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
            apellidoMaterno: _apellidoMaternoController.text.trim(),
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
    return AuthScreenShell(
      onBack: () => context.go(RoutePaths.login),
      titulo: 'Regístrate',
      subtitulo: 'Primero tus datos personales.',
      mostrarMarca: false,
      logoSize: 48,
      compactLogoSize: 36,
      waveLeftHeightFactor: 0.96,
      waveRightHeightFactor: 0.78,
      centrarContenido: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _IndicadorDePasos(
            key: const Key('registro-indicador-pasos'),
            pasoActual: _paso,
            totalPasos: 2,
          ),
          const SizedBox(height: 20),
          AnimatedSwitcher(
            duration: AppMotion.base,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.06, 0),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            child: _paso == 0 ? _buildPaso1(context) : _buildPaso2(context),
          ),
        ],
      ),
    );
  }

  Widget _buildPaso1(BuildContext context) {
    return Form(
      key: _formKeyPaso1,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        key: const ValueKey('paso1'),
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
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _apellidoPaternoController,
            decoration: const InputDecoration(
              labelText: 'Apellido paterno',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
            validator: (v) =>
                Validators.apellido(v, etiqueta: 'El apellido paterno'),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _apellidoMaternoController,
            decoration: const InputDecoration(
              labelText: 'Apellido materno',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
            validator: (v) =>
                Validators.apellido(v, etiqueta: 'El apellido materno'),
            textInputAction: TextInputAction.next,
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
            onFieldSubmitted: (_) => _irAPaso2(),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _irAPaso2,
            icon: const Icon(Icons.arrow_forward, size: 18),
            label: const Text('Siguiente'),
          ),
        ],
      ),
    );
  }

  Widget _buildPaso2(BuildContext context) {
    return Form(
      key: _formKeyPaso2,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        key: const ValueKey('paso2'),
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
            textInputAction: TextInputAction.next,
          ),
          if (_fuerzaPassword.isNotEmpty) ...[
            const SizedBox(height: 8),
            _MedidorFuerzaPassword(fuerza: _fuerzaPassword),
          ],
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
                    () =>
                        _confirmarPasswordVisible = !_confirmarPasswordVisible,
                  ),
                ),
              ),
            ),
            obscureText: !_confirmarPasswordVisible,
            validator: (v) =>
                Validators.confirmarPassword(v, _passwordController.text),
            onFieldSubmitted: (_) => _enviar(),
          ),
          if (_errorGeneral != null) ...[
            const SizedBox(height: 16),
            AvisoError(mensaje: _errorGeneral!),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _cargando ? null : _volverAPaso1,
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Atrás'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: AppElevatedButton(
                  onPressed: _enviar,
                  cargando: _cargando,
                  child: const Text('Crear cuenta'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Barra de progreso de 2 segmentos — el paso actual y los ya
/// completados se pintan con el azul de marca, el resto queda apagado.
class _IndicadorDePasos extends StatelessWidget {
  const _IndicadorDePasos({
    super.key,
    required this.pasoActual,
    required this.totalPasos,
  });

  final int pasoActual;
  final int totalPasos;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        for (var i = 0; i < totalPasos; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: AnimatedContainer(
              duration: AppMotion.base,
              curve: AppMotion.curve,
              height: 4,
              decoration: BoxDecoration(
                color: i <= pasoActual ? colors.primary : colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _MedidorFuerzaPassword extends StatelessWidget {
  const _MedidorFuerzaPassword({required this.fuerza});

  final String fuerza;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (color, fraccion) = switch (fuerza) {
      'Débil' => (colors.error, 1 / 3),
      'Media' => (colors.warning, 2 / 3),
      _ => (colors.success, 1.0),
    };

    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: AnimatedContainer(
              duration: AppMotion.base,
              curve: AppMotion.curve,
              height: 5,
              decoration: BoxDecoration(color: colors.border),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: fraccion,
                  child: DecoratedBox(decoration: BoxDecoration(color: color)),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          fuerza,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
