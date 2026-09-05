import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:receipt_vault_ai/core/ocr/receipt_ocr_parser.dart';
import 'package:receipt_vault_ai/data/providers/database_providers.dart';
import 'package:receipt_vault_ai/features/home/presentation/categories_screen.dart';
import 'package:receipt_vault_ai/features/home/presentation/home_screen.dart';
import 'package:receipt_vault_ai/features/onboarding/presentation/onboarding_screen.dart';
import 'package:receipt_vault_ai/features/receipts/presentation/manual_receipt_screen.dart';
import 'package:receipt_vault_ai/features/receipts/presentation/receipt_detail_screen.dart';
import 'package:receipt_vault_ai/features/receipts/presentation/receipts_screen.dart';
import 'package:receipt_vault_ai/features/reports/presentation/reports_screen.dart';
import 'package:receipt_vault_ai/features/scanner/presentation/scan_screen.dart';
import 'package:receipt_vault_ai/features/settings/presentation/settings_screen.dart';
import 'package:receipt_vault_ai/features/tax/presentation/tax_purpose_screen.dart';
import 'package:receipt_vault_ai/shared/navigation/main_scaffold.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);

final appRouterProvider = Provider<GoRouter>((ref) {
  final database = ref.watch(databaseProvider);
  final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/onboarding',
    redirect: (context, state) async {
      final isComplete = await database.isOnboardingComplete();
      final isOnboarding = state.matchedLocation == '/onboarding';
      if (!isComplete && !isOnboarding) {
        return '/onboarding';
      }
      if (isComplete && isOnboarding) {
        return '/home';
      }
      return null;
    },
    errorBuilder: (context, state) => Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, size: 44),
                const SizedBox(height: 16),
                Text(
                  'That page could not be opened.',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => context.go('/home'),
                  child: const Text('Back to Home'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainScaffold(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
                routes: [
                  GoRoute(
                    path: 'categories',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => const CategoriesScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/receipts',
                builder: (context, state) => ReceiptsScreen(
                  initialCategoryId: state.uri.queryParameters['category'],
                  initialStart: DateTime.tryParse(
                    state.uri.queryParameters['from'] ?? '',
                  ),
                  initialEndExclusive: DateTime.tryParse(
                    state.uri.queryParameters['to'] ?? '',
                  ),
                  periodLabel: state.uri.queryParameters['period'],
                ),
                routes: [
                  GoRoute(
                    path: 'new',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => ManualReceiptScreen(
                      scannedReceipt: state.extra is ReceiptScanResult
                          ? state.extra! as ReceiptScanResult
                          : null,
                    ),
                  ),
                  GoRoute(
                    path: ':receiptId',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => ReceiptDetailScreen(
                      receiptId: state.pathParameters['receiptId']!,
                    ),
                    routes: [
                      GoRoute(
                        path: 'edit',
                        parentNavigatorKey: _rootNavigatorKey,
                        builder: (context, state) => ReceiptEditScreen(
                          receiptId: state.pathParameters['receiptId']!,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/scan',
                builder: (context, state) => const ScanScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/reports',
                builder: (context, state) => const ReportsScreen(),
                routes: [
                  GoRoute(
                    path: 'categories',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => const CategoryReportsScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/tax',
                builder: (context, state) => const TaxPurposeScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );

  ref.onDispose(router.dispose);
  return router;
});
