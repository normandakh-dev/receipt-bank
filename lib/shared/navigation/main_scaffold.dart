import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MainScaffold extends StatelessWidget {
  const MainScaffold({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  void _selectBranch(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: navigationShell,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Semantics(
        label: 'Scan receipt',
        button: true,
        selected: navigationShell.currentIndex == 2,
        child: FloatingActionButton.large(
          heroTag: 'scan-receipt-button',
          tooltip: 'Scan receipt',
          onPressed: () => _selectBranch(2),
          child: const Icon(Icons.document_scanner_rounded, size: 30),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        height: 76,
        padding: EdgeInsets.zero,
        shape: const CircularNotchedRectangle(),
        notchMargin: 9,
        child: Row(
          children: [
            Expanded(
              child: _NavigationItem(
                label: 'Home',
                icon: Icons.home_outlined,
                selectedIcon: Icons.home_rounded,
                isSelected: navigationShell.currentIndex == 0,
                onTap: () => _selectBranch(0),
              ),
            ),
            Expanded(
              child: _NavigationItem(
                label: 'Receipts',
                icon: Icons.receipt_long_outlined,
                selectedIcon: Icons.receipt_long_rounded,
                isSelected: navigationShell.currentIndex == 1,
                onTap: () => _selectBranch(1),
              ),
            ),
            const SizedBox(width: 76),
            Expanded(
              child: _NavigationItem(
                label: 'Reports',
                icon: Icons.bar_chart_outlined,
                selectedIcon: Icons.bar_chart_rounded,
                isSelected: navigationShell.currentIndex == 3,
                onTap: () => _selectBranch(3),
              ),
            ),
            Expanded(
              child: _NavigationItem(
                label: 'Tax',
                icon: Icons.request_quote_outlined,
                selectedIcon: Icons.request_quote_rounded,
                isSelected: navigationShell.currentIndex == 4,
                onTap: () => _selectBranch(4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavigationItem extends StatelessWidget {
  const _NavigationItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = isSelected
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;

    return Semantics(
      label: label,
      selected: isSelected,
      button: true,
      child: InkResponse(
        onTap: onTap,
        radius: 34,
        child: SizedBox(
          height: 72,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(isSelected ? selectedIcon : icon, color: foreground),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: foreground,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
