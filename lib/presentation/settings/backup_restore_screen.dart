import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/app_theme.dart';
import '../providers/providers.dart';
import '../widgets/section_card.dart';

/// Sao lưu / khôi phục dữ liệu (tính năng "nên có" để lấy điểm hoàn thiện).
///
/// Cách hoạt động hiện tại: xuất toàn bộ dữ liệu SQLite ra 1 file JSON lưu
/// trong thư mục Documents của app (`smart_motel_backup.json`). Khôi phục
/// sẽ đọc lại đúng file này.
class BackupRestoreScreen extends ConsumerStatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  ConsumerState<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends ConsumerState<BackupRestoreScreen> {
  bool _busy = false;
  String? _backupFilePath;
  DateTime? _backupFileDate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkExistingBackup());
  }

  Future<File> _backupFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, 'smart_motel_backup.json'));
  }

  Future<void> _checkExistingBackup() async {
    final file = await _backupFile();
    if (await file.exists()) {
      final stat = await file.stat();
      if (!mounted) return;
      setState(() {
        _backupFilePath = file.path;
        _backupFileDate = stat.modified;
      });
    }
  }

  Future<void> _exportBackup() async {
    setState(() => _busy = true);
    try {
      final data = await ref.read(databaseHelperProvider).exportAll();
      final file = await _backupFile();
      await file.writeAsString(jsonEncode(data));
      if (!mounted) return;
      setState(() {
        _backupFilePath = file.path;
        _backupFileDate = DateTime.now();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã sao lưu vào:\n${file.path}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Lỗi sao lưu: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restoreBackup() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        title: const Text('Khôi phục dữ liệu?'),
        content: const Text(
            'Toàn bộ dữ liệu hiện tại sẽ bị THAY THẾ bằng dữ liệu trong file sao lưu. Bạn có chắc chắn?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Khôi phục'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _busy = true);
    try {
      final file = await _backupFile();
      if (!await file.exists()) {
        throw Exception('Chưa có file sao lưu nào.');
      }
      final content = await file.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;
      await ref.read(databaseHelperProvider).importAll(data);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Khôi phục dữ liệu thành công.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Lỗi khôi phục: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Sao lưu / Khôi phục')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          SectionCard(
            icon: Icons.info_outline,
            iconColor: AppColors.info,
            title: 'Về tính năng này',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sao lưu sẽ xuất toàn bộ nhà trọ, tầng, phòng, người thuê, chỉ số điện nước và hóa đơn ra 1 file JSON lưu trên máy.',
                  style: TextStyle(fontSize: 13.5, height: 1.4),
                ),
                if (_backupFilePath != null) ...[
                  const SizedBox(height: 14),
                  const Divider(),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.description_outlined, size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_backupFilePath!,
                                style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                            if (_backupFileDate != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                    'Cập nhật: ${_backupFileDate!.toLocal()}'.split('.').first,
                                    style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _busy ? null : _exportBackup,
            icon: const Icon(Icons.save_alt),
            label: const Text('Sao lưu dữ liệu ngay'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _busy ? null : _restoreBackup,
            icon: const Icon(Icons.restore),
            label: const Text('Khôi phục từ file sao lưu'),
          ),
          if (_busy) ...[
            const SizedBox(height: 24),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    );
  }
}
