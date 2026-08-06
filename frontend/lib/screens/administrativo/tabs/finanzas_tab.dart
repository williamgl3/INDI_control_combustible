import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../models/solicitud_autorizacion.dart';
import '../../../theme/app_section_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_radii.dart';
import '../../../widgets/barra_presupuesto.dart';
import '../../../widgets/celda_editable.dart';
import '../../../widgets/formato_numero.dart';
import '../../../widgets/grouped_section.dart';
import '../../../widgets/contenido_responsivo.dart';
import '../../../widgets/stat_tile.dart';
import '../../../widgets/stat_tile_row.dart';
import '../editar_presupuesto_dialog.dart';

/// Pestaña "Finanzas": presupuesto semanal y precios de combustible
/// vigentes — ambos editables directo en la fila (estilo hoja de
/// cálculo), sin abrir un diálogo aparte por cada cambio.
class FinanzasTab extends ConsumerStatefulWidget {
  const FinanzasTab({super.key});

  @override
  ConsumerState<FinanzasTab> createState() => _FinanzasTabState();
}

class _FinanzasTabState extends ConsumerState<FinanzasTab> {
  Future<void> _editarPresupuesto(double valorActual) async {
    final guardado = await EditarPresupuestoDialog.show(
      context,
      valorActual: valorActual,
    );
    if (guardado == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Presupuesto actualizado correctamente.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final repo = ref.watch(operacionesRepositoryProvider);
    ref.watch(operacionesTickProvider);

    final aprobadas = repo.todasLasSolicitudes.where(
      (s) => s.estado == EstadoSolicitud.aprobada,
    );
    final litrosAutorizados = aprobadas.fold(
      0.0,
      (suma, s) => suma + (s.litrosAutorizados ?? s.litrosSolicitados),
    );

    return ContenidoResponsivo(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Finanzas', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            'Presupuesto semanal y precios de combustible vigentes.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: 20),
          GroupedSection(
            header: 'Presupuesto',
            children: [
              GroupedRow(
                titulo: 'Presupuesto semanal total',
                subtitulo: 'Toca el monto para cambiarlo',
                icono: Icons.account_balance_wallet_outlined,
                iconoColor: AppSectionColors.finanzas,
                trailing: InkWell(
                  borderRadius: AppRadii.inputRadius,
                  onTap: () =>
                      _editarPresupuesto(repo.presupuestoSemanalTotal),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          formatearMoneda(repo.presupuestoSemanalTotal),
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(color: colors.primary),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.edit_outlined,
                          size: 16,
                          color: colors.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          BarraPresupuesto(
            restante: repo.presupuestoRestante,
            total: repo.presupuestoSemanalTotal,
            etiquetaSemana: repo.etiquetaSemanaActual,
          ),
          const SizedBox(height: 12),
          StatTileRow(
            tiles: [
              StatTile(
                icono: Icons.local_gas_station_outlined,
                valor: litrosAutorizados.toStringAsFixed(0),
                etiqueta: 'L autorizados',
                color: AppSectionColors.autorizaciones,
              ),
              StatTile(
                icono: Icons.payments_outlined,
                valor: formatearMoneda(repo.presupuestoEjercido),
                etiqueta: 'Ejercido esta semana',
                color: AppSectionColors.finanzas,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Precios de combustible',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          GroupedSection(
            children: [
              for (final p in repo.precios)
                GroupedRow(
                  titulo: p.tipoCombustible,
                  subtitulo: 'Toca el precio para cambiarlo',
                  icono: Icons.local_gas_station_outlined,
                  iconoColor: AppSectionColors.finanzas,
                  trailing: CeldaEditable(
                    valor: p.precioPorLitro,
                    sufijo: ' / L',
                    prefijo: '\$',
                    decimales: 2,
                    estilo: Theme.of(
                      context,
                    ).textTheme.titleSmall?.copyWith(color: colors.primary),
                    onGuardar: (nuevo) async {
                      await repo.actualizarPrecio(
                        tipoCombustible: p.tipoCombustible,
                        nuevoPrecio: nuevo,
                      );
                      ref.read(operacionesTickProvider.notifier).state++;
                    },
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
