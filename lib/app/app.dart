import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receipt_vault_ai/app/router/app_router.dart';
import 'package:receipt_vault_ai/app/theme/app_theme.dart';
import 'package:receipt_vault_ai/core/constants/app_constants.dart';

class ReceiptVaultApp extends ConsumerWidget {
  const ReceiptVaultApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
