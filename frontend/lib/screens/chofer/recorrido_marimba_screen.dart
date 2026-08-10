import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/catalogos_vehiculo.dart';
import '../../core/cola_solicitudes_offline.dart';
import '../../core/providers.dart';
import '../../models/despacho_marimba.dart';
import '../../models/recorrido_marimba.dart';
import '../../models/vehiculo.dart';
import '../../router/route_paths.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_elevated_button.dart';
import '../../widgets/aviso_error.dart';
import '../../widgets/captura_foto_field.dart';
import '../../widgets/chofer_operation_scaffold.dart';
import '../../widgets/selector_vehiculo.dart';
import '../../widgets/sin_conexion_dialog.dart';
import '../../widgets/stepper_numerico.dart';

/// Jornada de despacho de la marimba: abrir un recorrido, agregar N
/// despachos en una sola pantalla (sin navegar por cada máquina, ver
/// diseño acordado del flujo de marimba) y cerrarlo con conciliación de
/// litros. Reemplaza, para este flujo, la captura de un despacho suelto
/// (`RegistrarDespachoScreen` sigue existiendo para ese caso aparte).
///
/// Offline-first: cada acción (abrir/agregar despacho/cerrar) se escribe
/// primero en su cola local (ver `cola_solicitudes_offline.dart`) y luego
/// se intenta sincronizar de inmediato — funciona igual con o sin señal,
/// sin que esta pantalla necesite distinguir los dos casos.
class RecorridoMarimbaScreen extends ConsumerStatefulWidget {
  const RecorridoMarimbaScreen({super.key});

  @override
  ConsumerState<RecorridoMarimbaScreen> createState() =>
      _RecorridoMarimbaScreenState();
}

