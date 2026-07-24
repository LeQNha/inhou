import 'package:flutter/material.dart';

/// Đường kẻ đứt nét kiểu hóa đơn/biên lai thật.
class DashedDivider extends StatelessWidget {
  final Color color;
  const DashedDivider({super.key, this.color = const Color(0xFFD1D5DB)});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final dashCount = (constraints.constrainWidth() / 8).floor();
        return Flex(
          direction: Axis.horizontal,
          children: List.generate(dashCount, (_) {
            return Expanded(
              child: Container(
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                color: color,
              ),
            );
          }),
        );
      },
    );
  }
}
