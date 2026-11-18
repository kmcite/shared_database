import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_database/shared_database.dart';

import '../../utils/app_accent.dart';
import '../../utils/package_label.dart';
import '../../widgets/common.dart';
import '../../widgets/liquid.dart';
import '../app_collections/app_collections_page.dart';

/// Overview “Apps” block: share strip + treemap / stacked mosaic tiles.
class AppsOverviewSection extends StatelessWidget {
  const AppsOverviewSection({
    super.key,
    required this.apps,
    required this.totalRecords,
  });

  final List<AppDataInfo> apps;
  final int totalRecords;

  @override
  Widget build(BuildContext context) {
    if (apps.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: EmptyState(
          icon: Icons.apps_outlined,
          message:
              'No apps have written data yet.\n'
              'Install a client and call put() on a collection.',
        ),
      );
    }

    final sorted = [...apps]..sort((a, b) => b.recordCount.compareTo(a.recordCount));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DatabaseShareStrip(apps: sorted, totalRecords: totalRecords),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 720;
            if (wide) {
              return _AppsTreemap(
                apps: sorted,
                totalRecords: totalRecords,
                height: _treemapHeight(sorted.length),
              );
            }
            return _AppsStack(
              apps: sorted,
              totalRecords: totalRecords,
            );
          },
        ),
      ],
    );
  }

  static double _treemapHeight(int count) {
    if (count <= 1) return 168;
    if (count <= 3) return 220;
    if (count <= 6) return 280;
    return 320;
  }
}

class _DatabaseShareStrip extends StatelessWidget {
  const _DatabaseShareStrip({
    required this.apps,
    required this.totalRecords,
  });

  final List<AppDataInfo> apps;
  final int totalRecords;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final total = totalRecords == 0 ? 1 : totalRecords;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '${apps.length} apps',
              style: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 8),
            Text(
              '· $totalRecords records total',
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            height: 12,
            child: Row(
              children: [
                for (final app in apps)
                  Expanded(
                    flex: math.max(1, app.recordCount),
                    child: Tooltip(
                      message:
                          '${packageLabel(app.packageName)}\n'
                          '${app.recordCount} records · '
                          '${(100 * app.recordCount / total).toStringAsFixed(1)}%',
                      child: Container(
                        color: appAccent(app.packageName),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            for (final app in apps.take(6))
              _ShareLegendDot(
                color: appAccent(app.packageName),
                label: packageLabel(app.packageName),
                percent: app.recordCount / total,
              ),
            if (apps.length > 6)
              Text(
                '+${apps.length - 6} more',
                style: text.labelSmall?.copyWith(color: scheme.outline),
              ),
          ],
        ),
      ],
    );
  }
}

class _ShareLegendDot extends StatelessWidget {
  const _ShareLegendDot({
    required this.color,
    required this.label,
    required this.percent,
  });

  final Color color;
  final String label;
  final double percent;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          '$label ${(percent * 100).toStringAsFixed(0)}%',
          style: text.labelSmall,
        ),
      ],
    );
  }
}

/// Wide layout: nested flex rows weighted by record count.
class _AppsTreemap extends StatelessWidget {
  const _AppsTreemap({
    required this.apps,
    required this.totalRecords,
    required this.height,
  });

  final List<AppDataInfo> apps;
  final int totalRecords;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (apps.length == 1) {
      return SizedBox(
        height: height,
        child: _AppMosaicTile(
          app: apps.first,
          totalRecords: totalRecords,
          featured: true,
          dense: false,
        ),
      );
    }

