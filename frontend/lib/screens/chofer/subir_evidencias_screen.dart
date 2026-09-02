import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/catalogos_vehiculo.dart';
import '../../core/cola_solicitudes_offline.dart';
import '../../core/connectivity_provider.dart';
import '../../core/flujo_diario_provider.dart';
import '../../core/offline/metadata_archivo_offline.dart';
import '../../core/offline/metadata_operacion_offline.dart';
import '../../core/providers.dart';
import '../../core/session_provider.dart';
import '../../core/solicitud_idempotencia.dart';
import '../../core/validators.dart';
import '../../data/api_client.dart';
import '../../models/evidencia.dart';
import '../../models/precio_combustible.dart';
import '../../models/solicitud_autorizacion.dart';
import '../../models/vehiculo.dart';
import '../../theme/app_borders.dart';
import '../../theme/app_breakpoints.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_elevated_button.dart';
import '../../widgets/brand_sub_header.dart';
import '../../widgets/contenido_responsivo.dart';
import '../../widgets/chofer_operation_scaffold.dart';
import '../../widgets/estado_solicitud_badge.dart';
import '../../widgets/fecha_formato.dart';
import '../../widgets/grouped_section.dart';
import '../../widgets/paso_diario_stepper.dart';
import '../../widgets/sidebar_chofer.dart';
import '../../widgets/sin_conexion_dialog.dart';

class SubirEvidenciasScreen extends ConsumerStatefulWidget {
  const SubirEvidenciasScreen({super.key, this.mostrarComoTab = false});

  final bool mostrarComoTab;

  @override
  ConsumerState<SubirEvidenciasScreen> createState() =>
      _SubirEvidenciasScreenState();
}

class _SubirEvidenciasScreenState extends ConsumerState<SubirEvidenciasScreen> {
  static const _maxFotos = 5;

  /// "Evidencias" (índice 3) — el destino del sidebar que representa esta
  /// pantalla, usado solo en la ruta standalone (fuera del shell).
  static const _indiceSidebar = 3;

  /// Tolerancia entre el total tecleado y litros×precio calculado — el
  /// mayor entre un monto fijo (cubre redondeo de IVA) y un porcentaje del
  /// total (para montos grandes). Solo dispara una advertencia, nunca
  /// bloquea el envío.
  ///
  /// Más estricta que antes ($2.00/1% → $1.00/0.5%): a diferencia de la
  /// desviación contra el precio de referencia (que SÍ varía legítimo
  /// por estación/día), un desajuste entre litros×precio y el total es
  /// casi siempre un error de captura del chofer, no una variación de
  /// mercado — con el ticket real analizado (40 L × $23.99 = $959.60,
  /// que ya incluye IVA en el precio por litro publicado en la bomba) la
  /// discrepancia es 0, así que $1.00/0.5% sigue siendo holgado para
  /// redondeo legítimo sin dejar pasar un dedazo.
  static const _toleranciaTotalFija = 1.0;
  static const _toleranciaTotalPorcentaje = 0.005;

  /// Mismo umbral que `evidenciasService.UMBRAL_DESVIACION_PRECIO_REFERENCIA`
  /// en el backend — este valor es solo para la advertencia visual
  /// inmediata al capturar; el número que se persiste lo calcula el
  /// servidor. Mantener sincronizados ambos valores si se ajusta el
  /// umbral.
  static const _umbralDesviacionPrecioReferencia = 0.25;

  final _formKey = GlobalKey<FormState>();
  final _notasController = TextEditingController();
  final _busquedaController = TextEditingController();
  final _kmController = TextEditingController();
  final _litrosController = TextEditingController();
  final _precioController = TextEditingController();
  final _totalController = TextEditingController();

  _TipoEvidencia _tipo = _TipoEvidencia.comprobante;
  String? _tipoCombustibleCargado;
  final List<String> _fotoPaths = [];

  /// Metadata durable de cada foto importada — paralelo a [_fotoPaths].
  /// Cada entrada contiene el SHA-256 y storageKey que la cola offline
  /// usará para verificar integridad antes de reintentar el envío.
  final List<MetadataArchivoOffline> _fotosDurable = [];

  bool _cargandoFoto = false;
  bool _enviando = false;
  String? _errorGeneral;
  bool _guardado = false;

  /// El chofer a veces sube evidencia antes de que exista una solicitud
  /// folio asignada — con esto marca explícitamente "aún no la tengo" en
  /// vez de dejar el campo vacío por error. La evidencia se guarda sin
  /// `folioId`, marcada como pendiente de vincular después.
  bool _vincularDespues = false;

  /// ID local de la evidencia en construcción — se genera una vez y se
  /// reutiliza para todas las fotos importadas a durable storage y para
  /// la clave de idempotencia. Se establece al capturar la primera foto.
  String? _idLocalEvidencia;

  /// Solicitud seleccionada por el usuario — `null` = "Ninguna / evidencia suelta".
  SolicitudAutorizacion? _solicitudSeleccionada;