class _RecorridoMarimbaScreenState
    extends ConsumerState<RecorridoMarimbaScreen> {
  // --- Abrir recorrido ---
  Vehiculo? _marimba;
  final _frenteController = TextEditingController();
  double _litrosIniciales = 0;
  double _kmInicio = 0;
  double _horasEquipoMenorInicio = 0;
  bool _abriendo = false;
  String? _errorAbrir;

  // --- Recorrido activo (una vez abierto) ---
  String? _recorridoIdLocal;
  Vehiculo? _marimbaActiva;
  String? _frenteActivo;
  double _litrosInicialesActivos = 0;
  final _despachos = <DespachoMarimba>[];
  final _destinosRecientes = <String>[];
  int _contadorLocal = 0;

  // --- Agregar despacho ---
  Vehiculo? _destino;
  bool _destinoLibre = false;
  final _destinoTextoController = TextEditingController();
  final _operadorController = TextEditingController();
  final _residenteController = TextEditingController();
  double _litrosSuministrados = 0;
  double _lecturaMedidor = 0;
  String? _fotoDespachoPath;
  bool _cargandoFotoDespacho = false;
  bool _agregando = false;
  String? _errorDespacho;

  bool _cerrando = false;

  @override
  void dispose() {
    _frenteController.dispose();
    _destinoTextoController.dispose();
    _operadorController.dispose();
    _residenteController.dispose();
    super.dispose();
  }

  double get _litrosDespachados =>
      _despachos.fold(0.0, (suma, d) => suma + d.litrosSuministrados);

  double get _existenciaEstimada =>
      _litrosInicialesActivos - _litrosDespachados;

  Future<void> _abrirRecorrido() async {
    if (_marimba == null) {
      setState(() => _errorAbrir = 'Elige qué marimba vas a usar.');
      return;
    }
    if (_frenteController.text.trim().isEmpty) {
      setState(() => _errorAbrir = 'Indica el frente donde vas a operar.');
      return;
    }
    if (_litrosIniciales <= 0) {
      setState(
        () => _errorAbrir =
            'Indica con cuántos litros sale el camión (existencia inicial).',
      );
      return;
    }

    setState(() {
      _abriendo = true;
      _errorAbrir = null;
    });

    final marimba = _marimba!;
    final frente = _frenteController.text.trim();
    final idLocal = 'recorrido-${DateTime.now().microsecondsSinceEpoch}';

    await ref
        .read(colaRecorridosMarimbaOfflineProvider)
        .agregar(
          RecorridoMarimbaPendienteOffline(
            idLocal: idLocal,
            marimbaId: marimba.id,
            frente: frente,
            litrosIniciales: _litrosIniciales,
            kmInicio: _kmInicio > 0 ? _kmInicio : null,
            horasEquipoMenorInicio: _horasEquipoMenorInicio > 0
                ? _horasEquipoMenorInicio
                : null,
            creadaEn: DateTime.now(),
          ),
        );
    try {
      await sincronizarRecorridosMarimba(ref);
    } catch (_) {
      // El recorrido ya quedó guardado en la cola — un fallo aquí no
      // pierde nada, solo significa que no se resolvió todavía.
    }

    if (!mounted) return;
    setState(() {
      _recorridoIdLocal = idLocal;
      _marimbaActiva = marimba;
      _frenteActivo = frente;
      _litrosInicialesActivos = _litrosIniciales;
      _abriendo = false;
    });
  }

  Future<void> _agregarDespacho() async {
    if (_destino == null && _destinoTextoController.text.trim().isEmpty) {
      setState(
        () => _errorDespacho = 'Indica qué máquina recibió el combustible.',
      );
      return;
    }
    if (_operadorController.text.trim().isEmpty) {
      setState(() => _errorDespacho = 'Indica quién recibió el combustible.');
      return;
    }
    if (_litrosSuministrados <= 0) {
      setState(() => _errorDespacho = 'Indica los litros despachados.');
      return;
    }

    setState(() {
      _agregando = true;
      _errorDespacho = null;
    });

    final destinoTexto = _destinoLibre
        ? _destinoTextoController.text.trim()
        : null;
    final destino = _destinoLibre ? null : _destino;
    final operador = _operadorController.text.trim();
    final residente = _residenteController.text.trim().isEmpty
        ? null
        : _residenteController.text.trim();
    final litros = _litrosSuministrados;
    final lectura = _lecturaMedidor > 0 ? _lecturaMedidor : null;
    final foto = _fotoDespachoPath;

    await ref
        .read(colaDespachosMarimbaOfflineProvider)
        .agregar(
          DespachoMarimbaPendienteOffline(
            idLocal: 'despacho-${DateTime.now().microsecondsSinceEpoch}',
            recorridoIdLocal: _recorridoIdLocal!,
            vehiculoDestinoId: destino?.id,
            destinoTexto: destinoTexto,
            operadorTexto: operador,
            residenteTexto: residente,
            litrosSuministrados: litros,
            lecturaMedidor: lectura,
            fotoEvidenciaPath: foto,
            creadaEn: DateTime.now(),
          ),
        );
    try {
      await sincronizarRecorridosMarimba(ref);
    } catch (_) {
      // Igual que al abrir — ya quedó en la cola, se reintentará solo.
    }

    final etiquetaDestino =
        destino?.modelo ?? destino?.etiquetaUnidad ?? destinoTexto!;

    if (!mounted) return;
    setState(() {
      _despachos.add(
        DespachoMarimba(
          id: 'local-${_contadorLocal++}',
          marimbaId: _marimbaActiva!.id,
          vehiculoDestinoId: destino?.id,
          destinoTexto: destinoTexto,
          operadorTexto: operador,
          residenteTexto: residente,
          litrosSuministrados: litros,
          lecturaMedidor: lectura,
          fotoEvidenciaPath: foto,
          registradoPor: '',
          creadoEn: DateTime.now(),
          recorridoId: _recorridoIdLocal,
        ),
      );
      _destinosRecientes.remove(etiquetaDestino);
      _destinosRecientes.insert(0, etiquetaDestino);
      if (_destinosRecientes.length > 5) _destinosRecientes.removeLast();

      _destino = null;
      _destinoTextoController.clear();
      _litrosSuministrados = 0;
      _lecturaMedidor = 0;
      _fotoDespachoPath = null;
      _agregando = false;
    });
  }

  Future<void> _tomarFotoDespacho() async {
    setState(() => _cargandoFotoDespacho = true);
    final ruta = await ref.read(fotoPickerProvider).tomarFoto();
    if (mounted) {
      setState(() {
        if (ruta != null) _fotoDespachoPath = ruta;
        _cargandoFotoDespacho = false;
      });
    }
  }

  Future<void> _cerrarRecorrido() async {
    final resultado = await _DialogoCerrarRecorrido.show(context, ref: ref);
    if (resultado == null) return;

    setState(() => _cerrando = true);
    final idLocal = _recorridoIdLocal!;

    // Se guarda el `idServidor` (si ya se conoce) ANTES de sincronizar,
    // porque una vez que el cierre tenga éxito el recorrido se quita de
    // su cola — después de eso ya no habría forma de recuperarlo de ahí.
    final idServidorAntes =
        (await ref.read(colaRecorridosMarimbaOfflineProvider).leer())
            .where((r) => r.idLocal == idLocal)
            .map((r) => r.idServidor)
            .firstOrNull;

    await ref
        .read(colaCierresRecorridoMarimbaOfflineProvider)
        .agregar(
          CierreRecorridoMarimbaPendienteOffline(
            idLocal: 'cierre-${DateTime.now().microsecondsSinceEpoch}',
            recorridoIdLocal: idLocal,
            kmCierre: resultado.kmCierre,
            horasEquipoMenorCierre: resultado.horasEquipoMenorCierre,
            fotoCierrePath: resultado.fotoCierrePath,
            creadaEn: DateTime.now(),
          ),
        );
    try {
      await sincronizarRecorridosMarimba(ref);
    } catch (_) {
      // Queda en la cola — se reintenta sola.
    }

    final sigueEnCola =
        (await ref.read(colaRecorridosMarimbaOfflineProvider).leer()).any(
          (r) => r.idLocal == idLocal,
        );

    if (!mounted) return;

    if (sigueEnCola) {
      setState(() => _cerrando = false);
      await SinConexionDialog.show(
        context,
        mensaje:
            'Guardamos el cierre en este dispositivo. Se enviará solo en '
            'cuanto vuelvas a tener señal — no hace falta que lo repitas.',
      );
      if (mounted) context.go(RoutePaths.chofer);
      return;
    }

    // Se cerró de verdad en el servidor — se busca la conciliación real
    // para mostrarla (no la estimación local de `_existenciaEstimada`).
    RecorridoMarimba? recorridoCerrado;
    if (idServidorAntes != null) {
      recorridoCerrado = await ref
          .read(recorridosMarimbaRepositoryProvider)
          .buscarRecorrido(idServidorAntes);
    }

    if (!mounted) return;
    setState(() => _cerrando = false);
    await _DialogoConciliacion.show(context, recorrido: recorridoCerrado);
    if (mounted) context.go(RoutePaths.chofer);
  }

  @override
  Widget build(BuildContext context) {
    return ChoferOperationScaffold(
      titulo: _recorridoIdLocal == null
          ? 'Abrir recorrido de marimba'
          : 'Recorrido · $_frenteActivo',
      child: _recorridoIdLocal == null
          ? _buildFormularioAbrir(context)
          : _buildCaptura(context),
    );
  }

  Widget _buildFormularioAbrir(BuildContext context) {
    final marimbas = ref
        .watch(vehiculosRepositoryProvider)
        .todos
        .where((v) => esUnidadGranel(v.tipoUnidad) && estaActiva(v))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _marimba?.id,
          decoration: const InputDecoration(
            labelText: '¿Qué marimba vas a usar?',
            prefixIcon: Icon(Icons.local_shipping_outlined),
          ),
          items: marimbas
              .map(
                (m) => DropdownMenuItem(
                  value: m.id,
                  child: Text(m.etiquetaCompleta ?? m.etiquetaUnidad),
                ),
              )
              .toList(),
          onChanged: (valor) => setState(
            () => _marimba = marimbas.where((m) => m.id == valor).firstOrNull,
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _frenteController,
          decoration: const InputDecoration(
            labelText: 'Frente / ubicación del recorrido',
            hintText: 'Ej. BANCO EL HUIZACHITO',
            prefixIcon: Icon(Icons.location_on_outlined),
          ),
        ),
        const SizedBox(height: 16),
        StepperNumerico(
          etiqueta: 'Litros con los que sale el camión',
          valor: _litrosIniciales,
          sufijo: 'L',
          paso: 50,
          onChanged: (v) => setState(() => _litrosIniciales = v),
        ),
        const SizedBox(height: 16),
        StepperNumerico(
          etiqueta: 'Kilometraje inicial (opcional)',
          valor: _kmInicio,
          sufijo: 'km',
          paso: 1,
          decimales: 1,
          onChanged: (v) => setState(() => _kmInicio = v),
        ),
        const SizedBox(height: 16),
        StepperNumerico(
          etiqueta: 'Horas del equipo menor (opcional)',
          valor: _horasEquipoMenorInicio,
          sufijo: 'h',
          paso: 1,
          decimales: 1,
          onChanged: (v) => setState(() => _horasEquipoMenorInicio = v),
        ),
        if (_errorAbrir != null) ...[
          const SizedBox(height: 12),
          AvisoError(mensaje: _errorAbrir!),
        ],
        const SizedBox(height: 24),
        AppElevatedButton(
          onPressed: _abrirRecorrido,
          cargando: _abriendo,
          child: const Text('Abrir recorrido'),
        ),
      ],
    );
  }

  Widget _buildCaptura(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _TarjetaTotales(
          litrosIniciales: _litrosInicialesActivos,
          litrosDespachados: _litrosDespachados,
          existenciaEstimada: _existenciaEstimada,
        ),
        const SizedBox(height: 20),
        Text(
          'Despachos de este recorrido',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (_despachos.isEmpty)
          Text(
            'Todavía no agregas ningún despacho.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.textMuted),
          )
        else
          ..._despachos.reversed.map(
            (d) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _TarjetaDespacho(despacho: d),
            ),
          ),
        const SizedBox(height: 20),
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Agregar despacho',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 12),
              if (_destinosRecientes.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: _destinosRecientes
                      .map(
                        (etiqueta) => ActionChip(
                          label: Text(etiqueta),
                          onPressed: () => setState(() {
                            _destinoLibre = true;
                            _destino = null;
                            _destinoTextoController.text = etiqueta;
                          }),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 12),
              ],
              if (!_destinoLibre)
                SelectorVehiculo(
                  vehiculoSeleccionado: _destino,
                  filtroTipoUnidad: 'Maquinaria',
                  filtroUbicacion: _frenteActivo,
                  onSeleccionar: (v) => setState(() => _destino = v),
                )
              else
                TextFormField(
                  controller: _destinoTextoController,
                  decoration: const InputDecoration(
                    labelText: 'Máquina destino',
                    prefixIcon: Icon(Icons.precision_manufacturing_outlined),
                  ),
                ),
              TextButton(
                onPressed: () => setState(() => _destinoLibre = !_destinoLibre),
                child: Text(
                  _destinoLibre
                      ? 'Elegir del catálogo'
                      : 'No está en el catálogo',
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _operadorController,
                decoration: const InputDecoration(
                  labelText: 'Operador que recibe el combustible',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _residenteController,
                decoration: const InputDecoration(
                  labelText: 'Residente a cargo (opcional)',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
              ),
              const SizedBox(height: 16),
              StepperNumerico(
                etiqueta: 'Litros despachados',
                valor: _litrosSuministrados,
                sufijo: 'L',
                paso: 10,
                onChanged: (v) => setState(() => _litrosSuministrados = v),
              ),
              const SizedBox(height: 16),
              StepperNumerico(
                etiqueta: 'Horómetro de la máquina (opcional)',
                valor: _lecturaMedidor,
                sufijo: 'h',
                paso: 1,
                decimales: 1,
                onChanged: (v) => setState(() => _lecturaMedidor = v),
              ),
              const SizedBox(height: 16),
              CapturaFotoField(
                etiqueta: 'Foto del despacho (opcional)',
                icono: Icons.photo_camera_outlined,
                rutaFoto: _fotoDespachoPath,
                cargando: _cargandoFotoDespacho,
                onTomarFoto: _tomarFotoDespacho,
              ),
              if (_errorDespacho != null) ...[
                const SizedBox(height: 12),
                AvisoError(mensaje: _errorDespacho!),
              ],
              const SizedBox(height: 16),
              AppElevatedButton(
                onPressed: _agregarDespacho,
                cargando: _agregando,
                child: const Text('Agregar a la lista'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        OutlinedButton(
          onPressed: _cerrando ? null : _cerrarRecorrido,
          child: _cerrando
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Cerrar recorrido'),
        ),
      ],
    );
  }
}

class _TarjetaTotales extends StatelessWidget {
  const _TarjetaTotales({
    required this.litrosIniciales,
    required this.litrosDespachados,
    required this.existenciaEstimada,
  });

  final double litrosIniciales;
  final double litrosDespachados;
  final double existenciaEstimada;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppCard(
      floating: true,
      color: colors.info.withValues(alpha: 0.08),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _Dato(
              etiqueta: 'Salió con',
              valor: '${litrosIniciales.toStringAsFixed(0)} L',
            ),
          ),
          Expanded(
            child: _Dato(
              etiqueta: 'Despachado',
              valor: '${litrosDespachados.toStringAsFixed(0)} L',
            ),
          ),
          Expanded(
            child: _Dato(
              etiqueta: 'Existencia estimada',
              valor: '${existenciaEstimada.toStringAsFixed(0)} L',
              destacado: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({
    required this.etiqueta,
    required this.valor,
    this.destacado = false,
  });

  final String etiqueta;
  final String valor;
  final bool destacado;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          etiqueta.toUpperCase(),
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: colors.textMuted),
        ),
        const SizedBox(height: 2),
        Text(
          valor,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: destacado ? colors.info : colors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _TarjetaDespacho extends StatelessWidget {
  const _TarjetaDespacho({required this.despacho});

  final DespachoMarimba despacho;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  despacho.destinoTexto ?? 'Máquina sin identificar',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  '${despacho.operadorTexto}${despacho.lecturaMedidor != null ? ' · ${despacho.lecturaMedidor!.toStringAsFixed(1)} h' : ''}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
                ),
              ],
            ),
          ),
          Text(
            '${despacho.litrosSuministrados.toStringAsFixed(0)} L',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: colors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultadoCierre {
  const _ResultadoCierre({
    this.kmCierre,
    this.horasEquipoMenorCierre,
    required this.fotoCierrePath,
  });

  final double? kmCierre;
  final double? horasEquipoMenorCierre;
  final String fotoCierrePath;
}

class _DialogoCerrarRecorrido extends ConsumerStatefulWidget {
  const _DialogoCerrarRecorrido();

  static Future<_ResultadoCierre?> show(
    BuildContext context, {
    required WidgetRef ref,
  }) {
    return showDialog<_ResultadoCierre>(
      context: context,
      builder: (_) => const _DialogoCerrarRecorrido(),
    );
  }

  @override
  ConsumerState<_DialogoCerrarRecorrido> createState() =>
      _DialogoCerrarRecorridoState();
}

class _DialogoCerrarRecorridoState
    extends ConsumerState<_DialogoCerrarRecorrido> {
  double _kmCierre = 0;
  double _horasEquipoMenorCierre = 0;
  String? _fotoCierrePath;
  bool _cargandoFoto = false;
  String? _error;

  Future<void> _tomarFoto() async {
    setState(() => _cargandoFoto = true);
    final ruta = await ref.read(fotoPickerProvider).tomarFoto();
    if (mounted) {
      setState(() {
        if (ruta != null) _fotoCierrePath = ruta;
        _cargandoFoto = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cerrar recorrido'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StepperNumerico(
            etiqueta: 'Kilometraje final (opcional)',
            valor: _kmCierre,
            sufijo: 'km',
            paso: 1,
            decimales: 1,
            onChanged: (v) => setState(() => _kmCierre = v),
          ),
          const SizedBox(height: 16),
          StepperNumerico(
            etiqueta: 'Horas del equipo menor al cierre (opcional)',
            valor: _horasEquipoMenorCierre,
            sufijo: 'h',
            paso: 1,
            decimales: 1,
            onChanged: (v) => setState(() => _horasEquipoMenorCierre = v),
          ),
          const SizedBox(height: 16),
          CapturaFotoField(
            etiqueta: 'Foto de cierre (obligatoria)',
            icono: Icons.photo_camera_outlined,
            rutaFoto: _fotoCierrePath,
            cargando: _cargandoFoto,
            onTomarFoto: _tomarFoto,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            AvisoError(mensaje: _error!),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (_fotoCierrePath == null) {
              setState(() => _error = 'La foto de cierre es obligatoria.');
              return;
            }
            Navigator.of(context).pop(
              _ResultadoCierre(
                kmCierre: _kmCierre > 0 ? _kmCierre : null,
                horasEquipoMenorCierre: _horasEquipoMenorCierre > 0
                    ? _horasEquipoMenorCierre
                    : null,
                fotoCierrePath: _fotoCierrePath!,
              ),
            );
          },
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}

class _DialogoConciliacion {
  const _DialogoConciliacion._();

  static Future<void> show(
    BuildContext context, {
    required RecorridoMarimba? recorrido,
  }) {
    final requiereRevision = recorrido?.requiereRevision ?? false;
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          requiereRevision
              ? Icons.warning_amber_outlined
              : Icons.check_circle_outline,
          color: requiereRevision
              ? context.colors.warning
              : context.colors.success,
        ),
        title: const Text('Recorrido cerrado'),
        content: recorrido == null
            ? const Text('El recorrido se cerró correctamente.')
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Litros despachados: '
                    '${recorrido.litrosDespachadosTotal?.toStringAsFixed(1) ?? '—'} L',
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Existencia en tanque: '
                    '${recorrido.existenciaCalculada?.toStringAsFixed(1) ?? '—'} L',
                  ),
                  if (requiereRevision) ...[
                    const SizedBox(height: 12),
                    Text(
                      'La diferencia excede la tolerancia — un administrativo '
                      'va a revisar este recorrido.',
                      style: TextStyle(color: context.colors.warning),
                    ),
                  ],
                ],
              ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }
}
