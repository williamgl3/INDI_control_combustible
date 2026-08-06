import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../models/despacho_marimba.dart';
import '../../models/vehiculo.dart';
import '../../router/route_paths.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_elevated_button.dart';
import '../../widgets/aviso_error.dart';
import '../../widgets/captura_foto_field.dart';
import '../../widgets/contenido_responsivo.dart';
import '../../widgets/selector_vehiculo.dart';
import '../../widgets/stepper_numerico.dart';

/// Registra un despacho de la marimba hacia una unidad de maquinaria en
/// campo — la SALIDA del libro mayor de saldo de la marimba. La carga a
/// granel de la marimba (la ENTRADA) no tiene pantalla propia: usa el
/// mismo flujo de Solicitar/Comprobar carga que cualquier vehículo,
/// eligiendo la marimba como unidad.
class RegistrarDespachoScreen extends ConsumerStatefulWidget {
  const RegistrarDespachoScreen({super.key});

  @override
  ConsumerState<RegistrarDespachoScreen> createState() =>
      _RegistrarDespachoScreenState();
}

class _RegistrarDespachoScreenState
    extends ConsumerState<RegistrarDespachoScreen> {
  final _destinoTextoController = TextEditingController();
  final _operadorController = TextEditingController();
  final _residenteController = TextEditingController();
  final _sitioController = TextEditingController();

  Vehiculo? _marimba;
  Vehiculo? _destino;
  bool _destinoLibre = false;
  double _litrosSolicitados = 0;
  double _litrosSuministrados = 0;
  double _lecturaMedidor = 0;
  bool _unidadInactivaHoy = false;
  String? _fotoEvidenciaPath;
  bool _cargandoFoto = false;
  bool _enviando = false;
  String? _errorGeneral;

  double? _saldoActual;
  bool _cargandoSaldo = false;

  @override
  void dispose() {
    _destinoTextoController.dispose();
    _operadorController.dispose();
    _residenteController.dispose();
    _sitioController.dispose();
    super.dispose();
  }

  Future<void> _elegirMarimba(Vehiculo marimba) async {
    setState(() {
      _marimba = marimba;
      _saldoActual = null;
      _cargandoSaldo = true;
    });
    try {
      final saldo = await ref
          .read(despachosMarimbaRepositoryProvider)
          .saldoDeMarimba(marimba.id);
      if (mounted) setState(() => _saldoActual = saldo);
    } catch (_) {
      // El formulario sigue usable sin el saldo visible — el backend
      // vuelve a validar el saldo real al enviar de todas formas.
    } finally {
      if (mounted) setState(() => _cargandoSaldo = false);
    }
  }

  Future<void> _tomarFoto() async {
    setState(() => _cargandoFoto = true);
    final ruta = await ref.read(fotoPickerProvider).tomarFoto();
    if (mounted) {
      setState(() {
        if (ruta != null) _fotoEvidenciaPath = ruta;
        _cargandoFoto = false;
      });
    }
  }

  bool get _formularioCompleto {
    if (_marimba == null) return false;
    if (_destino == null && _destinoTextoController.text.trim().isEmpty) {
      return false;
    }
    if (_operadorController.text.trim().isEmpty) return false;
    if (_sitioController.text.trim().isEmpty) return false;
    if (_unidadInactivaHoy) return true;
    return _litrosSuministrados > 0 && _fotoEvidenciaPath != null;
  }

  Future<void> _enviar() async {
    if (!_formularioCompleto) {
      setState(
        () => _errorGeneral = _unidadInactivaHoy
            ? 'Completa la unidad destino, el operador y el sitio.'
            : 'Completa la unidad destino, el operador, el sitio, los litros '
                  'suministrados y la foto de evidencia.',
      );
      return;
    }

    setState(() {
      _enviando = true;
      _errorGeneral = null;
    });

    try {
      await ref
          .read(despachosMarimbaRepositoryProvider)
          .registrarDespacho(
            marimbaId: _marimba!.id,
            vehiculoDestinoId: _destinoLibre ? null : _destino?.id,
            destinoTexto: _destinoLibre
                ? _destinoTextoController.text.trim()
                : null,
            operadorTexto: _operadorController.text.trim(),
            residenteTexto: _residenteController.text.trim().isEmpty
                ? null
                : _residenteController.text.trim(),
            sitio: _sitioController.text.trim(),
            litrosSolicitados: _litrosSolicitados > 0
                ? _litrosSolicitados
                : null,
            litrosSuministrados: _unidadInactivaHoy ? 0 : _litrosSuministrados,
            lecturaMedidor: _lecturaMedidor > 0 ? _lecturaMedidor : null,
            estado: _unidadInactivaHoy
                ? EstadoDespacho.inactivo
                : EstadoDespacho.activo,
            fotoEvidenciaPath: _fotoEvidenciaPath,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Despacho registrado correctamente.')),
        );
        context.pop();
      }
    } catch (e) {
      setState(
        () => _errorGeneral =
            'No pudimos registrar el despacho. Intenta de nuevo.',
      );
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(operacionesTickProvider);
    // "Pipa" opera el mismo libro mayor que "Marimba" — ver migración
    // 0024. Las 14 pipas normales del catálogo real y el camión especial
    // "orquesta" comparten el mismo mecanismo de carga a granel +
    // despacho, solo son categorías de unidad distintas.
    final marimbas = ref
        .watch(vehiculosRepositoryProvider)
        .todos
        .where(
          (v) =>
              (v.tipoUnidad == 'Marimba' || v.tipoUnidad == 'Pipa') &&
              v.activo,
        )
        .toList();
    final maquinaria = ref
        .watch(vehiculosRepositoryProvider)
        .todos
        .where((v) => v.tipoUnidad == 'Maquinaria' && v.activo)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar despacho'),
        leading: BackButton(onPressed: () => context.go(RoutePaths.chofer)),
      ),
      body: SafeArea(
        child: ContenidoResponsivo(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              _SelectorMarimba(
                marimbas: marimbas,
                seleccionada: _marimba,
                onSeleccionar: _elegirMarimba,
              ),
              if (_marimba != null) ...[
                const SizedBox(height: 12),
                _TarjetaSaldo(
                  cargando: _cargandoSaldo,
                  saldo: _saldoActual,
                ),
              ],
              const SizedBox(height: 20),
              if (maquinaria.isNotEmpty && !_destinoLibre)
                SelectorVehiculo(
                  vehiculoSeleccionado: _destino,
                  filtroTipoUnidad: 'Maquinaria',
                  onSeleccionar: (v) => setState(() => _destino = v),
                ),
              if (maquinaria.isEmpty || _destinoLibre)
                TextFormField(
                  controller: _destinoTextoController,
                  decoration: const InputDecoration(
                    labelText: 'Unidad destino',
                    hintText: 'Ej. Tractor D8R, Excavadora 330 EHO-330-056',
                    prefixIcon: Icon(Icons.precision_manufacturing_outlined),
                  ),
                ),
              if (maquinaria.isNotEmpty)
                TextButton(
                  onPressed: () => setState(() => _destinoLibre = !_destinoLibre),
                  child: Text(
                    _destinoLibre
                        ? 'Elegir del catálogo'
                        : 'La unidad no está en el catálogo',
                  ),
                ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _operadorController,
                decoration: const InputDecoration(
                  labelText: 'Operador que recibe el combustible',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _residenteController,
                decoration: const InputDecoration(
                  labelText: 'Residente a cargo (opcional)',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _sitioController,
                decoration: const InputDecoration(
                  labelText: 'Sitio / frente de trabajo',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
              ),
              const SizedBox(height: 20),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Unidad inactiva hoy (sin despacho)'),
                subtitle: const Text(
                  'Se registra que se consideró, sin mover el saldo de la marimba.',
                ),
                value: _unidadInactivaHoy,
                onChanged: (v) => setState(() => _unidadInactivaHoy = v),
              ),
              if (!_unidadInactivaHoy) ...[
                const SizedBox(height: 8),
                StepperNumerico(
                  etiqueta: 'Litros solicitados (opcional)',
                  valor: _litrosSolicitados,
                  sufijo: 'L',
                  paso: 10,
                  onChanged: (v) => setState(() => _litrosSolicitados = v),
                ),
                const SizedBox(height: 16),
                StepperNumerico(
                  etiqueta: 'Litros suministrados',
                  valor: _litrosSuministrados,
                  sufijo: 'L',
                  paso: 10,
                  onChanged: (v) => setState(() => _litrosSuministrados = v),
                ),
                const SizedBox(height: 16),
                StepperNumerico(
                  etiqueta: 'Horómetro / km de la unidad (opcional)',
                  valor: _lecturaMedidor,
                  sufijo: '',
                  paso: 1,
                  decimales: 1,
                  onChanged: (v) => setState(() => _lecturaMedidor = v),
                ),
                const SizedBox(height: 16),
                CapturaFotoField(
                  etiqueta: 'Foto de evidencia del despacho',
                  icono: Icons.photo_camera_outlined,
                  rutaFoto: _fotoEvidenciaPath,
                  cargando: _cargandoFoto,
                  onTomarFoto: _tomarFoto,
                ),
              ],
              if (_errorGeneral != null) ...[
                const SizedBox(height: 12),
                AvisoError(mensaje: _errorGeneral!),
              ],
              const SizedBox(height: 24),
              AppElevatedButton(
                onPressed: _enviar,
                cargando: _enviando,
                child: const Text('Registrar despacho'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectorMarimba extends StatelessWidget {
  const _SelectorMarimba({
    required this.marimbas,
    required this.seleccionada,
    required this.onSeleccionar,
  });

  final List<Vehiculo> marimbas;
  final Vehiculo? seleccionada;
  final ValueChanged<Vehiculo> onSeleccionar;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: seleccionada?.id,
      decoration: const InputDecoration(
        labelText: '¿Qué marimba vas a despachar?',
        prefixIcon: Icon(Icons.local_shipping_outlined),
      ),
      items: marimbas
          .map(
            (m) => DropdownMenuItem(
              value: m.id,
              child: Text(
                '${m.etiquetaUnidad} · ${m.tipoCombustible ?? 'Sin especificar'}',
              ),
            ),
          )
          .toList(),
      onChanged: (valor) {
        final marimba = marimbas.where((m) => m.id == valor).firstOrNull;
        if (marimba != null) onSeleccionar(marimba);
      },
    );
  }
}

class _TarjetaSaldo extends StatelessWidget {
  const _TarjetaSaldo({required this.cargando, required this.saldo});

  final bool cargando;
  final double? saldo;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppCard(
      floating: true,
      color: colors.info.withValues(alpha: 0.08),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(Icons.water_drop_outlined, color: colors.info),
          const SizedBox(width: 12),
          Expanded(
            child: cargando
                ? const Text('Consultando saldo…')
                : Text(
                    saldo == null
                        ? 'No se pudo consultar el saldo.'
                        : 'Saldo actual en la marimba: ${saldo!.toStringAsFixed(1)} L',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
          ),
        ],
      ),
    );
  }
}
