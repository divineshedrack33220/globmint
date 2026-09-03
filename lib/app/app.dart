import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import 'router.dart';

class GlobeMintApp extends StatelessWidget {
  const GlobeMintApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Globe Mint',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      routerConfig: appRouter,
    );
  }
}
