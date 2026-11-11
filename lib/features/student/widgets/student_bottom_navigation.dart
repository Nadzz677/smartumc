import 'package:flutter/material.dart';

import '../../../core/design_system/app_colors.dart';
import '../../../core/design_system/app_spacing.dart';

class StudentBottomNavigation extends StatelessWidget {
  const StudentBottomNavigation({
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const _items = <({String label, IconData icon})>[
    (label: 'Home', icon: Icons.home_outlined),
    (label: 'Activities', icon: Icons.menu_book_outlined),
    (label: 'QR', icon: Icons.qr_code_scanner),
    (label: 'Events', icon: Icons.campaign_outlined),
    (label: 'Profile', icon: Icons.account_circle_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: SizedBox(
        height: 80,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Container(
              height: 76,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(40),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.ink.withValues(alpha: 0.14),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: List.generate(_items.length, (index) {
                  if (index == 2) return _qrButton();
                  return Expanded(child: _tab(index));
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tab(int index) {
    final item = _items[index];
    final selected = selectedIndex == index;
    final color = selected
        ? AppColors.brandCyan
        : AppColors.slate.withValues(alpha: 0.62);
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: InkWell(
        key: ValueKey('student-tab-${item.label.toLowerCase()}'),
        borderRadius: BorderRadius.circular(32),
        onTap: () => onSelected(index),
        child: SizedBox.expand(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(item.icon, size: 27, color: color),
              const SizedBox(height: 2),
              Text(
                item.label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _qrButton() => SizedBox(
    width: 68,
    child: Align(
      alignment: Alignment.topCenter,
      child: Transform.translate(
        offset: const Offset(0, -12),
        child: Semantics(
          button: true,
          label: 'QR scanner',
          selected: selectedIndex == 2,
          child: InkWell(
            key: const ValueKey('student-tab-qr'),
            onTap: () => onSelected(2),
            customBorder: const CircleBorder(),
            child: Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.brandCyan,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x30000000),
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.qr_code_scanner, color: AppColors.white, size: 30),
                  Text(
                    'QR',
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
