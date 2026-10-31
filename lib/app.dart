import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/claim/presentation/pages/app_shell.dart';

class SathiApp extends StatelessWidget {
  const SathiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sathi — Local-first Claim Companion',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const AppShell(),
    );
  }
}
