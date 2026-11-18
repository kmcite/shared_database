import 'package:flutter/material.dart';

import '../brand/brand.dart';

/// Accent choices persisted by the settings page.
enum AppAccent {
  teal(Brand.seedTeal, 'Teal', Icons.water_drop_outlined),
  violet(Color(0xFF7C3AED), 'Violet', Icons.auto_awesome_outlined),
  blue(Color(0xFF2563EB), 'Blue', Icons.waves_outlined),
  green(Color(0xFF059669), 'Green', Icons.eco_outlined),
  orange(Color(0xFFEA580C), 'Orange', Icons.local_fire_department_outlined),
  rose(Color(0xFFE11D48), 'Rose', Icons.favorite_outline_rounded),
  slate(Color(0xFF475569), 'Slate', Icons.circle_outlined);

  const AppAccent(this.seed, this.label, this.icon);

  final Color seed;
  final String label;
  final IconData icon;

  static AppAccent fromSeed(Color color) {
    for (final a in values) {
      if (a.seed.toARGB32() == color.toARGB32()) return a;
    }
    return teal;
  }
}

abstract final class AppTheme {
  static ThemeData light(Color seed) => _from(Brightness.light, seed);

  static ThemeData dark(Color seed) => _from(Brightness.dark, seed);

  static ThemeData _from(Brightness brightness, Color seed) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );

    // Liquid-glass surfaces without blur: translucent-tinted cards with
    // hairline borders over a softly seed-tinted scaffold.
    final scaffoldBg = Color.alphaBlend(
      seed.withValues(alpha: brightness == Brightness.dark ? 0.10 : 0.05),
      scheme.surface,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffoldBg,
      canvasColor: scaffoldBg,
      visualDensity: VisualDensity.standard,
      splashFactory: InkSparkle.splashFactory,
      hoverColor: scheme.onSurface.withValues(alpha: 0.05),
      highlightColor: scheme.onSurface.withValues(alpha: 0.03),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer.withValues(alpha: 0.6),
        elevation: 0,
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow.withValues(alpha: 0.58),
        margin: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.7),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
        elevation: 2,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.5),
        space: 1,
        thickness: 1,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: TextStyle(color: scheme.onInverseSurface, fontSize: 12),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        circularTrackColor: scheme.surfaceContainerHighest,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
      ),
    );
    return base;
  }
}

abstract final class AppLayout {
  static const pagePadding = EdgeInsets.fromLTRB(20, 12, 20, 32);
  static const pagePaddingFab = EdgeInsets.fromLTRB(20, 12, 20, 104);
  static const compactBreakpoint = 900.0;
  static const wideBreakpoint = 1200.0;
}
