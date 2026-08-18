import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/catalogos_vehiculo.dart';
import '../../core/cola_solicitudes_offline.dart';
import '../../core/providers.dart';
import '../../core/session_provider.dart';
import '../../data/api_client.dart';
import '../../models/despacho_marimba.dart';
import '../../models/recorrido_marimba.dart';
import '../../models/vehiculo.dart';
import '../../router/route_paths.dart';
import '../../theme/app_breakpoints.dart';
import '../../theme/app_status_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_elevated_button.dart';
import '../../widgets/app_status_chip.dart';
import '../../widgets/aviso_error.dart';
import '../../widgets/captura_foto_field.dart';
import '../../widgets/chofer_operation_scaffold.dart';
import '../../widgets/selector_vehiculo.dart';
import '../../widgets/stepper_numerico.dart';

/// Jornada de despacho de la marimba: abrir un recorrido, agregar N
/// despachos en una sola pantalla (sin navegar por cada máquina, ver
/// diseño acordado del flujo de marimba) y cerrarlo con conciliación de
/// litros. Es la única captura operativa de despachos de Marimba/Pipa.
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
  String? _tipoCombustible;
  final _frenteController = TextEditingController();
  double _kmInicio = 0;
  double _horasEquipoMenorInicio = 0;
  bool _abriendo = false;
  String? _errorAbrir;
  final _saldosPorCombustible = <String, double>{};
  bool _cargandoSaldos = false;

  // --- Recorrido activo (una vez abierto) ---
  String? _recorridoIdLocal;
  bool _recorridoPendiente = false;
  String? _frenteActivo;
  double _litrosInicialesActivos = 0;
  final _despachos = <DespachoMarimba>[];
  final _destinosRecientes = <String>[];

  // --- Agregar despacho ---
  Vehiculo? _destino;
  final _operadorController = TextEditingController();
  bool _cantidadDeclarada = false;
  double _litrosDeclarados = 0;
  double _horometro = 0;
  double _medidorInicial = 0;
  double _medidorFinal = 0;
  String? _fotoHorometroPath;
  String? _fotoMedidorPath;
  String? _fotoEvidenciaPath;
  String? _fotoEnCarga;
  bool _agregando = false;
  String? _errorDespacho;

  bool _cerrando = false;

  @override
  void dispose() {
    _frenteController.dispose();
    _operadorController.dispose();
    super.dispose();
  }

  double get _litrosDespachados =>
      _despachos.fold(0.0, (suma, d) => suma + d.litrosSuministrados);

  double get _existenciaEstimada =>
      _litrosInicialesActivos - _litrosDespachados;

  double get _litrosCapturados {
    if (_cantidadDeclarada) return _litrosDeclarados;
    final inicial = (_medidorInicial * 1000).round();
    final finalLectura = (_medidorFinal * 1000).round();
    return (finalLectura - inicial) / 1000;
  }

  Future<void> _cargarSaldos(Vehiculo marimba) async {
    setState(() {
      _cargandoSaldos = true;
      _saldosPorCombustible.clear();
    });
    try {
      final repo = ref.read(recorridosMarimbaRepositoryProvider);
      for (final combustible in tiposCombustibleVehiculo) {
        _saldosPorCombustible[combustible] = await repo.saldoDeMarimba(
          marimba.id,
          combustible,
        );
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _errorAbrir = error.mensaje);
    } finally {
      if (mounted) setState(() => _cargandoSaldos = false);
    }
  }

  Future<void> _abrirRecorrido() async {
    if (_abriendo) return;
    if (_marimba == null) {
      setState(() => _errorAbrir = 'Elige qué marimba vas a usar.');
      return;
    }
    if (_frenteController.text.trim().isEmpty) {
      setState(() => _errorAbrir = 'Indica el frente donde vas a operar.');
      return;
    }
    if (_tipoCombustible == null) {
      setState(() => _errorAbrir = 'Selecciona el combustible transportado.');
      return;
    }
    setState(() {
      _abriendo = true;
      _errorAbrir = null;
    });

    final marimba = _marimba!;
    final frente = _frenteController.text.trim();
    try {
      final recorrido = await ref
          .read(recorridosMarimbaRepositoryProvider)
          .abrirRecorrido(
            marimbaId: marimba.id,
            tipoCombustible: _tipoCombustible!,
            frente: frente,
            kmInicio: _kmInicio > 0 ? _kmInicio : null,
            horasEquipoMenorInicio: _horasEquipoMenorInicio > 0
                ? _horasEquipoMenorInicio
                : null,
          );
      if (!mounted) return;
      setState(() {
        _recorridoIdLocal = recorrido.id;
        _recorridoPendiente = false;
        _frenteActivo = frente;
        _litrosInicialesActivos = recorrido.litrosIniciales;
      });
    } on ApiException catch (error) {
      if (error.status == null) {
        final perfil = ref.read(sessionProvider);
        if (perfil == null || !perfil.esSupervisor) {
          if (mounted) {
            setState(() => _errorAbrir = 'La sesión ya no es válida.');
          }
          return;
        }
        final ahora = DateTime.now();
        final idLocal = 'recorrido-${ahora.microsecondsSinceEpoch}';
        await ref
            .read(colaRecorridosMarimbaOfflineProvider)
            .agregar(
              RecorridoMarimbaPendienteOffline(
                idLocal: idLocal,
                usuarioId: perfil.id,
                rol: perfil.rol.name,
                marimbaId: marimba.id,
                tipoCombustible: _tipoCombustible!,
                frente: frente,
                kmInicio: _kmInicio > 0 ? _kmInicio : null,
                horasEquipoMenorInicio: _horasEquipoMenorInicio > 0
                    ? _horasEquipoMenorInicio
                    : null,
                creadaEn: ahora,
              ),
            );
        if (mounted) {
          setState(() {
            _recorridoIdLocal = idLocal;
            _recorridoPendiente = true;
            _frenteActivo = frente;
          });
        }
      } else if (mounted) {
        setState(() => _errorAbrir = error.mensaje);
      }
    } finally {
      if (mounted) setState(() => _abriendo = false);
    }
  }

  Future<void> _agregarDespacho() async {
    if (_agregando) return;
    if (_destino == null) {
      setState(
        () =>
            _errorDespacho = 'Selecciona una maquinaria aprobada del catálogo.',
      );
      return;
    }
    if (_operadorController.text.trim().isEmpty) {
      setState(() => _errorDespacho = 'Indica quién recibió el combustible.');
      return;
    }
    final litros = _litrosCapturados;
    if (!_cantidadDeclarada && _medidorFinal < _medidorInicial) {
      setState(
        () =>
            _errorDespacho = 'El medidor final no puede ser menor al inicial.',
      );
      return;
    }
    if (litros <= 0) {
      setState(() => _errorDespacho = 'Los litros deben ser mayores a cero.');
      return;
    }
    if (_litrosInicialesActivos > 0 && litros > _existenciaEstimada) {
      setState(
        () => _errorDespacho = 'Saldo insuficiente para este combustible.',
      );
      return;
    }
    if (_horometro < 0 || _fotoHorometroPath == null) {
      setState(
        () => _errorDespacho =
            'Captura el horómetro y su evidencia antes del despacho.',
      );
      return;
    }
    if (!_cantidadDeclarada && _fotoMedidorPath == null) {
      setState(() => _errorDespacho = 'La foto del medidor es obligatoria.');
      return;
    }
    if (_fotoEvidenciaPath == null) {
      setState(
        () => _errorDespacho = 'La evidencia del despacho es obligatoria.',
      );
      return;
    }

    setState(() {
      _agregando = true;
      _errorDespacho = null;
    });

    final destino = _destino!;
    final operador = _operadorController.text.trim();

    try {
      if (_recorridoPendiente) throw ApiException('Sin conexión.');
      final despacho = await ref
          .read(recorridosMarimbaRepositoryProvider)
          .agregarDespacho(
            recorridoId: _recorridoIdLocal!,
            tipoCombustible: _tipoCombustible!,
            vehiculoDestinoId: destino.id,
            operadorTexto: operador,
            horometro: _horometro,
            fotoHorometroPath: _fotoHorometroPath!,
            litrosDeclarados: _cantidadDeclarada ? litros : null,
            medidorInicial: _cantidadDeclarada ? null : _medidorInicial,
            medidorFinal: _cantidadDeclarada ? null : _medidorFinal,
            fotoMedidorPath: _cantidadDeclarada ? null : _fotoMedidorPath,
            fotoEvidenciaPath: _fotoEvidenciaPath,
            ubicacion: _frenteActivo,
          );
      final etiquetaDestino = destino.modelo ?? destino.etiquetaUnidad;
      if (!mounted) return;
      setState(() {
        _despachos.add(despacho);
        _destinosRecientes.remove(etiquetaDestino);
        _destinosRecientes.insert(0, etiquetaDestino);
        if (_destinosRecientes.length > 5) _destinosRecientes.removeLast();

        _destino = null;
        _litrosDeclarados = 0;
        _horometro = 0;
        _medidorInicial = 0;
        _medidorFinal = 0;
        _fotoHorometroPath = null;
        _fotoMedidorPath = null;
        _fotoEvidenciaPath = null;
      });
    } on ApiException catch (error) {
      if (error.status == null) {
        final perfil = ref.read(sessionProvider);
        if (perfil == null || !perfil.esSupervisor) {
          if (mounted) {
            setState(() => _errorDespacho = 'La sesión ya no es válida.');
          }
          return;
        }
        final ahora = DateTime.now();
        final colaRecorridos = ref.read(colaRecorridosMarimbaOfflineProvider);
        final existeEncabezado = (await colaRecorridos.leer()).any(
          (r) => r.idLocal == _recorridoIdLocal,
        );
        if (!existeEncabezado) {
          await colaRecorridos.agregar(
            RecorridoMarimbaPendienteOffline(
              idLocal: _recorridoIdLocal!,
              usuarioId: perfil.id,
              rol: perfil.rol.name,
              marimbaId: _marimba!.id,
              tipoCombustible: _tipoCombustible!,
              frente: _frenteActivo!,
              creadaEn: ahora,
              idServidor: _recorridoIdLocal,
            ),
          );
        }
        await ref
            .read(colaDespachosMarimbaOfflineProvider)
            .agregar(
              DespachoMarimbaPendienteOffline(
                idLocal: 'despacho-${ahora.microsecondsSinceEpoch}',
                recorridoIdLocal: _recorridoIdLocal!,
                usuarioId: perfil.id,
                rol: perfil.rol.name,
                vehiculoDestinoId: destino.id,
                tipoCombustible: _tipoCombustible!,
                operadorTexto: operador,
                horometro: _horometro,
                fotoHorometroPath: _fotoHorometroPath!,
                litrosDeclarados: _cantidadDeclarada ? litros : null,
                medidorInicial: _cantidadDeclarada ? null : _medidorInicial,
                medidorFinal: _cantidadDeclarada ? null : _medidorFinal,
                fotoMedidorPath: _cantidadDeclarada ? null : _fotoMedidorPath,
                fotoEvidenciaPath: _fotoEvidenciaPath,
                ubicacion: _frenteActivo,
                creadaEn: ahora,
              ),
            );
        if (mounted) {
          setState(() {
            _despachos.add(
              DespachoMarimba(
                id: 'local-${ahora.microsecondsSinceEpoch}',
                marimbaId: _marimba!.id,
                vehiculoDestinoId: destino.id,
                destinoTexto: destino.modelo ?? destino.etiquetaUnidad,
                operadorTexto: operador,
                litrosSuministrados: litros,
                registradoPor: perfil.id,
                creadoEn: ahora,
                recorridoId: _recorridoIdLocal,
                horometro: _horometro,
                medidorInicial: _cantidadDeclarada ? null : _medidorInicial,
                medidorFinal: _cantidadDeclarada ? null : _medidorFinal,
                cantidadDeclarada: _cantidadDeclarada,
                tipoCombustible: _tipoCombustible,
              ),
            );
            _errorDespacho = 'Despacho guardado para sincronizar.';
          });
        }
      } else if (mounted) {
        setState(() => _errorDespacho = error.mensaje);
      }
    } finally {
      if (mounted) setState(() => _agregando = false);
    }
  }

  Future<void> _tomarFoto(String tipo) async {
    setState(() => _fotoEnCarga = tipo);
    final ruta = await ref.read(fotoPickerProvider).tomarFoto();
    if (mounted) {
      setState(() {
        if (ruta != null) {
          if (tipo == 'horometro') _fotoHorometroPath = ruta;
          if (tipo == 'medidor') _fotoMedidorPath = ruta;
          if (tipo == 'evidencia') _fotoEvidenciaPath = ruta;
        }
        _fotoEnCarga = null;
      });
    }
  }

  Future<void> _cerrarRecorrido() async {
    final resultado = await _DialogoCerrarRecorrido.show(context, ref: ref);
    if (resultado == null) return;

    setState(() => _cerrando = true);
    try {
      if (_recorridoPendiente) throw ApiException('Sin conexión.');
      final recorridoCerrado = await ref
          .read(recorridosMarimbaRepositoryProvider)
          .cerrarRecorrido(
            recorridoId: _recorridoIdLocal!,
            kmCierre: resultado.kmCierre,
            horasEquipoMenorCierre: resultado.horasEquipoMenorCierre,
            fotoCierrePath: resultado.fotoCierrePath,
            fotoNivelPath: resultado.fotoNivelPath,
            existenciaFisica: resultado.existenciaFisica,
            observaciones: resultado.observaciones,
          );
      if (!mounted) return;
      await _DialogoConciliacion.show(context, recorrido: recorridoCerrado);
      if (mounted) context.go(RoutePaths.chofer);
    } on ApiException catch (error) {
      if (error.status == null) {
        final perfil = ref.read(sessionProvider);
        if (perfil == null || !perfil.esSupervisor) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('La sesión ya no es válida.')),
            );
          }
          return;
        }
        final ahora = DateTime.now();
        final colaRecorridos = ref.read(colaRecorridosMarimbaOfflineProvider);
        final existeEncabezado = (await colaRecorridos.leer()).any(
          (r) => r.idLocal == _recorridoIdLocal,
        );
        if (!existeEncabezado) {
          await colaRecorridos.agregar(
            RecorridoMarimbaPendienteOffline(
              idLocal: _recorridoIdLocal!,
              usuarioId: perfil.id,
              rol: perfil.rol.name,
              marimbaId: _marimba!.id,
              tipoCombustible: _tipoCombustible!,
              frente: _frenteActivo!,
              creadaEn: ahora,
              idServidor: _recorridoIdLocal,
            ),
          );
        }
        await ref
            .read(colaCierresRecorridoMarimbaOfflineProvider)
            .agregar(
              CierreRecorridoMarimbaPendienteOffline(
                idLocal: 'cierre-${ahora.microsecondsSinceEpoch}',
                recorridoIdLocal: _recorridoIdLocal!,
                usuarioId: perfil.id,
                rol: perfil.rol.name,
                kmCierre: resultado.kmCierre,
                horasEquipoMenorCierre: resultado.horasEquipoMenorCierre,
                fotoCierrePath: resultado.fotoCierrePath,
                fotoNivelPath: resultado.fotoNivelPath,
                existenciaFisica: resultado.existenciaFisica,
                observaciones: resultado.observaciones,
                creadaEn: ahora,
              ),
            );
        if (mounted) context.go(RoutePaths.chofer);
      } else if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.mensaje)));
      }
    } finally {
      if (mounted) setState(() => _cerrando = false);
    }
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
          onChanged: (valor) {
            final seleccion = marimbas.where((m) => m.id == valor).firstOrNull;
            setState(() {
              _marimba = seleccion;
              _tipoCombustible = null;
            });
            if (seleccion != null) {
              _cargarSaldos(seleccion);
            }
          },
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _tipoCombustible,
          decoration: const InputDecoration(
            labelText: 'Combustible transportado',
            prefixIcon: Icon(Icons.local_gas_station_outlined),
          ),
          items: tiposCombustibleVehiculo
              .map(
                (combustible) => DropdownMenuItem(
                  value: combustible,
                  child: Text(combustible),
                ),
              )
              .toList(growable: false),
          onChanged: _abriendo
              ? null
              : (valor) => setState(() => _tipoCombustible = valor),
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
        const Text(
          'La existencia inicial se obtiene del inventario confirmado por el servidor.',
        ),
        const SizedBox(height: 8),
        if (_cargandoSaldos)
          const LinearProgressIndicator()
        else if (_marimba != null)
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: tiposCombustibleVehiculo
                .map(
                  (tipo) => Chip(
                    label: Text(
                      '$tipo: ${_saldosPorCombustible[tipo]?.toStringAsFixed(2) ?? 'No disponible'} L',
                    ),
                  ),
                )
                .toList(growable: false),
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
                      .map((etiqueta) => Chip(label: Text(etiqueta)))
                      .toList(),
                ),
                const SizedBox(height: 12),
              ],
              SelectorVehiculo(
                vehiculoSeleccionado: _destino,
                filtroTipoUnidad: 'Maquinaria',
                filtroUbicacion: _frenteActivo,
                onSeleccionar: (v) => setState(() => _destino = v),
              ),
              const Text(
                'Si la maquinaria no aparece, repórtala para aprobación administrativa antes de despachar.',
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
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Cantidad medida')),
                  ButtonSegment(value: true, label: Text('Cantidad declarada')),
                ],
                selected: {_cantidadDeclarada},
                onSelectionChanged: (seleccion) =>
                    setState(() => _cantidadDeclarada = seleccion.first),
              ),
              const SizedBox(height: 16),
              StepperNumerico(
                etiqueta: 'Horómetro de la máquina',
                valor: _horometro,
                sufijo: 'h',
                paso: 1,
                decimales: 1,
                onChanged: (v) => setState(() => _horometro = v),
              ),
              const SizedBox(height: 16),
              CapturaFotoField(
                etiqueta: 'Foto del horómetro',
                icono: Icons.photo_camera_outlined,
                rutaFoto: _fotoHorometroPath,
                cargando: _fotoEnCarga == 'horometro',
                onTomarFoto: () => _tomarFoto('horometro'),
              ),
              const SizedBox(height: 16),
              if (_cantidadDeclarada)
                StepperNumerico(
                  etiqueta: 'Litros declarados',
                  valor: _litrosDeclarados,
                  sufijo: 'L',
                  paso: 1,
                  decimales: 2,
                  onChanged: (v) => setState(() => _litrosDeclarados = v),
                )
              else ...[
                StepperNumerico(
                  etiqueta: 'Medidor inicial',
                  valor: _medidorInicial,
                  sufijo: 'L',
                  paso: 1,
                  decimales: 2,
                  onChanged: (v) => setState(() => _medidorInicial = v),
                ),
                const SizedBox(height: 12),
                StepperNumerico(
                  etiqueta: 'Medidor final',
                  valor: _medidorFinal,
                  sufijo: 'L',
                  paso: 1,
                  decimales: 2,
                  onChanged: (v) => setState(() => _medidorFinal = v),
                ),
                const SizedBox(height: 8),
                Text(
                  'Litros calculados: ${_litrosCapturados.toStringAsFixed(2)} L',
                ),
                const SizedBox(height: 12),
                CapturaFotoField(
                  etiqueta: 'Foto del medidor',
                  icono: Icons.speed_outlined,
                  rutaFoto: _fotoMedidorPath,
                  cargando: _fotoEnCarga == 'medidor',
                  onTomarFoto: () => _tomarFoto('medidor'),
                ),
              ],
              const SizedBox(height: 16),
              CapturaFotoField(
                etiqueta: 'Evidencia del despacho',
                icono: Icons.local_gas_station_outlined,
                rutaFoto: _fotoEvidenciaPath,
                cargando: _fotoEnCarga == 'evidencia',
                onTomarFoto: () => _tomarFoto('evidencia'),
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
    final esMovil = AppBreakpoints.isMobile(MediaQuery.sizeOf(context).width);
    final datos = [
      _Dato(
        etiqueta: 'Salió con',
        valor: '${litrosIniciales.toStringAsFixed(0)} L',
      ),
      _Dato(
        etiqueta: 'Despachado',
        valor: '${litrosDespachados.toStringAsFixed(0)} L',
      ),
      _Dato(
        etiqueta: 'Existencia estimada',
        valor: '${existenciaEstimada.toStringAsFixed(0)} L',
        destacado: true,
      ),
    ];
    return AppCard(
      floating: true,
      color: colors.info.withValues(alpha: 0.08),
      padding: const EdgeInsets.all(16),
      child: esMovil
          ? Wrap(
              spacing: 24,
              runSpacing: 16,
              children: datos
                  .map((dato) => SizedBox(width: 132, child: dato))
                  .toList(growable: false),
            )
          : Row(
              children: datos
                  .map((dato) => Expanded(child: dato))
                  .toList(growable: false),
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
    final clasificacion = despacho.cantidadDeclarada;
    final etiqueta = clasificacion == true
        ? 'Cantidad declarada'
        : clasificacion == false
        ? 'Cantidad medida'
        : 'Registro histórico';
    final icono = clasificacion == true
        ? Icons.edit_note_outlined
        : clasificacion == false
        ? Icons.speed_outlined
        : Icons.history_outlined;
    final color = clasificacion == true
        ? context.statusColors.declared
        : clasificacion == false
        ? context.statusColors.measured
        : context.statusColors.unconfigured;
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 12,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 180, maxWidth: 420),
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
          AppStatusChip(label: etiqueta, icon: icono, color: color),
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
    required this.fotoNivelPath,
    required this.existenciaFisica,
    this.observaciones,
  });

  final double? kmCierre;
  final double? horasEquipoMenorCierre;
  final String fotoCierrePath;
  final String fotoNivelPath;
  final double existenciaFisica;
  final String? observaciones;
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
  double _existenciaFisica = 0;
  final _observacionesController = TextEditingController();
  String? _fotoCierrePath;
  String? _fotoNivelPath;
  String? _fotoEnCarga;
  String? _error;

  @override
  void dispose() {
    _observacionesController.dispose();
    super.dispose();
  }

  Future<void> _tomarFoto(String tipo) async {
    setState(() => _fotoEnCarga = tipo);
    final ruta = await ref.read(fotoPickerProvider).tomarFoto();
    if (mounted) {
      setState(() {
        if (ruta != null) {
          if (tipo == 'cierre') _fotoCierrePath = ruta;
          if (tipo == 'nivel') _fotoNivelPath = ruta;
        }
        _fotoEnCarga = null;
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
          StepperNumerico(
            etiqueta: 'Existencia física al cierre',
            valor: _existenciaFisica,
            sufijo: 'L',
            paso: 1,
            decimales: 2,
            onChanged: (v) => setState(() => _existenciaFisica = v),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _observacionesController,
            decoration: const InputDecoration(
              labelText: 'Observaciones de conciliación',
              hintText: 'Obligatorias si existe una diferencia',
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          CapturaFotoField(
            etiqueta: 'Foto de cierre (obligatoria)',
            icono: Icons.photo_camera_outlined,
            rutaFoto: _fotoCierrePath,
            cargando: _fotoEnCarga == 'cierre',
            onTomarFoto: () => _tomarFoto('cierre'),
          ),
          const SizedBox(height: 16),
          CapturaFotoField(
            etiqueta: 'Foto del nivel final (obligatoria)',
            icono: Icons.water_drop_outlined,
            rutaFoto: _fotoNivelPath,
            cargando: _fotoEnCarga == 'nivel',
            onTomarFoto: () => _tomarFoto('nivel'),
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
            if (_fotoCierrePath == null || _fotoNivelPath == null) {
              setState(
                () => _error = 'Las fotos de cierre y nivel son obligatorias.',
              );
              return;
            }
            Navigator.of(context).pop(
              _ResultadoCierre(
                kmCierre: _kmCierre > 0 ? _kmCierre : null,
                horasEquipoMenorCierre: _horasEquipoMenorCierre > 0
                    ? _horasEquipoMenorCierre
                    : null,
                fotoCierrePath: _fotoCierrePath!,
                fotoNivelPath: _fotoNivelPath!,
                existenciaFisica: _existenciaFisica,
                observaciones: _observacionesController.text.trim().isEmpty
                    ? null
                    : _observacionesController.text.trim(),
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
