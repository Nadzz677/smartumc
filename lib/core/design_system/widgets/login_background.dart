import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../app_colors.dart';

/// Figma's three blurred SVG shapes, scaled from its 393 x 852 mobile frame.
class LoginBackground extends StatelessWidget {
  const LoginBackground({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = math
            .min(constraints.maxWidth / 393, constraints.maxHeight / 852)
            .clamp(0.65, 1.4)
            .toDouble();
        final canvasWidth = 393 * scale;
        final canvasHeight = 852 * scale;
        final offsetX = (constraints.maxWidth - canvasWidth) / 2;
        final offsetY = (constraints.maxHeight - canvasHeight) / 2;

        Widget wave({
          required String asset,
          required double left,
          required double top,
          required double width,
          required double height,
        }) {
          return Positioned(
            left: offsetX + left * scale,
            top: offsetY + top * scale,
            width: width * scale,
            height: height * scale,
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(
                sigmaX: 40 * scale,
                sigmaY: 40 * scale,
              ),
              child: SvgPicture.asset(
                asset,
                fit: BoxFit.fill,
                excludeFromSemantics: true,
              ),
            ),
          );
        }

        return Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.hardEdge,
          children: [
            const ColoredBox(color: AppColors.white),
            wave(
              asset: 'assets/design/login/wave_top_1.svg',
              left: -6,
              top: -270,
              width: 595,
              height: 810,
            ),
            wave(
              asset: 'assets/design/login/wave_top_2.svg',
              left: -232,
              top: -49,
              width: 657,
              height: 790,
            ),
            wave(
              asset: 'assets/design/login/wave_bottom.svg',
              left: -56,
              top: 340,
              width: 643,
              height: 740,
            ),
            child,
          ],
        );
      },
    );
  }
}