  @override
  void dispose() {
    _notasController.dispose();
    _busquedaController.dispose();
    _kmController.dispose();
    _litrosController.dispose();
    _precioController.dispose();
    _totalController.dispose();
    super.dispose();
  }

  /// El tipo "tablero" no se asocia a una solicitud (es una lectura de
  /// km, no un gasto) — para los demás tipos el folio es obligatorio a
  /// menos que el chofer elija "vincular después".
  bool get _folioRequerido =>
      _tipo != _TipoEvidencia.tablero && !_vincularDespues;

  /// Último km conocido del vehículo activo hoy — si existe, el km nuevo
  /// debe ser mayor (el odómetro no retrocede). `null` si no hay carga
  /// abierta hoy (dato no disponible).
  double? get _ultimoKm {
    final perfil = ref.read(sessionProvider);
    if (perfil == null) return null;
    final repo = ref.read(operacionesRepositoryProvider);
    return repo.cargaAbiertaDeHoy(perfil.id)?.kmAlCargar;
  }

  /// El vehículo de la solicitud ligada (si hay una) — para cruzar su
  /// `tipoCombustible` ya registrado contra lo que el chofer reporta en
  /// el comprobante. `null` si no hay solicitud seleccionada (evidencia
  /// suelta/"vincular después"), en cuyo caso no hay nada contra qué
  /// comparar.
  Vehiculo? get _vehiculoDeSolicitud {
    final solicitud = _solicitudSeleccionada;
    if (solicitud == null) return null;
    return ref.read(vehiculosRepositoryProvider).porId(solicitud.vehiculoId);
  }

  /// Advertencia NO bloqueante (punto 3g) — puede haber excepciones
  /// legítimas (préstamo de combustible entre unidades, etc.), así que
  /// solo avisa, nunca impide guardar.
  bool get _hayDiscrepanciaCombustible {
    final vehiculo = _vehiculoDeSolicitud;
    final tipo = _tipoCombustibleCargado;
    final registrado = vehiculo?.tipoCombustible;
    // Sin combustible confirmado en el catálogo, no hay nada contra qué
    // comparar — no es una discrepancia real, es un dato faltante.
    if (vehiculo == null || tipo == null || registrado == null) return false;
    return registrado != tipo;
  }

  /// Adelanto visual, no autoritativo, de la misma comparación que hace
  /// el backend al guardar (`evidenciasService.calcularDesviacionPrecio`)
  /// — el número que realmente se persiste (`requiereRevision`,
  /// `desviacionPrecioPorcentaje`) se calcula del lado del servidor
  /// contra el histórico de precios, no aquí. Esto es solo para que el
  /// chofer vea la advertencia AL CAPTURAR, sin esperar la respuesta del
  /// servidor. El precio sí varía legítimo por estación y por día —
  /// lenguaje deliberadamente no acusatorio.
  bool get _hayDesviacionPrecioReferencia {
    final precio = double.tryParse(_precioController.text.trim());
    final tipo = _tipoCombustibleCargado;
    if (precio == null || tipo == null) return false;
    final precios = ref.read(operacionesRepositoryProvider).precios;
    PrecioCombustible? referencia;
    for (final p in precios) {
      if (p.tipoCombustible == tipo) {
        referencia = p;
        break;
      }
    }
    if (referencia == null || referencia.precioPorLitro <= 0) return false;
    final desviacion =
        (precio - referencia.precioPorLitro).abs() / referencia.precioPorLitro;
    return desviacion > _umbralDesviacionPrecioReferencia;
  }

  /// Compara el total tecleado contra litros×precio — con la tolerancia
  /// de [_toleranciaTotalFija]/[_toleranciaTotalPorcentaje]. Esta
  /// comparación es solo una pista visual para el chofer (Opción B del
  /// diseño) — no se persiste ni se manda al backend, así que hacerla con
  /// `double` normal (no `Decimal`) es aceptable aquí: el cuidado de
  /// precisión real está en qué valor se GUARDA (el texto tal cual lo
  /// tecleó el chofer, ver `_guardar`), no en esta alerta informativa.
  bool get _hayDiscrepanciaTotal {
    final litros = double.tryParse(_litrosController.text.trim());
    final precio = double.tryParse(_precioController.text.trim());
    final total = double.tryParse(_totalController.text.trim());
    if (litros == null || precio == null || total == null) return false;
    final calculado = litros * precio;
    final tolerancia = math.max(
      _toleranciaTotalFija,
      calculado.abs() * _toleranciaTotalPorcentaje,
    );
    return (total - calculado).abs() > tolerancia;
  }

  String get _etiquetaFoto {
    switch (_tipo) {
      case _TipoEvidencia.tablero:
        return 'Foto del tablero (km/horómetro)';
      case _TipoEvidencia.comprobante:
        return 'Foto del comprobante';
    }
  }

  IconData get _iconoFoto {
    switch (_tipo) {
      case _TipoEvidencia.tablero:
        return Icons.speed_outlined;
      case _TipoEvidencia.comprobante:
        return Icons.description_outlined;
    }
  }

