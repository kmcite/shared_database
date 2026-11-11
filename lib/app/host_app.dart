import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:shared_database/shared_database.dart';

import 'brand/brand.dart';
import 'pages/host_console_page.dart';
import 'providers/host_database_scope.dart';
import 'theme/app_theme.dart';

class SharedDatabaseHostApp extends StatefulWidget {
  const SharedDatabaseHostApp({super.key});

  @override
  State<SharedDatabaseHostApp> createState() => _SharedDatabaseHostAppState();
}

class _SharedDatabaseHostAppState extends State<SharedDatabaseHostApp> {
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    setState(() {
      _error = null;
      _ready = false;
    });
    try {
      await SharedDatabase.openHost();
      if (!mounted) return;
      FlutterNativeSplash.remove();
      setState(() => _ready = true);
    } catch (e) {
      if (!mounted) return;
      FlutterNativeSplash.remove();
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: Brand.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      builder: (context, child) {
        if (!_ready) return child ?? const SizedBox.shrink();
        return HostDatabaseScope(child: child ?? const SizedBox.shrink());
      },
      home: switch ((_ready, _error != null)) {
        (true, _) => const HostConsolePage(),
        (_, true) => BrandSplashError(message: _error!, onRetry: _start),
        _ => const BrandSplashLoading(),
      },
    );
  }
}
