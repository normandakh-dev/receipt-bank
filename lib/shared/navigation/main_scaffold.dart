import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:receipt_vault_ai/app/theme/app_colors.dart';
import 'package:receipt_vault_ai/app/theme/ledger_styles.dart';

/// Five-branch shell with the floating ink pill from the paper-ledger design:
/// four icon destinations and a round green camera button at the end.
class MainScaffold extends StatelessWidget {
  const MainScaffold({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  static const double pillHeight = 60;

  void _selectBranch(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = LedgerStyles.isDark(context);
    final pillColor = AppColors.ink;
    final selected = AppColors.paper;
    final unselected = AppColors.inkFaint;

    return Scaffold(
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(24, 0, 24, 12),
        child: Container(
          height: pillHeight,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: pillColor,
            borderRadius: BorderRadius.circular(pillHeight / 2),
            border: isDark ? Border.all(color: AppColors.darkRule) : null,
            boxShadow: [
              BoxShadow(
                color: AppColors.ink.withValues(alpha: 0.55),
                blurRadius: 30,
                spreadRadius: -12,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Row(
            children: [
              _PillItem(
                label: 'Home',
                icon: Icons.home_rounded,
                color: navigationShell.currentIndex == 0
                    ? selected
                    : unselected,
                isSelected: navigationShell.currentIndex == 0,
                onTap: () => _selectBranch(0),
              ),
              _PillItem(
                label: 'Receipts',
                icon: Icons.receipt_long_rounded,
                color: navigationShell.currentIndex == 1
                    ? selected
                    : unselected,
                isSelected: navigationShell.currentIndex == 1,
                onTap: () => _selectBranch(1),
              ),
              _PillItem(
                label: 'Reports',
                icon: Icons.bar_chart_rounded,
                color: navigationShell.currentIndex == 3
                    ? selected
                    : unselected,
                isSelected: navigationShell.currentIndex == 3,
                onTap: () => _selectBranch(3),
              ),
              _PillItem(
                label: 'Tax',
                icon: Icons.request_quote_rounded,
                color: navigationShell.currentIndex == 4
                    ? selected
                    : unselected,
                isSelected: navigationShell.currentIndex == 4,
                onTap: () => _selectBranch(4),
              ),
              const SizedBox(width: 6),
              Semantics(
                label: 'Scan receipt',
                button: true,
                selected: navigationShell.currentIndex == 2,
                child: Tooltip(
                  message: 'Scan receipt',
                  child: Material(
                    color: navigationShell.currentIndex == 2
                        ? AppColors.accentDeep
                        : AppColors.accent,
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => _selectBranch(2),
                      child: const SizedBox(
                        width: 46,
                        height: 46,
                        child: Icon(
                          Icons.add_a_photo_rounded,
                          color: AppColors.paper,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PillItem extends StatelessWidget {
  const _PillItem({
    required this.label,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        label: label,
        selected: isSelected,
        button: true,
        child: Tooltip(
          message: label,
          child: InkResponse(
            onTap: onTap,
            radius: 28,
            child: SizedBox(
              height: MainScaffold.pillHeight,
              child: Icon(icon, color: color, size: 23),
            ),
          ),
        ),
      ),
    );
  }
}