  Future<void> _agregarFoto() async {
    if (_fotoPaths.length >= _maxFotos) return;
    setState(() => _cargandoFoto = true);
    final ruta = await ref.read(fotoPickerProvider).tomarFoto();
    if (mounted) {
      setState(() {
        if (ruta != null) _fotoPaths.add(ruta);
        _cargandoFoto = false;
      });
      if (ruta != null && mounted) {
        final perfil = ref.read(sessionProvider);
        if (perfil != null) {
          _idLocalEvidencia ??= nuevaIdempotencyKeyOffline();
          final idx = _fotoPaths.length - 1;
          final durable = await importarFotoADurable(
            almacenamiento: ref.read(almacenamientoOfflineProvider),
            fotoPicker: ref.read(fotoPickerProvider),
            userId: perfil.id,
            idLocal: _idLocalEvidencia!,
            rutaTemporal: ruta,
            multipartField: 'fotos_$idx',
          );
          if (mounted && durable != null) {
            setState(() {
              while (_fotosDurable.length <= idx) {
                _fotosDurable.add(durable);
              }
              _fotosDurable[idx] = durable;
            });
          }
        }
      }
    }
  }

  Future<void> _quitarFoto(int indice) async {
    if (indice < _fotosDurable.length) {
      final perfil = ref.read(sessionProvider);
      if (perfil != null && _idLocalEvidencia != null) {
        await ref
            .read(almacenamientoOfflineProvider)
            .eliminar(
              storageKey: _fotosDurable[indice].storageKey,
              usuarioId: perfil.id,
              idLocalOperacion: _idLocalEvidencia!,
            );
      }
    }
    setState(() {
      _fotoPaths.removeAt(indice);
      if (indice < _fotosDurable.length) _fotosDurable.removeAt(indice);
    });
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    if (_fotoPaths.isEmpty) {
      setState(() => _errorGeneral = 'Toma al menos una foto de la evidencia.');
      return;
    }

    if (_folioRequerido && _solicitudSeleccionada == null) {
      setState(
        () => _errorGeneral =
            'Selecciona la solicitud asociada a esta evidencia, o marca '
            '"Aún no tengo solicitud".',
      );
      return;
    }

    if (_tipo == _TipoEvidencia.comprobante &&
        _tipoCombustibleCargado == null) {
      setState(
        () => _errorGeneral = 'Selecciona el tipo de combustible cargado.',
      );
      return;
    }

    if (_fotosDurable.length != _fotoPaths.length) {
      setState(
        () => _errorGeneral =
            'Espera a que se guarden todas las fotos antes de enviar.',
      );
      return;
    }

    setState(() {
      _enviando = true;
      _errorGeneral = null;
    });

    try {
      final perfil = ref.read(sessionProvider);
      if (perfil == null) return;

      _idLocalEvidencia ??= nuevaIdempotencyKeyOffline();
      final metadata = MetadataOperacionOffline.nueva();
      final esComprobante = _tipo == _TipoEvidencia.comprobante;

      final km = _tipo == _TipoEvidencia.tablero
          ? double.tryParse(_kmController.text.trim())
          : null;
      final folioId = _solicitudSeleccionada?.id;
      final pendienteVincular =
          _vincularDespues && _solicitudSeleccionada == null;
      final notas = _notasController.text.isEmpty
          ? null
          : _notasController.text;
      final tipoCombustibleCargado = esComprobante
          ? _tipoCombustibleCargado
          : null;
      final litros = esComprobante
          ? double.tryParse(_litrosController.text.trim())
          : null;
      final precioPorLitro = esComprobante
          ? double.tryParse(_precioController.text.trim())
          : null;
      final montoPagado = esComprobante
          ? double.tryParse(_totalController.text.trim())
          : null;

      // Calcular fingerprint con SHA-256 de archivos durables.
      final fotosSha256 = _fotosDurable
          .map((a) => a.sha256)
          .toList(growable: false);
      final fingerprint = await fingerprintEvidencia(
        usuarioId: perfil.id,
        tipo: _tipo.toTipoEvidencia.name,
        km: km,
        folioId: folioId,
        cargaId: null,
        pendienteVincular: pendienteVincular,
        notas: notas,
        tipoCombustibleCargado: tipoCombustibleCargado,
        litros: litros,
        precioPorLitro: precioPorLitro,
        montoPagado: montoPagado,
        fotosSha256: fotosSha256,
      );

      final pendiente = EvidenciaPendienteOffline(
        idLocal: _idLocalEvidencia!,
        usuarioId: perfil.id,
        tipo: _tipo.toTipoEvidencia.name,
        km: km,
        folioId: folioId,
        cargaId: null,
        pendienteVincular: pendienteVincular,
        notas: notas,
        tipoCombustibleCargado: tipoCombustibleCargado,
        litros: litros,
        precioPorLitro: precioPorLitro,
        montoPagado: montoPagado,
        creadaEn: DateTime.now(),
        fotoPaths: List.of(_fotoPaths),
        archivosOffline: List.of(_fotosDurable),
        metadata: metadata,
        payloadFingerprint: fingerprint,
      );

      await ref.read(colaEvidenciasOfflineProvider).agregar(pendiente);
      ref.read(operacionesTickProvider.notifier).state++;

      // Si hay conexión, intento de envío inmediato.
      final hayConexion = ref.read(conectividadProvider).valueOrNull ?? true;
      if (hayConexion) {
        try {
          final repo = ref.read(evidenciasRepositoryProvider);
          await repo.subirEvidencia(
            usuarioId: perfil.id,
            tipo: _tipo.toTipoEvidencia,
            fotoPaths: List.of(_fotoPaths),
            km: km,
            folioId: folioId,
            cargaId: null,
            pendienteVincular: pendienteVincular,
            notas: notas,
            tipoCombustibleCargado: tipoCombustibleCargado,
            litros: litros,
            precioPorLitro: precioPorLitro,
            montoPagado: montoPagado,
            idempotencyKey: metadata.idempotencyKey,
          );
          // Éxito — limpiar de la cola.
          await ref
              .read(colaEvidenciasOfflineProvider)
              .quitar(_idLocalEvidencia!);
          ref.read(operacionesTickProvider.notifier).state++;
        } on ApiException catch (e) {
          await ref
              .read(colaEvidenciasOfflineProvider)
              .registrarError(_idLocalEvidencia!, e);
          if (e.status == null) {
            // Sin status = nunca llegó al servidor — posible falso
            // positivo de conectividad. Se queda en la cola.
          } else {
            if (mounted) {
              setState(() {
                _enviando = false;
                _errorGeneral = e.mensaje;
              });
            }
            return;
          }
        }
      }

      ref.read(evidenciaSubidaHoyProvider.notifier).state = true;
      if (!mounted) return;
      setState(() {
        _enviando = false;
        _guardado = true;
      });
      if (!hayConexion) {
        await SinConexionDialog.show(
          context,
          mensaje:
              'Guardamos tu evidencia en este dispositivo. Se enviará '
              'solo en cuanto vuelvas a tener señal.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _enviando = false;
        _errorGeneral = 'No se pudo guardar la evidencia. Intenta de nuevo.';
      });
    }
  }

