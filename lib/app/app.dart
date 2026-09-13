import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_theme.dart';
import 'router.dart';

class GlobeMintApp extends StatelessWidget {
  const GlobeMintApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp.router(
        title: 'GlobMint',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        routerConfig: appRouter,
      ),
    );
  }
}