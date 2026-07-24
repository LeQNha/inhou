import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../core/id_generator.dart';
import '../../domain/entities/room_type.dart';
import '../providers/providers.dart';

/// Quản lý "Loại phòng" (RoomType) - mẫu dùng chung cho nhiều phòng giống
/// nhau, tránh phải nhập lại giá/diện tích cho từng phòng.
class RoomTypeListScreen extends ConsumerStatefulWidget {
  const RoomTypeListScreen({super.key});

  @override
  ConsumerState<RoomTypeListScreen> createState() => _RoomTypeListScreenState();
}

class _RoomTypeListScreenState extends ConsumerState<RoomTypeListScreen> {
  List<RoomType> _roomTypes = [];
  bool _loading = true;
  String? _motelId;

  static const _palette = [
    AppColors.primary,
    AppColors.info,
    AppColors.accent,
    AppColors.success,
    Color(0xFFEC4899),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final owner = ref.read(authRepositoryProvider).currentUser!;
    final motels = await ref.read(motelRepositoryProvider).getMotelsByOwner(owner.id);
    _motelId = ref.read(selectedMotelIdProvider) ?? motels.first.id;
    final types =
        await ref.read(roomTypeRepositoryProvider).getRoomTypesByMotel(_motelId!);
    if (!mounted) return;
    setState(() {
      _roomTypes = types;
      _loading = false;
    });
  }

  Future<void> _openForm({RoomType? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final areaCtrl =
        TextEditingController(text: existing?.area.toStringAsFixed(0) ?? '18');
    final priceCtrl =
        TextEditingController(text: existing?.roomPrice.toStringAsFixed(0) ?? '');
    final electricCtrl = TextEditingController(
        text: existing?.electricPrice.toStringAsFixed(0) ?? '3500');
    final waterCtrl = TextEditingController(
        text: existing?.waterPrice.toStringAsFixed(0) ?? '15000');
    final internetCtrl = TextEditingController(
        text: existing?.internetPrice.toStringAsFixed(0) ?? '0');
    final garbageCtrl = TextEditingController(
        text: existing?.garbagePrice.toStringAsFixed(0) ?? '20000');

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
        ),
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration:
                      BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Text(existing == null ? 'Thêm loại phòng' : 'Sửa loại phòng',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 18),
              TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Tên loại phòng (VD: Tiêu chuẩn, VIP...)',
                      prefixIcon: Icon(Icons.category_outlined))),
              const SizedBox(height: 12),
              TextField(
                  controller: areaCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Diện tích (m²)', prefixIcon: Icon(Icons.square_foot))),
              const SizedBox(height: 12),
              TextField(
                  controller: priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Giá phòng/tháng (đ)', prefixIcon: Icon(Icons.home_outlined))),
              const SizedBox(height: 12),
              TextField(
                  controller: electricCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Giá điện/kWh (đ)', prefixIcon: Icon(Icons.bolt_outlined))),
              const SizedBox(height: 12),
              TextField(
                  controller: waterCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Giá nước/m³ (đ)', prefixIcon: Icon(Icons.water_drop_outlined))),
              const SizedBox(height: 12),
              TextField(
                  controller: internetCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Giá Internet/tháng (đ)', prefixIcon: Icon(Icons.wifi))),
              const SizedBox(height: 12),
              TextField(
                  controller: garbageCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Tiền rác/tháng (đ)', prefixIcon: Icon(Icons.delete_outline))),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Lưu'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (saved != true || nameCtrl.text.trim().isEmpty) return;

    final repo = ref.read(roomTypeRepositoryProvider);
    final roomType = RoomType(
      id: existing?.id ?? IdGenerator.newId(),
      motelId: _motelId!,
      name: nameCtrl.text.trim(),
      area: double.tryParse(areaCtrl.text) ?? 0,
      roomPrice: double.tryParse(priceCtrl.text) ?? 0,
      electricPrice: double.tryParse(electricCtrl.text) ?? 0,
      waterPrice: double.tryParse(waterCtrl.text) ?? 0,
      internetPrice: double.tryParse(internetCtrl.text) ?? 0,
      garbagePrice: double.tryParse(garbageCtrl.text) ?? 0,
    );

    if (existing == null) {
      await repo.addRoomType(roomType);
    } else {
      await repo.updateRoomType(roomType);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Đã cập nhật. Các phòng dùng loại này (không override riêng) sẽ tự áp dụng giá mới.'),
        ));
      }
    }
    _load();
  }

  Future<void> _delete(RoomType rt) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        title: Text('Xóa loại phòng "${rt.name}"?'),
        content: const Text(
            'Lưu ý: các phòng đang dùng loại này cần được đổi sang loại khác trước.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Xóa')),
        ],
      ),
    );
    if (confirm != true) return;
    await ref.read(roomTypeRepositoryProvider).deleteRoomType(rt.id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Loại phòng')),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(28),
          boxShadow: AppShadows.colored(AppColors.primary),
        ),
        child: FloatingActionButton.extended(
          onPressed: () => _openForm(),
          backgroundColor: Colors.transparent,
          elevation: 0,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('Thêm loại phòng', style: TextStyle(color: Colors.white)),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _roomTypes.isEmpty
              ? const Center(child: Text('Chưa có loại phòng nào.'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 90),
                    itemCount: _roomTypes.length,
                    itemBuilder: (context, i) {
                      final rt = _roomTypes[i];
                      final color = _palette[i % _palette.length];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: AppColors.border),
                          boxShadow: AppShadows.soft,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(13),
                              ),
                              alignment: Alignment.center,
                              child: Icon(Icons.category_rounded, color: color),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(rt.name,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w700, fontSize: 15.5)),
                                      ),
                                      Text(AppFormatters.currency(rt.roomPrice),
                                          style: TextStyle(
                                              fontWeight: FontWeight.w800, color: color)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      _miniChip(Icons.square_foot, '${rt.area.toStringAsFixed(0)}m²'),
                                      _miniChip(Icons.bolt_outlined,
                                          '${AppFormatters.currency(rt.electricPrice)}/kWh'),
                                      _miniChip(Icons.water_drop_outlined,
                                          '${AppFormatters.currency(rt.waterPrice)}/m³'),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      TextButton.icon(
                                        onPressed: () => _openForm(existing: rt),
                                        icon: const Icon(Icons.edit_outlined, size: 16),
                                        label: const Text('Sửa'),
                                      ),
                                      const SizedBox(width: 4),
                                      TextButton.icon(
                                        onPressed: () => _delete(rt),
                                        style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                                        icon: const Icon(Icons.delete_outline, size: 16),
                                        label: const Text('Xóa'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _miniChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
