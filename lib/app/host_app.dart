import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:shared_database/shared_database.dart';

import 'brand/brand.dart';
import 'features/shell/app_host.dart';
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
      await SharedDatabase.open();
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
    if (!_ready) {
      final seed = AppAccent.teal.seed;
      return MaterialApp(
        title: Brand.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(seed),
        darkTheme: AppTheme.dark(seed),
        home: _error != null
            ? BrandSplashError(message: _error!, onRetry: _start)
            : const BrandSplashLoading(),
      );
    }
    return const AppHost();
  }
}