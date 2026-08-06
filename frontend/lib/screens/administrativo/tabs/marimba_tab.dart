import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_logger.dart';
import '../../../core/providers.dart';
import '../../../models/recorrido_marimba.dart';
import '../../../theme/app_section_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/contenido_responsivo.dart';
import '../../../widgets/estado_vacio.dart';
import '../../../widgets/ios_segmented_control.dart';

enum _FiltroRecorridos { todos, requierenRevision }

/// Pestaña "Marimba": recorridos (jornadas de despacho) del día/rango,
/// con la conciliación de litros calculada al cierre — separada de
/// Concentrado/Finanzas porque esas miden combustible por vehículo
/// individual, no por jornada con control de merma (ver diseño acordado).
class MarimbaTab extends ConsumerStatefulWidget {
  const MarimbaTab({super.key});

  @override
  ConsumerState<MarimbaTab> createState() => _MarimbaTabState();
}

class _MarimbaTabState extends ConsumerState<MarimbaTab> {
  _FiltroRecorridos _filtro = _FiltroRecorridos.todos;
  bool _cargando = true;
  String? _error;
  List<RecorridoMarimba> _recorridos = [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final recorridos = await ref
          .read(recorridosMarimbaRepositoryProvider)
          .listarRecorridos(
            requiereRevision: _filtro == _FiltroRecorridos.requierenRevision
                ? true
                : null,
          );
      if (mounted) setState(() => _recorridos = recorridos);
    } catch (e) {
      AppLogger.error('MarimbaTab._cargar', e);
      if (mounted) setState(() => _error = 'No pudimos cargar los recorridos.');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ContenidoResponsivo(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Marimba', style: Theme.of(context).textTheme.headlineSmall),
              ),
              IconButton(
                onPressed: _cargando ? null : _cargar,
                icon: const Icon(Icons.refresh),
                tooltip: 'Actualizar',
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Recorridos de despacho a maquinaria en campo y su conciliación de litros.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: 20),
          IosSegmentedControl<_FiltroRecorridos>(
            valor: _filtro,
            opciones: const {
              _FiltroRecorridos.todos: 'Todos',
              _FiltroRecorridos.requierenRevision: 'Requieren revisión',
            },
            onChanged: (f) {
              setState(() => _filtro = f);
              _cargar();
            },
          ),
          const SizedBox(height: 16),
          if (_cargando)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            EstadoVacio(icono: Icons.error_outline, mensaje: _error!)
          else if (_recorridos.isEmpty)
            const EstadoVacio(
              icono: Icons.local_shipping_outlined,
              mensaje: 'No hay recorridos con este filtro.',
            )
          else
            for (final recorrido in _recorridos)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _TarjetaRecorrido(recorrido: recorrido),
              ),
        ],
      ),
    );
  }
}

class _TarjetaRecorrido extends StatelessWidget {
  const _TarjetaRecorrido({required this.recorrido});

  final RecorridoMarimba recorrido;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final r = recorrido;
    return AppCard(
      floating: true,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  r.frente,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (r.requiereRevision) const _BadgeRequiereRevision(),
              if (r.estado == EstadoRecorridoMarimba.abierto) ...[
                const SizedBox(width: 8),
                _BadgeAbierto(),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${r.iniciadoEn.day.toString().padLeft(2, '0')}/'
            '${r.iniciadoEn.month.toString().padLeft(2, '0')}/'
            '${r.iniciadoEn.year}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Dato(
                  etiqueta: 'Salió con',
                  valor: '${r.litrosIniciales.toStringAsFixed(0)} L',
                ),
              ),
              Expanded(
                child: _Dato(
                  etiqueta: 'Despachado',
                  valor: r.litrosDespachadosTotal == null
                      ? '—'
                      : '${r.litrosDespachadosTotal!.toStringAsFixed(0)} L',
                ),
              ),
              Expanded(
                child: _Dato(
                  etiqueta: 'Existencia',
                  valor: r.existenciaCalculada == null
                      ? '—'
                      : '${r.existenciaCalculada!.toStringAsFixed(0)} L',
                  destacado: r.requiereRevision,
                ),
              ),
            ],
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
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colors.textMuted),
        ),
        const SizedBox(height: 2),
        Text(
          valor,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: destacado ? colors.warning : colors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _BadgeRequiereRevision extends StatelessWidget {
  const _BadgeRequiereRevision();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colors.warning.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'REQUIERE REVISIÓN',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colors.warning,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _BadgeAbierto extends StatelessWidget {
  const _BadgeAbierto();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppSectionColors.autorizaciones.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'ABIERTO',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppSectionColors.autorizaciones,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
