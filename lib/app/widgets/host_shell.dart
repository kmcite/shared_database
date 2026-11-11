import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../brand/brand.dart';

class ManagerScaffold extends StatelessWidget {
  const ManagerScaffold({
    super.key,
    required this.body,
    this.title,
    this.showHostPill = false,
    this.actions,
    this.floatingActionButton,
  });

  final Widget body;
  final Widget? title;
  final bool showHostPill;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final scheme = Theme.of(context).colorScheme;
    final overlay = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness:
          brightness == Brightness.dark ? Brightness.light : Brightness.dark,
      statusBarBrightness: brightness,
      systemNavigationBarColor: scheme.surface,
      systemNavigationBarIconBrightness:
          brightness == Brightness.dark ? Brightness.light : Brightness.dark,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay,
      child: Scaffold(
        appBar: AppBar(
          title: title ?? const BrandMark(showTitle: true, size: 36),
          actions: [
            ...?actions,
            if (showHostPill)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Chip(
                  avatar: Icon(Icons.bolt_rounded, size: 16, color: scheme.primary),
                  label: const Text('Host'),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                ),
              ),
          ],
        ),
        floatingActionButton: floatingActionButton,
        body: body,
      ),
    );
  }
}
