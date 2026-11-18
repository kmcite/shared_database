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
    BorderRadiusGeometry? borderRadius,
    double alpha = 0.62,
    Color? tint,
    bool elevated = false,
    double strength = 1,
    Border? border,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final base = tint ?? scheme.surfaceContainerLow;
    final radiusGeometry = borderRadius ?? BorderRadius.circular(radius);
    return BoxDecoration(
      color: base.withValues(alpha: alpha),
      borderRadius: radiusGeometry,
      border: border ??
          Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.8),
            width: 0.8,
          ),
      boxShadow: elevated ? shadows(context, strength: strength) : null,
    );
  }

  /// Mosaic-style panel tinted by an accent color (apps / collections tiles).
  static BoxDecoration panelAccent(
    BuildContext context, {
    required Color accent,
    double radius = 18,
    bool featured = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return panel(
      context,
      radius: radius,
      tint: Color.alphaBlend(
        accent.withValues(alpha: featured ? 0.12 : 0.1),
        scheme.surfaceContainerLow,
      ),
      elevated: featured,
      strength: featured ? 1.2 : 0.8,
    ).copyWith(
      border: Border.all(
        color: accent.withValues(alpha: featured ? 0.35 : 0.22),
        width: featured ? 1.2 : 0.8,
      ),
    );
  }

  static BoxDecoration pill(BuildContext context, {Color? tint, double alpha = 0.55}) {
    final scheme = Theme.of(context).colorScheme;
    final base = tint ?? scheme.primaryContainer;
    return BoxDecoration(
      color: base.withValues(alpha: alpha),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(
        color: scheme.outlineVariant.withValues(alpha: 0.65),
        width: 0.7,
      ),
    );
  }

  /// Soft radial highlight used behind mosaic tiles.
  static Widget glowOrb(Color accent, {double size = 100}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            accent.withValues(alpha: 0.22),
            accent.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}

/// Glass card — drop-in for [Card] with optional tap and accent glow.
class LiquidCard extends StatefulWidget {
  const LiquidCard({
    super.key,
    required this.child,
    this.padding,
    this.margin = const EdgeInsets.only(bottom: 8),
    this.radius = 18,
    this.tint,
    this.accent,
    this.featured = false,
    this.elevated,
    this.onTap,
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry margin;
  final double radius;
  final Color? tint;
  final Color? accent;
  final bool featured;
  final bool? elevated;
  final VoidCallback? onTap;
  final Clip clipBehavior;

  @override
  State<LiquidCard> createState() => _LiquidCardState();
}

class _LiquidCardState extends State<LiquidCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;
    final elevated = widget.elevated ?? widget.featured;

    BoxDecoration decoration;
    if (accent != null) {
      decoration = Liquid.panelAccent(
        context,
        accent: accent,
        radius: widget.radius,
        featured: widget.featured,
      );
    } else {
      decoration = Liquid.panel(
        context,
        radius: widget.radius,
        tint: widget.tint,
        elevated: elevated,
        strength: widget.featured ? 1.15 : 0.9,
      );
    }

    Widget inner = Padding(
      padding: widget.padding ?? const EdgeInsets.all(16),
      child: widget.child,
    );

    if (accent != null) {
      inner = Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: Liquid.glowOrb(accent, size: widget.featured ? 110 : 88),
          ),
          inner,
        ],
      );
    }

    final content = AnimatedScale(
      scale: widget.onTap != null && _pressed ? 0.985 : 1,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      child: DecoratedBox(
        decoration: decoration,
        child: inner,
      ),
    );

    return Padding(
      padding: widget.margin,
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: widget.onTap != null ? (_) => setState(() => _pressed = true) : null,
        onTapUp: widget.onTap != null ? (_) => setState(() => _pressed = false) : null,
        onTapCancel:
            widget.onTap != null ? () => setState(() => _pressed = false) : null,
        child: content,
      ),
    );
  }
}

/// Full-width glass panel (headers, empty states).
class LiquidPanel extends StatelessWidget {
  const LiquidPanel({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.radius = 20,
    this.tint,
    this.elevated = true,
    this.accent,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final Color? tint;
  final bool elevated;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final accentColor = accent;
    final decoration = accentColor != null
        ? Liquid.panelAccent(context, accent: accentColor, radius: radius)
        : Liquid.panel(
            context,
            radius: radius,
            tint: tint,
            elevated: elevated,
          );

    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: DecoratedBox(
        decoration: decoration,
        child: Padding(
          padding: padding ?? const EdgeInsets.all(20),
          child: child,
        ),
      ),
    );
  }
}