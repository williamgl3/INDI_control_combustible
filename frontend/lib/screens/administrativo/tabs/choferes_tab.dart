import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../models/perfil.dart';
import '../../../router/route_paths.dart';
import '../../../theme/app_radii.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/estado_vacio.dart';
import '../../../widgets/stat_tile.dart';

/// Pestaña "Choferes": directorio de choferes registrados, cada uno con
/// acceso a su historial completo (solicitudes + cargas).
class ChoferesTab extends ConsumerStatefulWidget {
  const ChoferesTab({super.key});

  @override
  ConsumerState<ChoferesTab> createState() => _ChoferesTabState();
}

class _ChoferesTabState extends ConsumerState<ChoferesTab> {
  Future<void> _verDetalle(Perfil chofer) async {
    await context.push(RoutePaths.administrativoChoferDetalle, extra: chofer);
    if (mounted) setState(() {}); // por si se editó el tope desde el detalle
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final choferes = ref.watch(authRepositoryProvider).listarChoferes();
    ref.watch(operacionesTickProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Choferes', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text('Directorio de choferes registrados en la obra.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.textSecondary)),
          const SizedBox(height: 20),
          StatTile(icono: Icons.groups_outlined, valor: '${choferes.length}', etiqueta: 'Choferes'),
          const SizedBox(height: 24),
          if (choferes.isEmpty)
            const EstadoVacio(
              icono: Icons.groups_outlined,
              mensaje: 'Aún no hay choferes registrados.',
            )
          else
            ...choferes.map((c) => _ChoferTile(chofer: c, onTap: () => _verDetalle(c))),
        ],
      ),
    );
  }
}

class _ChoferTile extends StatelessWidget {
  const _ChoferTile({required this.chofer, required this.onTap});

  final Perfil chofer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final vehiculo = chofer.vehiculo!;

    return Material(
      color: colors.surface,
      borderRadius: AppRadii.cardRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.cardRadius,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: AppRadii.cardRadius,
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: colors.primary.withValues(alpha: 0.12),
                child: Text(
                  chofer.nombreCompleto.isNotEmpty ? chofer.nombreCompleto[0] : '?',
                  style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(chofer.nombreCompleto, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      '${vehiculo.tipoUnidad} · ${vehiculo.placaONumeroEconomico}',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: colors.textMuted),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: colors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