  void _abrirSelectorSolicitudes() {
    final perfil = ref.read(sessionProvider);
    if (perfil == null) return;

    final repo = ref.read(operacionesRepositoryProvider);
    final solicitudes = repo.solicitudesDeChofer(perfil.id);
    final filtradas = List<SolicitudAutorizacion>.from(solicitudes);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return _SelectorSolicitudesSheet(
          solicitudes: filtradas,
          seleccionada: _solicitudSeleccionada,
          busquedaController: _busquedaController,
          onSeleccionar: (s) {
            setState(() => _solicitudSeleccionada = s);
            Navigator.of(ctx).pop();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final perfil = ref.watch(sessionProvider);
    final nombre = perfil?.nombreCompleto.split(' ').first ?? '';
    final paso = ref.watch(pasoDiarioProvider);
    final esAncho = AppBreakpoints.isTabletOrDesktop(
      MediaQuery.sizeOf(context).width,
    );

    if (_guardado) {
      return _buildExito(colors, esAncho);
    }

    final formContent = Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          Text(
            'Tipo de evidencia',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          _SelectorTipoEvidencia(
            seleccionado: _tipo,
            onChanged: (t) => setState(() {
              _tipo = t;
              _solicitudSeleccionada = null;
            }),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Foto(s) de la evidencia',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            'Hasta $_maxFotos fotos — útil cuando subes tablero y '
            'comprobante juntos al final del día.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          _SelectorFotosMultiple(
            etiqueta: _etiquetaFoto,
            icono: _iconoFoto,
            rutas: _fotoPaths,
            maxFotos: _maxFotos,
            cargando: _cargandoFoto,
            onAgregar: _agregarFoto,
            onQuitar: _quitarFoto,
          ),
          if (_tipo == _TipoEvidencia.tablero) ...[
            const SizedBox(height: AppSpacing.xl),
            Text('Kilometraje', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _kmController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                hintText: 'Ej. 45230',
                prefixIcon: Icon(Icons.speed_outlined),
                suffixText: 'km',
              ),
              validator: (v) => Validators.kilometraje(v, ultimoKm: _ultimoKm),
            ),
          ],
          if (_tipo == _TipoEvidencia.comprobante) ...[
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Tipo de combustible cargado',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '*',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(color: colors.error),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _SelectorCombustible(
              seleccionado: _tipoCombustibleCargado,
              onChanged: (t) => setState(() => _tipoCombustibleCargado = t),
            ),
            if (_hayDiscrepanciaCombustible) ...[
              const SizedBox(height: AppSpacing.sm),
              _AvisoNoBloqueante(
                mensaje:
                    'El vehículo está registrado como '
                    '${_vehiculoDeSolicitud!.tipoCombustible}, pero '
                    'seleccionaste $_tipoCombustibleCargado — verifica '
                    'antes de guardar.',
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Litros cargados',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _litrosController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                hintText: 'Ej. 40.00',
                prefixIcon: Icon(Icons.local_gas_station_outlined),
                suffixText: 'L',
              ),
              validator: (v) =>
                  Validators.numeroPositivo(v, etiqueta: 'Los litros'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Precio por litro pagado',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _precioController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                hintText: 'Ej. 23.99',
                prefixIcon: Icon(Icons.sell_outlined),
                prefixText: '\$ ',
              ),
              validator: (v) =>
                  Validators.numeroPositivo(v, etiqueta: 'El precio por litro'),
              onChanged: (_) => setState(() {}),
            ),
            if (_hayDesviacionPrecioReferencia) ...[
              const SizedBox(height: AppSpacing.sm),
              const _AvisoNoBloqueante(
                mensaje:
                    'El precio que capturaste se desvía mucho del precio de '
                    'referencia — verifica que sea correcto (el precio real '
                    'sí varía por estación y por día, esto es solo un '
                    'recordatorio).',
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            Text('Total pagado', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'El total impreso en tu comprobante — puede diferir un poco '
              'de litros × precio por el IVA.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _totalController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                hintText: 'Ej. 959.60',
                prefixIcon: Icon(Icons.payments_outlined),
                prefixText: '\$ ',
              ),
              validator: (v) =>
                  Validators.numeroPositivo(v, etiqueta: 'El total pagado'),
              onChanged: (_) => setState(() {}),
            ),
            if (_hayDiscrepanciaTotal) ...[
              const SizedBox(height: AppSpacing.sm),
              _AvisoNoBloqueante(
                mensaje:
                    'El total no coincide con litros × precio '
                    '(${(double.parse(_litrosController.text.trim()) * double.parse(_precioController.text.trim())).toStringAsFixed(2)} '
                    'calculado) — revisa antes de guardar.',
              ),
            ],
          ],
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Folio / Solicitud asociada',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (_folioRequerido) ...[
                const SizedBox(width: 4),
                Text(
                  '*',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(color: colors.error),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _CampoSolicitud(
            solicitudSeleccionada: _solicitudSeleccionada,
            requerido: _folioRequerido,
            onTap: _vincularDespues ? null : _abrirSelectorSolicitudes,
            onLimpiar: () => setState(() => _solicitudSeleccionada = null),
          ),
          if (_tipo != _TipoEvidencia.tablero) ...[
            const SizedBox(height: AppSpacing.sm),
            GroupedSection(
              children: [
                GroupedRow(
                  titulo: 'Aún no tengo solicitud',
                  subtitulo: 'Vincular después desde otra pantalla',
                  icono: Icons.link_off,
                  iconoColor: colors.textMuted,
                  trailing: Switch(
                    value: _vincularDespues,
                    onChanged: (v) => setState(() {
                      _vincularDespues = v;
                      if (v) _solicitudSeleccionada = null;
                    }),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Notas adicionales',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _notasController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Describe brevemente la evidencia...',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_errorGeneral != null) ...[
            AppCard(
              floating: true,
              padding: const EdgeInsets.all(12),
              color: colors.error.withValues(alpha: 0.1),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: colors.error, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorGeneral!,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: colors.error),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          AppElevatedButton(
            onPressed: _guardar,
            cargando: _enviando,
            child: const Text('Guardar evidencia'),
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );

    if (widget.mostrarComoTab) {
      return SafeArea(
        // Mismo `ContenidoResponsivo` compartido por todo el panel de
        // chofer — ver `ChoferHomeShell` (ya no envuelve las pestañas en
        // un tope de 480px, cada una controla el suyo).
        child: ContenidoResponsivo(
          paddingSuperior: 0,
          paddingInferior: 80,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Consumer(
                  builder: (context, ref, _) {
                    final paso = ref.watch(pasoDiarioProvider);
                    return PasoDiarioStepper(
                      unidad: paso.unidad,
                      tablero: paso.tablero,
                      solicitud: paso.solicitud,
                      evidencia: paso.evidencia,
                      pasoActivo: PasoDiarioTipo.evidencia,
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  'Hola, $nombre',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Adjunta fotos o comprobantes',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
              ),
              formContent,
            ],
          ),
        ),
      );
    }

    // Ruta standalone (fuera del `IndexedStack` de `ChoferHomeShell` — se
    // llega aquí, por ejemplo, desde el sidebar de `TipoOperacionScreen`,
    // o desde cualquier otro flujo que navegue directo a esta ruta). Sin
    // el shell alrededor, esta pantalla necesita su propio sidebar (en
    // pantallas anchas), su propio stepper y su propio botón de atrás —
    // mismo patrón que `TipoOperacionScreen`.
    final contenidoStandalone = Column(
      children: [
        BrandSubHeader(
          titulo: 'Subir evidencia',
          onBack: () => volverEnFlujoChofer(context),
        ),
        Expanded(
          child: SafeArea(
            top: false,
            child: ContenidoResponsivo(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PasoDiarioStepper(
                    unidad: paso.unidad,
                    tablero: paso.tablero,
                    solicitud: paso.solicitud,
                    evidencia: paso.evidencia,
                    pasoActivo: PasoDiarioTipo.evidencia,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  formContent,
                ],
              ),
            ),
          ),
        ),
      ],
    );

    if (esAncho) {
      return Scaffold(
        body: SafeArea(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SidebarChofer(
                indiceSeleccionado: _indiceSidebar,
                onSeleccionar: (i) =>
                    navegarDesdeSidebarChofer(context, _indiceSidebar, i),
              ),
              Expanded(child: contenidoStandalone),
            ],
          ),
        ),
      );
    }

    return Scaffold(body: contenidoStandalone);
  }

  Widget _buildExito(AppColors colors, bool esAncho) {
    final contenido = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colors.success.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.check_circle_outline,
            size: 64,
            color: colors.success,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Evidencia guardada',
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Tu evidencia fue registrada exitosamente.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        AppElevatedButton(
          onPressed: widget.mostrarComoTab
              ? () => setState(() {
                  _guardado = false;
                  _fotoPaths.clear();
                  _solicitudSeleccionada = null;
                  _vincularDespues = false;
                  _notasController.clear();
                  _busquedaController.clear();
                  _kmController.clear();
                  _litrosController.clear();
                  _precioController.clear();
                  _totalController.clear();
                  _tipoCombustibleCargado = null;
                  _tipo = _TipoEvidencia.comprobante;
                })
              : () => volverEnFlujoChofer(context),
          cargando: false,
          child: Text(
            widget.mostrarComoTab ? 'Subir otra evidencia' : 'Volver al inicio',
          ),
        ),
      ],
    );

    // Tarjeta de confirmación centrada, no un formulario/dashboard — se
    // queda con un `maxWidth` propio más angosto que el resto del panel
    // (`ContenidoResponsivo` con su default de 1040 se vería absurdo aquí:
    // botón gigante, espacio de sobra). Antes esto era inconsistente: sin
    // límite en modo pestaña, 500px fijo solo en standalone.
    final contenidoConTope = ContenidoResponsivo(
      maxWidth: 500,
      paddingSuperior: 32,
      paddingInferior: 32,
      scrollable: false,
      child: contenido,
    );

    if (widget.mostrarComoTab) {
      return SafeArea(child: contenidoConTope);
    }

    if (esAncho) {
      return Scaffold(
        body: SafeArea(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SidebarChofer(
                indiceSeleccionado: _indiceSidebar,
                onSeleccionar: (i) =>
                    navegarDesdeSidebarChofer(context, _indiceSidebar, i),
              ),
              Expanded(child: contenidoConTope),
            ],
          ),
        ),
      );
    }

    return Scaffold(body: SafeArea(child: contenidoConTope));
  }
}

// ---------------------------------------------------------------------------
// Selector de tipo de evidencia — chips con contraste mejorado
// ---------------------------------------------------------------------------

// 'ticket' se unificó con 'comprobante' — ver `models/evidencia.dart`.
enum _TipoEvidencia { tablero, comprobante }

extension _TipoEvidenciaX on _TipoEvidencia {
  TipoEvidencia get toTipoEvidencia {
    switch (this) {
      case _TipoEvidencia.tablero:
        return TipoEvidencia.tablero;
      case _TipoEvidencia.comprobante:
        return TipoEvidencia.comprobante;
    }
  }
}

class _SelectorTipoEvidencia extends StatelessWidget {
  const _SelectorTipoEvidencia({
    required this.seleccionado,
    required this.onChanged,
  });

