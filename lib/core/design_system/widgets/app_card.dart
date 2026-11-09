import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_radii.dart';

/// Reusable elevated or translucent surface used across role experiences.
class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.color = AppColors.white,
    this.borderRadius = AppRadii.card,
    this.blurSigma = 0,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final double borderRadius;
  final double blurSigma;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            if (blurSigma > 0)
              Positioned.fill(
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(
                    sigmaX: blurSigma,
                    sigmaY: blurSigma,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            Container(
              padding: padding,
              decoration: BoxDecoration(
                color: color,
                border: Border.all(
                  color: AppColors.white.withValues(alpha: 0.55),
                ),
              ),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}