    final lead = apps.first;
    final rest = apps.sublist(1);
    final restTotal = math.max(1, rest.fold(0, (s, a) => s + a.recordCount));

    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: math.max(1, lead.recordCount),
            child: _AppMosaicTile(
              app: lead,
              totalRecords: totalRecords,
              featured: true,
              dense: false,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: restTotal,
            child: Column(
              children: _rowsFor(rest),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _rowsFor(List<AppDataInfo> list) {
    if (list.isEmpty) return const [];
    final rows = <Widget>[];
    for (var i = 0; i < list.length; i += 2) {
      final pair = list.skip(i).take(2).toList();
      rows.add(
        Expanded(
          child: Row(
            children: [
              for (var j = 0; j < pair.length; j++) ...[
                if (j > 0) const SizedBox(width: 8),
                Expanded(
                  flex: math.max(1, pair[j].recordCount),
                  child: _AppMosaicTile(
                    app: pair[j],
                    totalRecords: totalRecords,
                    featured: false,
                    dense: true,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
      if (i + 2 < list.length) {
        rows.add(const SizedBox(height: 8));
      }
    }
    return rows;
  }
}

/// Narrow layout: hero tile + horizontal carousel of the rest.
class _AppsStack extends StatelessWidget {
  const _AppsStack({
    required this.apps,
    required this.totalRecords,
  });

  final List<AppDataInfo> apps;
  final int totalRecords;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AppMosaicTile(
          app: apps.first,
          totalRecords: totalRecords,
          featured: true,
          dense: false,
        ),
        if (apps.length > 1) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 132,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: apps.length - 1,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final app = apps[i + 1];
                return SizedBox(
                  width: 200,
                  child: _AppMosaicTile(
                    app: app,
                    totalRecords: totalRecords,
                    featured: false,
                    dense: true,
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _AppMosaicTile extends StatefulWidget {
  const _AppMosaicTile({
    required this.app,
    required this.totalRecords,
    required this.featured,
    required this.dense,
  });

  final AppDataInfo app;
  final int totalRecords;
  final bool featured;
  final bool dense;

  @override
  State<_AppMosaicTile> createState() => _AppMosaicTileState();
}

class _AppMosaicTileState extends State<_AppMosaicTile> {
  bool _pressed = false;

  void _open() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) =>
            AppCollectionsPage(packageName: widget.app.packageName),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final accent = appAccent(app.packageName);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final total = widget.totalRecords == 0 ? 1 : widget.totalRecords;
    final share = app.recordCount / total;
    final topCollections = [...app.collections]
      ..sort((a, b) => b.recordCount.compareTo(a.recordCount));

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: _open,
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: Liquid.panel(
            context,
            radius: widget.featured ? 22 : 18,
            tint: Color.alphaBlend(
              accent.withValues(alpha: 0.12),
              scheme.surfaceContainerLow,
            ),
            elevated: widget.featured,
            strength: widget.featured ? 1.2 : 0.8,
          ).copyWith(
            border: Border.all(
              color: accent.withValues(alpha: widget.featured ? 0.35 : 0.2),
              width: widget.featured ? 1.2 : 0.8,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -24,
                top: -24,
                child: Container(
                  width: widget.featured ? 120 : 88,
                  height: widget.featured ? 120 : 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        accent.withValues(alpha: 0.22),
                        accent.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(widget.dense ? 12 : 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ShareRing(
                          accent: accent,
                          share: share,
                          initial: packageInitial(app.packageName),
                          size: widget.featured ? 52 : 44,
                          stroke: widget.featured ? 4.5 : 3.5,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                packageLabel(app.packageName),
                                style: text.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                app.packageName,
                                style: text.labelSmall?.copyWith(
                                  fontFamily: 'monospace',
                                  color: scheme.onSurfaceVariant,
                                  fontSize: 10,
                                ),
                                maxLines: widget.dense ? 1 : 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.north_east_rounded,
                          size: 18,
                          color: scheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                    SizedBox(height: widget.dense ? 10 : 14),
                    Row(
                      children: [
                        _StatChip(
                          icon: Icons.folder_outlined,
                          value: '${app.collectionCount}',
                          label: 'coll',
                          accent: accent,
                        ),
                        const SizedBox(width: 8),
                        _StatChip(
                          icon: Icons.description_outlined,
                          value: '${app.recordCount}',
                          label: 'rec',
                          accent: accent,
                        ),
                        const Spacer(),
                        Text(
                          '${(share * 100).toStringAsFixed(share < 0.01 ? 1 : 0)}%',
                          style: text.labelLarge?.copyWith(
                            color: accent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    if (!widget.dense || widget.featured) ...[
                      const SizedBox(height: 12),
                      _CollectionRibbon(
                        collections: topCollections,
                        accent: accent,
                        maxVisible: widget.featured ? 5 : 3,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShareRing extends StatelessWidget {
  const _ShareRing({
    required this.accent,
    required this.share,
    required this.initial,
    required this.size,
    required this.stroke,
  });

  final Color accent;
  final double share;
  final String initial;
  final double size;
  final double stroke;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: share.clamp(0.0, 1.0),
            strokeWidth: stroke,
            backgroundColor: scheme.surfaceContainerHighest,
            color: accent,
            strokeCap: StrokeCap.round,
          ),
          Text(
            initial,
            style: TextStyle(
              fontSize: size * 0.34,
              fontWeight: FontWeight.w800,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.value,
    required this.label,
    required this.accent,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: accent),
          const SizedBox(width: 4),
          Text(
            value,
            style: text.labelMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 2),
          Text(label, style: text.labelSmall),
        ],
      ),
    );
  }
}

class _CollectionRibbon extends StatelessWidget {
  const _CollectionRibbon({
    required this.collections,
    required this.accent,
    required this.maxVisible,
  });

  final List<CollectionInfo> collections;
  final Color accent;
  final int maxVisible;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    if (collections.isEmpty) {
      return Text(
        'No collections yet',
        style: text.bodySmall?.copyWith(color: scheme.outline),
      );
    }

    final visible = collections.take(maxVisible).toList();
    final overflow = collections.length - visible.length;

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final c in visible)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.7),
              ),
            ),
            child: Text(
              '${c.name} · ${c.recordCount}',
              style: text.labelSmall?.copyWith(fontFamily: 'monospace'),
            ),
          ),
        if (overflow > 0)
          Text(
            '+$overflow',
            style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
      ],
    );
  }
}
