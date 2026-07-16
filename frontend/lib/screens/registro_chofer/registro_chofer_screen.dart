import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth_controller.dart';
import '../../core/validators.dart';
import '../../data/mock_auth_repository.dart';
import '../../router/route_paths.dart';
import '../../theme/app_theme.dart';

/// TODO-SPEC: opciones de tipo de unidad y tipo de combustible son
/// PLACEHOLDER (no hay enum cerrado confirmado en SPEC.md todavía).
const _tiposUnidad = ['Camión', 'Camioneta', 'Maquinaria'];
const _tiposCombustible = ['Diésel', 'Gasolina'];

class RegistroChoferScreen extends ConsumerStatefulWidget {
  const RegistroChoferScreen({super.key});

  @override
  ConsumerState<RegistroChoferScreen> createState() => _RegistroChoferScreenState();
}

class _RegistroChoferScreenState extends ConsumerState<RegistroChoferScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nombreController = TextEditingController();
  final _edadController = TextEditingController();
  final _correoController = TextEditingController();
  final _usuarioController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmarPasswordController = TextEditingController();
  final _modeloController = TextEditingController();
  final _placaController = TextEditingController();

  String _tipoUnidad = _tiposUnidad.first;
  String _tipoCombustible = _tiposCombustible.first;

  bool _cargando = false;
  String? _errorGeneral;

  @override
  void dispose() {
    _nombreController.dispose();
    _edadController.dispose();
    _correoController.dispose();
    _usuarioController.dispose();
    _passwordController.dispose();
    _confirmarPasswordController.dispose();
    _modeloController.dispose();
    _placaController.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _cargando = true;
      _errorGeneral = null;
    });

    try {
      await ref.read(authControllerProvider).registrarChofer(
            nombreCompleto: _nombreController.text.trim(),
            edad: int.parse(_edadController.text.trim()),
            correo: _correoController.text.trim(),
            usuario: _usuarioController.text.trim(),
            password: _passwordController.text,
            tipoUnidad: _tipoUnidad,
            modelo: _modeloController.text.trim(),
            placaONumeroEconomico: _placaController.text.trim(),
            tipoCombustible: _tipoCombustible,
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registro de chofer'),
        leading: BackButton(onPressed: () => context.go(RoutePaths.login)),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Datos personales', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nombreController,
                      decoration: const InputDecoration(labelText: 'Nombre completo'),
                      validator: Validators.nombre,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _edadController,
                      decoration: const InputDecoration(labelText: 'Edad'),
                      keyboardType: TextInputType.number,
                      validator: Validators.edad,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _correoController,
                      decoration: const InputDecoration(labelText: 'Correo'),
                      keyboardType: TextInputType.emailAddress,
                      validator: Validators.correo,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _usuarioController,
                      decoration: const InputDecoration(labelText: 'Usuario'),
                      validator: Validators.usuario,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      decoration: const InputDecoration(labelText: 'Contraseña'),
                      obscureText: true,
                      validator: Validators.password,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmarPasswordController,
                      decoration: const InputDecoration(labelText: 'Confirmar contraseña'),
                      obscureText: true,
                      validator: (v) =>
                          Validators.confirmarPassword(v, _passwordController.text),
                    ),
                    const SizedBox(height: 32),
                    Text('Datos de tu vehículo/maquinaria',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(
                      'Estos datos quedan asociados a tu cuenta y se usarán para '
                      'precargar tus solicitudes de carga.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _tipoUnidad,
                      decoration: const InputDecoration(labelText: 'Tipo de unidad'),
                      items: _tiposUnidad
                          .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                          .toList(),
                      onChanged: (v) => setState(() => _tipoUnidad = v!),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _modeloController,
                      decoration: const InputDecoration(labelText: 'Modelo / descripción'),
                      validator: (v) => Validators.requerido(v, etiqueta: 'El modelo'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _placaController,
                      decoration:
                          const InputDecoration(labelText: 'Placa o número económico'),
                      validator: (v) =>
                          Validators.requerido(v, etiqueta: 'La placa o número económico'),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _tipoCombustible,
                      decoration: const InputDecoration(labelText: 'Tipo de combustible'),
                      items: _tiposCombustible
                          .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                          .toList(),
                      onChanged: (v) => setState(() => _tipoCombustible = v!),
                    ),
                    if (_errorGeneral != null) ...[
                      const SizedBox(height: 16),
                      Text(_errorGeneral!, style: TextStyle(color: colors.error)),
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
            ),
          ),
        ),
      ),
    );
  }
}
