import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_database/shared_database.dart';

import '../../utils/app_accent.dart';
import '../../utils/date_format.dart';
import '../../utils/package_label.dart';
import '../../widgets/common.dart';
import '../../widgets/liquid.dart';
import '../collection/collection_page.dart';

/// Recently created collections — timeline strip + mosaic cards.
class RecentCollectionsSection extends StatelessWidget {
  const RecentCollectionsSection({
    super.key,
    required this.collections,
    required this.totalRecords,
  });

  final List<CollectionInfo> collections;
  final int totalRecords;

  @override
  Widget build(BuildContext context) {
    if (collections.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: EmptyState(
          icon: Icons.folder_off_outlined,
          message: 'No collections yet.\nCreate one to get started.',
        ),
      );
    }

    final sorted = [...collections]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RecencyTimelineStrip(collections: sorted),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 720;
            if (wide) {
              return _RecentWideMosaic(
                collections: sorted,
                totalRecords: totalRecords,
              );
            }
            return _RecentVerticalTimeline(
              collections: sorted,
              totalRecords: totalRecords,
            );
          },
        ),
      ],
    );
  }
}

class _RecencyTimelineStrip extends StatelessWidget {
  const _RecencyTimelineStrip({required this.collections});

  final List<CollectionInfo> collections;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final newest = collections.first.createdAt;
    final oldest = collections.last.createdAt;
    final span = math.max(1, newest - oldest);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${collections.length} newest · sorted by created',
          style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 36,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 8,
                    right: 8,
                    top: 16,
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        gradient: LinearGradient(
                          colors: [
                            scheme.outlineVariant.withValues(alpha: 0.3),
                            scheme.primary.withValues(alpha: 0.5),
                          ],
                        ),
                      ),
                    ),
                  ),
                  for (var i = 0; i < collections.length; i++)
                    _TimelineNode(
                      left: _nodeX(
                        collections[i].createdAt,
                        oldest,
                        span,
                        w,
                      ),
                      accent: appAccent(collections[i].createdByPackage),
                      latest: i == 0,
                      records: collections[i].recordCount,
                    ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              formatRelativeEpoch(oldest),
              style: text.labelSmall?.copyWith(color: scheme.outline),
            ),
            Text(
              formatRelativeEpoch(newest),
              style: text.labelSmall?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  double _nodeX(int at, int oldest, int span, double width) {
    final t = (at - oldest) / span;
    const pad = 20.0;
    return pad + t * (width - pad * 2) - 7;
  }
}

class _TimelineNode extends StatelessWidget {
  const _TimelineNode({
    required this.left,
    required this.accent,
    required this.latest,
    required this.records,
  });

  final double left;
  final Color accent;
  final bool latest;
  final int records;

  @override
  Widget build(BuildContext context) {
    final size = latest ? 16.0 : (records > 0 ? 12.0 : 10.0);
    return Positioned(
      left: left,
      top: 16 - size / 2 + 1.5,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: accent,
          border: Border.all(
            color: latest ? accent : Colors.white.withValues(alpha: 0.5),
            width: latest ? 2.5 : 1.5,
          ),
          boxShadow: latest
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.45),
                    blurRadius: 8,
                  ),
                ]
              : null,
        ),
      ),
    );
  }
}

class _RecentWideMosaic extends StatelessWidget {
  const _RecentWideMosaic({
    required this.collections,
    required this.totalRecords,
  });

  final List<CollectionInfo> collections;
  final int totalRecords;

