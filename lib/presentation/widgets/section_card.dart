import 'package:flutter/material.dart';

import '../../core/app_theme.dart';

/// Card tiêu chuẩn dùng lặp lại khắp app: icon tròn + tiêu đề + nội dung.
/// Giúp các màn hình có bố cục nhất quán thay vì mỗi nơi tự làm 1 kiểu.
class SectionCard extends StatelessWidget {
  final String? title;
  final IconData? icon;
  final Color? iconColor;
  final Widget child;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  const SectionCard({
    super.key,
    this.title,
    this.icon,
    this.iconColor,
    required this.child,
    this.trailing,
    this.padding = const EdgeInsets.all(18),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.soft,
      ),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              children: [
                if (icon != null) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (iconColor ?? AppColors.primary).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 18, color: iconColor ?? AppColors.primary),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(title!,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 14),
          ],
          child,
        ],
      ),
    );
  }
}
