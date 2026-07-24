import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_theme.dart';
import '../providers/providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final owner = ref.watch(authRepositoryProvider).currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Cài đặt')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              boxShadow: AppShadows.colored(AppColors.primary),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.white.withOpacity(0.22),
                  child: Text(
                    (owner?.displayName.isNotEmpty == true
                            ? owner!.displayName[0]
                            : 'C')
                        .toUpperCase(),
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(owner?.displayName ?? 'Chủ trọ',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(owner?.email ?? '',
                          style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const _SettingsSectionLabel('Quản lý'),
          _SettingsTile(
            icon: Icons.category_outlined,
            iconColor: AppColors.primary,
            label: 'Loại phòng (Room Type)',
            subtitle: 'Mẫu giá dùng chung cho nhiều phòng',
            onTap: () => context.push('/room-types'),
          ),
          _SettingsTile(
            icon: Icons.apartment_outlined,
            iconColor: AppColors.info,
            label: 'Tầng & phòng',
            subtitle: 'Xem lại toàn bộ cấu trúc nhà trọ',
            onTap: () => context.push('/floors'),
          ),
          const SizedBox(height: 20),
          const _SettingsSectionLabel('Dữ liệu'),
          _SettingsTile(
            icon: Icons.settings_backup_restore,
            iconColor: AppColors.accent,
            label: 'Sao lưu / Khôi phục',
            subtitle: 'Xuất & nhập dữ liệu JSON',
            onTap: () => context.push('/backup'),
          ),
          const SizedBox(height: 20),
          const _SettingsSectionLabel('Tài khoản'),
          _SettingsTile(
            icon: Icons.logout,
            iconColor: AppColors.danger,
            label: 'Đăng xuất',
            subtitle: null,
            onTap: () async {
              await ref.read(authRepositoryProvider).signOut();
              if (context.mounted) context.go('/login');
            },
          ),
          const SizedBox(height: 24),
          Center(
            child: Text('Smart Motel Manager • v1.0.0',
                style: TextStyle(color: AppColors.textSecondary.withOpacity(0.7), fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _SettingsSectionLabel extends StatelessWidget {
  final String label;
  const _SettingsSectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(label,
          style: const TextStyle(
              color: AppColors.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w700)),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        leading: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: subtitle == null ? null : Text(subtitle!, style: const TextStyle(fontSize: 12.5)),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
        onTap: onTap,
      ),
    );
  }
}