  final _TipoEvidencia seleccionado;
  final ValueChanged<_TipoEvidencia> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _OpcionTipo(
            icono: Icons.speed_outlined,
            etiqueta: 'Tablero',
            seleccionado: seleccionado == _TipoEvidencia.tablero,
            color: context.colors.primary,
            onTap: () => onChanged(_TipoEvidencia.tablero),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _OpcionTipo(
            icono: Icons.description_outlined,
            etiqueta: 'Comprobante',
            seleccionado: seleccionado == _TipoEvidencia.comprobante,
            color: context.colors.primary,
            onTap: () => onChanged(_TipoEvidencia.comprobante),
          ),
        ),
      ],
    );
  }
}

/// Selector del tipo de combustible cargado (Diésel/Magna/Premium) — mismo
/// look que `_SelectorTipoEvidencia`/`_OpcionTipo`, pero data-driven sobre
/// el catálogo compartido (`tiposCombustibleVehiculo`) en vez de 3 chips
/// fijos, porque aquí no hay un significado semántico distinto por color
/// (son tipos de combustible, no categorías con su propio código de
/// color) — todos usan `colors.primary`.
class _SelectorCombustible extends StatelessWidget {
  const _SelectorCombustible({
    required this.seleccionado,
    required this.onChanged,
  });