  @override
  Widget build(BuildContext context) {
    final lead = collections.first;
    final rest = collections.length > 1 ? collections.sublist(1) : <CollectionInfo>[];

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 5,
            child: _CollectionMosaicCard(
              collection: lead,
              totalRecords: totalRecords,
              featured: true,
            ),
          ),
          if (rest.isNotEmpty) ...[
            const SizedBox(width: 8),
            Expanded(
              flex: 4,
              child: Column(
                children: [
                  for (var i = 0; i < rest.length && i < 4; i++) ...[
                    if (i > 0) const SizedBox(height: 8),
                    Expanded(
                      child: _CollectionMosaicCard(
                        collection: rest[i],
                        totalRecords: totalRecords,
                        featured: false,
                        dense: true,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RecentVerticalTimeline extends StatelessWidget {
  const _RecentVerticalTimeline({
    required this.collections,
    required this.totalRecords,
  });

  final List<CollectionInfo> collections;
  final int totalRecords;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        _CollectionMosaicCard(
          collection: collections.first,
          totalRecords: totalRecords,
          featured: true,
        ),
        if (collections.length > 1) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 148,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: collections.length - 1,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                return SizedBox(
                  width: 220,
                  child: _CollectionMosaicCard(
                    collection: collections[i + 1],
                    totalRecords: totalRecords,
                    featured: false,
                    dense: true,
                  ),
                );
              },
            ),
          ),
        ],
        const SizedBox(height: 4),
        Row(
          children: [
            Container(
              width: 2,
              height: 12,
              color: scheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 8),
            Text(
              'Drag sideways for older entries',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.outline,
                  ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CollectionMosaicCard extends StatefulWidget {
  const _CollectionMosaicCard({
    required this.collection,
    required this.totalRecords,
    required this.featured,
    this.dense = false,
  });

  final CollectionInfo collection;
  final int totalRecords;
  final bool featured;
  final bool dense;

  @override
  State<_CollectionMosaicCard> createState() => _CollectionMosaicCardState();
}

class _CollectionMosaicCardState extends State<_CollectionMosaicCard> {
  bool _pressed = false;

  void _open() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CollectionPage(collection: widget.collection),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.collection;
    final accent = appAccent(c.createdByPackage);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final total = widget.totalRecords == 0 ? 1 : widget.totalRecords;
    final share = c.recordCount / total;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: _open,
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1,
        duration: const Duration(milliseconds: 120),
        child: DecoratedBox(
          decoration: Liquid.panel(
            context,
            radius: widget.featured ? 20 : 16,
            tint: Color.alphaBlend(
              accent.withValues(alpha: 0.1),
              scheme.surfaceContainerLow,
            ),
            elevated: widget.featured,
          ).copyWith(
            border: Border.all(
              color: accent.withValues(alpha: widget.featured ? 0.4 : 0.22),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(widget.dense ? 12 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _RecordShareBadge(
                      share: share,
                      count: c.recordCount,
                      accent: accent,
                      size: widget.featured ? 46 : 38,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.name,
                            style: text.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontFamily: 'monospace',
                            ),
                            maxLines: widget.dense ? 1 : 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.schedule_rounded,
                                size: 12,
                                color: scheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                formatRelativeEpoch(c.createdAt),
                                style: text.labelSmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.north_east_rounded,
                      size: 16,
                      color: scheme.onSurfaceVariant,
                    ),
                  ],
                ),
                SizedBox(height: widget.dense ? 8 : 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 9,
                        backgroundColor: accent.withValues(alpha: 0.25),
                        child: Text(
                          packageInitial(c.createdByPackage),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: accent,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          packageLabel(c.createdByPackage),
                          style: text.labelSmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.featured && !widget.dense) ...[
                  const SizedBox(height: 8),
                  Text(
                    formatEpochMillis(c.createdAt),
                    style: text.labelSmall?.copyWith(
                      fontFamily: 'monospace',
                      color: scheme.outline,
                      fontSize: 10,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecordShareBadge extends StatelessWidget {
  const _RecordShareBadge({
    required this.share,
    required this.count,
    required this.accent,
    required this.size,
  });

  final double share;
  final int count;
  final Color accent;
  final double size;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: share.clamp(0.0, 1.0),
            strokeWidth: 3.5,
            color: accent,
            backgroundColor:
                Theme.of(context).colorScheme.surfaceContainerHighest,
            strokeCap: StrokeCap.round,
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$count',
                style: text.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              Text(
                'rec',
                style: text.labelSmall?.copyWith(fontSize: 9, height: 1),
              ),
            ],
          ),
        ],
      ),
    );
  }
}