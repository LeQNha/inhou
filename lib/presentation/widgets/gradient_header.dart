import 'package:flutter/material.dart';

import '../../core/app_theme.dart';

/// Header gradient bo góc dưới, dùng cho các màn hình cần điểm nhấn thương
/// hiệu (Login, Wizard...). Tạo cảm giác "app thật" thay vì nền trắng đơn điệu.
class GradientHeader extends StatelessWidget {
  final Widget child;
  final double height;
  final Gradient gradient;

  const GradientHeader({
    super.key,
    required this.child,
    this.height = 220,
    this.gradient = AppColors.heroGradient,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(32),
        bottomRight: Radius.circular(32),
      ),
      child: Container(
        width: double.infinity,
        height: height,
        decoration: BoxDecoration(gradient: gradient),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              right: -30,
              top: -30,
              child: _blob(120, Colors.white.withOpacity(0.08)),
            ),
            Positioned(
              left: -40,
              bottom: -50,
              child: _blob(160, Colors.white.withOpacity(0.06)),
            ),
            child,
          ],
        ),
      ),
    );
  }

  Widget _blob(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