  final String? seleccionado;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final tipo in tiposCombustibleVehiculo) ...[
          if (tipo != tiposCombustibleVehiculo.first) const SizedBox(width: 8),
          Expanded(
            child: _OpcionTipo(
              icono: Icons.local_gas_station_outlined,
              etiqueta: tipo,
              seleccionado: seleccionado == tipo,
              color: context.colors.primary,
              onTap: () => onChanged(tipo),
            ),
          ),
        ],
      ],
    );
  }
}

/// Aviso NO bloqueante (fondo de advertencia, no de error) — usado tanto
/// para la discrepancia de tipo de combustible (punto 3g) como para la
/// de total vs. litros×precio (punto 2d, Opción B). Nunca impide guardar.
class _AvisoNoBloqueante extends StatelessWidget {
  const _AvisoNoBloqueante({required this.mensaje});

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppCard(
      floating: true,
      padding: const EdgeInsets.all(12),
      color: colors.warning.withValues(alpha: 0.1),
      child: Row(
        children: [
          Icon(Icons.warning_amber_outlined, color: colors.warning, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              mensaje,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.warning),
            ),
          ),
        ],
      ),
    );
  }
}

class _OpcionTipo extends StatelessWidget {
  const _OpcionTipo({
    required this.icono,
    required this.etiqueta,
    required this.seleccionado,
    required this.color,
    required this.onTap,
  });

