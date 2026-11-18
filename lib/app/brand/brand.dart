import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Matches [flutter_native_splash] and launcher icon assets.
abstract final class Brand {
  static const Color seedTeal = Color(0xFF0F766E);
  static const Color splashBackground = Color(0xFF0F172A);
  static const String splashImage = 'assets/splash.png';
  static const String appIcon = 'assets/app_icon.png';
  static const String appName = 'SharedDB';
  static const String tagline = 'Shared database console';

  static const double splashLogoSize = 128;
  static const double markSizeDefault = 40;
}

/// Centered splash artwork (matches native splash — logo only).
class BrandSplashLogo extends StatelessWidget {
  const BrandSplashLogo({super.key, this.size = Brand.splashLogoSize});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      Brand.splashImage,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) => Icon(
        Icons.storage_rounded,
        size: size * 0.7,
        color: Brand.seedTeal,
      ),
    );
  }
}

/// Logo + optional title used on splash and in the app bar.
class BrandMark extends StatelessWidget {
  const BrandMark({
    super.key,
    this.size = Brand.markSizeDefault,
    this.showTitle = false,
    this.titleStyle,
  });

  final double size;
  final bool showTitle;
  final TextStyle? titleStyle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = TextStyle(
      fontSize: size * 0.45,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.3,
      color: scheme.onSurface,
    );

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(size * 0.22),
            child: Image.asset(
              Brand.appIcon,
              width: size,
              height: size,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
              gaplessPlayback: true,
              errorBuilder: (context, error, stackTrace) => Icon(
                Icons.storage_rounded,
                size: size,
                color: scheme.primary,
              ),
            ),
          ),
          if (showTitle) ...[
            SizedBox(width: size * 0.28),
            Text(Brand.appName, style: titleStyle ?? title),
          ],
        ],
      ),
    );
  }
}

/// Same look as the native splash while Flutter initializes.
class BrandSplashScaffold extends StatelessWidget {
  const BrandSplashScaffold({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    const overlay = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Brand.splashBackground,
      systemNavigationBarIconBrightness: Brightness.light,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay,
      child: Scaffold(
        backgroundColor: Brand.splashBackground,
        body: SafeArea(child: child),
      ),
    );
  }
}

class BrandSplashLoading extends StatelessWidget {
  const BrandSplashLoading({super.key, this.message = 'Opening local database...'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return BrandSplashScaffold(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const BrandSplashLogo(),
                  const SizedBox(height: 24),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.35,
                      color: Colors.white.withValues(alpha: 0.72),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Brand.seedTeal,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class BrandSplashError extends StatelessWidget {
  const BrandSplashError({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final dark = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Brand.seedTeal,
        brightness: Brightness.dark,
      ),
    );
    return Theme(
      data: dark,
      child: BrandSplashScaffold(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const BrandMark(size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'Could not start database',
                      style: dark.textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(message, textAlign: TextAlign.center),
                    const SizedBox(height: 20),
                    FilledButton(onPressed: onRetry, child: const Text('Retry')),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
