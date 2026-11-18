import 'package:flutter/material.dart';

import 'liquid.dart';

/// Screen title in a liquid-glass bar.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
  });

  final String title;
  final String? subtitle;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: LiquidPanel(
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        radius: 22,
        elevated: true,
        tint: Color.alphaBlend(
          scheme.primary.withValues(alpha: 0.06),
          scheme.surfaceContainerLow,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: text.headlineSmall),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            ...?actions,
          ],
        ),
      ),
    );
  }
}