  final IconData icono;
  final String etiqueta;
  final bool seleccionado;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: seleccionado ? color : colors.surfaceAlt,
        borderRadius: AppRadii.cardRadius,
        border: seleccionado
            ? Border.all(color: color, width: AppBorders.accent)
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadii.cardRadius,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                Icon(
                  icono,
                  color: seleccionado ? colors.primaryOn : colors.textMuted,
                  size: 28,
                ),
                const SizedBox(height: 6),
                Text(
                  etiqueta,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: seleccionado ? colors.primaryOn : colors.textMuted,
                    fontWeight: seleccionado
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Selector de múltiples fotos — grid de miniaturas + tile para agregar
// ---------------------------------------------------------------------------

class _SelectorFotosMultiple extends StatelessWidget {
  const _SelectorFotosMultiple({
    required this.etiqueta,
    required this.icono,
    required this.rutas,
    required this.maxFotos,
    required this.cargando,
    required this.onAgregar,
    required this.onQuitar,
  });

  final String etiqueta;
  final IconData icono;
  final List<String> rutas;
  final int maxFotos;
  final bool cargando;
  final VoidCallback onAgregar;
  final ValueChanged<int> onQuitar;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final puedeAgregar = rutas.length < maxFotos;

    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: [
        for (var i = 0; i < rutas.length; i++)
          _MiniaturaFoto(ruta: rutas[i], onQuitar: () => onQuitar(i)),
        if (puedeAgregar)
          Semantics(
            button: true,
            label: rutas.isEmpty
                ? 'Tomar foto: $etiqueta'
                : 'Agregar otra foto',
            child: Material(
              color: colors.surfaceAlt,
              borderRadius: AppRadii.cardRadius,
              child: InkWell(
                onTap: cargando ? null : onAgregar,
                borderRadius: AppRadii.cardRadius,
                child: CustomPaint(
                  foregroundPainter: _DashedBorderPainter(
                    color: colors.border,
                    radius: AppRadii.card,
                  ),
                  child: SizedBox(
                    width: 88,
                    height: 88,
                    child: cargando
                        ? const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                rutas.isEmpty
                                    ? icono
                                    : Icons.add_a_photo_outlined,
                                color: colors.primary,
                                size: 24,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                rutas.isEmpty ? 'Tomar foto' : 'Agregar',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(color: colors.textSecondary),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MiniaturaFoto extends StatelessWidget {
  const _MiniaturaFoto({required this.ruta, required this.onQuitar});

  final String ruta;
  final VoidCallback onQuitar;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AppCard(
      floating: true,
      padding: EdgeInsets.zero,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: AppRadii.cardRadius,
            child: Image.file(
              File(ruta),
              width: 88,
              height: 88,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 88,
                height: 88,
                color: colors.success.withValues(alpha: 0.15),
                child: Icon(Icons.image_outlined, color: colors.success),
              ),
            ),
          ),
          Positioned(
            right: -6,
            top: -6,
            child: GestureDetector(
              onTap: onQuitar,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: colors.error,
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.surface, width: 1.5),
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Copiado de `captura_foto_field.dart` (privado ahí, no reutilizable
/// entre archivos) — borde punteado para el tile de "agregar foto".
class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  static const dashWidth = 6.0;
  static const gapWidth = 4.0;
  static const strokeWidth = 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        strokeWidth / 2,
        strokeWidth / 2,
        size.width - strokeWidth,
        size.height - strokeWidth,
      ),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    for (final metric in path.computeMetrics()) {
      var distancia = 0.0;
      while (distancia < metric.length) {
        final siguiente = distancia + dashWidth;
        canvas.drawPath(
          metric.extractPath(distancia, siguiente.clamp(0, metric.length)),
          paint,
        );
        distancia = siguiente + gapWidth;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}

// ---------------------------------------------------------------------------
// Campo de solicitud — toca para abrir selector en BottomSheet
// ---------------------------------------------------------------------------

class _CampoSolicitud extends StatelessWidget {
  const _CampoSolicitud({
    required this.solicitudSeleccionada,
    required this.requerido,
    required this.onTap,
    required this.onLimpiar,
  });

  final SolicitudAutorizacion? solicitudSeleccionada;
  final bool requerido;
  final VoidCallback? onTap;
  final VoidCallback onLimpiar;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final seleccionada = solicitudSeleccionada;

    return Material(
      color: colors.surfaceAlt,
      borderRadius: AppRadii.inputRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.inputRadius,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: 16,
          ),
          decoration: BoxDecoration(
            borderRadius: AppRadii.inputRadius,
            border: requerido && seleccionada == null
                ? Border.all(color: colors.error, width: AppBorders.standard)
                : null,
          ),
          child: Row(
            children: [
              Icon(Icons.tag, color: colors.textMuted, size: 20),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: seleccionada != null
                    ? _SolicitudInfo(solicitud: seleccionada)
                    : Text(
                        requerido
                            ? 'Selecciona una solicitud *'
                            : 'Ninguna / evidencia suelta',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.textMuted,
                        ),
                      ),
              ),
              if (seleccionada != null)
                GestureDetector(
                  onTap: onLimpiar,
                  child: Icon(Icons.close, color: colors.textMuted, size: 18),
                )
              else
                Icon(Icons.chevron_right, color: colors.textMuted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _SolicitudInfo extends StatelessWidget {
  const _SolicitudInfo({required this.solicitud});

  final SolicitudAutorizacion solicitud;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final folio = solicitud.folioAutorizacion ?? solicitud.id.substring(0, 8);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          folio,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(color: colors.primary),
        ),
        const SizedBox(height: 2),
        Text(
          '${solicitud.litrosSolicitados.toStringAsFixed(0)} L · '
          '${solicitud.actividad}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Text(
              formatearFechaCorta(solicitud.creadaEn),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(width: 8),
            EstadoSolicitudBadge(estadoVisual: solicitud.estadoVisual),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// BottomSheet con lista buscable de solicitudes
// ---------------------------------------------------------------------------

class _SelectorSolicitudesSheet extends StatefulWidget {
  const _SelectorSolicitudesSheet({
    required this.solicitudes,
    required this.seleccionada,
    required this.busquedaController,
    required this.onSeleccionar,
  });

  final List<SolicitudAutorizacion> solicitudes;
  final SolicitudAutorizacion? seleccionada;
  final TextEditingController busquedaController;
  final ValueChanged<SolicitudAutorizacion?> onSeleccionar;

  @override
  State<_SelectorSolicitudesSheet> createState() =>
      _SelectorSolicitudesSheetState();
}

class _SelectorSolicitudesSheetState extends State<_SelectorSolicitudesSheet> {
  String _filtro = '';

  @override
  void initState() {
    super.initState();
    _filtro = widget.busquedaController.text;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final filtradas = widget.solicitudes.where((s) {
      if (_filtro.isEmpty) return true;
      final folio = s.folioAutorizacion ?? s.id;
      final buscar = _filtro.toLowerCase();
      return folio.toLowerCase().contains(buscar) ||
          s.actividad.toLowerCase().contains(buscar);
    }).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (ctx, scrollController) {
        return Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Text(
                'Selecciona solicitud',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: TextField(
                controller: widget.busquedaController,
                onChanged: (v) => setState(() => _filtro = v),
                decoration: InputDecoration(
                  hintText: 'Buscar por folio o actividad...',
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  // Opción "Ninguna / evidencia suelta"
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colors.surfaceAlt,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.link_off,
                        color: colors.textMuted,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      'Ninguna / evidencia suelta',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    subtitle: Text(
                      'No asociar a ninguna solicitud',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    trailing: widget.seleccionada == null
                        ? Icon(Icons.check_circle, color: colors.primary)
                        : null,
                    onTap: () => widget.onSeleccionar(null),
                  ),
                  if (filtradas.isNotEmpty) ...[
                    const Divider(height: 1),
                    ...filtradas.map((s) {
                      final folio = s.folioAutorizacion ?? s.id.substring(0, 8);
                      final seleccionada = widget.seleccionada?.id == s.id;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: seleccionada
                                ? colors.primary.withValues(alpha: 0.12)
                                : colors.surfaceAlt,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.receipt_long_outlined,
                            color: seleccionada
                                ? colors.primary
                                : colors.textMuted,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          folio,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: seleccionada
                                    ? colors.primary
                                    : colors.textPrimary,
                              ),
                        ),
                        subtitle: Text(
                          '${formatearFechaCorta(s.creadaEn)} · '
                          '${s.litrosSolicitados.toStringAsFixed(0)} L · '
                          '${s.actividad}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colors.textSecondary),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            EstadoSolicitudBadge(estadoVisual: s.estadoVisual),
                            if (seleccionada) ...[
                              const SizedBox(width: 8),
                              Icon(
                                Icons.check_circle,
                                color: colors.primary,
                                size: 20,
                              ),
                            ],
                          ],
                        ),
                        onTap: () => widget.onSeleccionar(s),
                      );
                    }),
                  ],
                  if (filtradas.isEmpty && _filtro.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    Center(
                      child: Text(
                        'No se encontraron solicitudes',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.textMuted,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
