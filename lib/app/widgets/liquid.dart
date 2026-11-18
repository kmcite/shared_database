import 'package:flutter/material.dart';

/// Liquid-glass surfaces — translucent fills, hairline borders, soft shadows.
abstract final class Liquid {
  static List<BoxShadow> shadows(BuildContext context, {double strength = 1}) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: dark ? 0.35 : 0.10),
        blurRadius: 18 * strength,
        offset: const Offset(0, 6),
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: dark ? 0.20 : 0.05),
        blurRadius: 4 * strength,
        offset: const Offset(0, 1),
      ),
    ];
  }

  static BoxDecoration panel(
    BuildContext context, {
    double radius = 20,
    double alpha = 0.62,
    Color? tint,
    bool elevated = false,
    double strength = 1,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final base = tint ?? scheme.surfaceContainerLow;
    return BoxDecoration(
      color: base.withValues(alpha: alpha),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: scheme.outlineVariant.withValues(alpha: 0.8),
        width: 0.8,
      ),
      boxShadow: elevated ? shadows(context, strength: strength) : null,
    );
  }
}