import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:shared_database/shared_database.dart';

import 'features/shell/brand.dart';
import 'features/shell/app_host.dart';
import 'features/shell/app_theme.dart';

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
      return MaterialApp(
        title: Brand.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        home: _error != null
            ? BrandSplashError(message: _error!, onRetry: _start)
            : const BrandSplashLoading(),
      );
    }
    return const AppHost();
  }
}