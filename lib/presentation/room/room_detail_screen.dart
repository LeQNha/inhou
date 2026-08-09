import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../domain/entities/room.dart';
import '../../domain/entities/room_type.dart';
import '../../domain/entities/tenant.dart';
import '../providers/providers.dart';
import '../widgets/section_card.dart';
import '../widgets/status_badge.dart';

class RoomDetailScreen extends ConsumerStatefulWidget {
  final String roomId;
  const RoomDetailScreen({super.key, required this.roomId});

  @override
  ConsumerState<RoomDetailScreen> createState() => _RoomDetailScreenState();
}

class _RoomDetailScreenState extends ConsumerState<RoomDetailScreen> {
  RoomDetail? _detail;
  Tenant? _tenant;
  List<RoomType> _roomTypes = [];
  bool _loading = true;
  String? _monthKey;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final detail =
        await ref.read(roomRepositoryProvider).getRoomDetailById(widget.roomId);
    final tenant =
        await ref.read(tenantRepositoryProvider).getTenantByRoom(widget.roomId);

    List<RoomType> types = [];
    if (detail != null) {
      final owner = ref.read(authRepositoryProvider).currentUser!;
      final motels =
          await ref.read(motelRepositoryProvider).getMotelsByOwner(owner.id);
      final motelId = ref.read(selectedMotelIdProvider) ?? motels.first.id;
      types = await ref
          .read(roomTypeRepositoryProvider)
          .getRoomTypesByMotel(motelId);
    }

    if (!mounted) return;
    setState(() {
      _detail = detail;
      _tenant = tenant;
      _roomTypes = types;
      _loading = false;
    });
  }

  Future<void> _toggleStatus() async {
    final room = _detail!.room;
    if (room.status == RoomStatus.trong && _tenant == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Vui lòng thêm thông tin người thuê trước khi đổi trạng thái.'),
      ));
      return;
    }
    final newStatus = room.status == RoomStatus.trong
        ? RoomStatus.dangThue
        : RoomStatus.trong;
    await ref
        .read(roomRepositoryProvider)
        .updateRoom(room.copyWith(status: newStatus));
    _load();
  }

  Future<void> _editOverride() async {
    final detail = _detail!;
    final room = detail.room;
    final roomPriceCtrl = TextEditingController(
        text: room.customRoomPrice?.toStringAsFixed(0) ?? '');
    final areaCtrl =
        TextEditingController(text: room.customArea?.toStringAsFixed(0) ?? '');
    final electricCtrl = TextEditingController(
        text: room.customElectricPrice?.toStringAsFixed(0) ?? '');
    final waterCtrl = TextEditingController(
        text: room.customWaterPrice?.toStringAsFixed(0) ?? '');

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
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
                  decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Text('Ghi đè giá riêng cho phòng này',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text('Để trống = dùng theo loại phòng "${detail.roomTypeName}"',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 18),
              TextField(
                controller: roomPriceCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                    labelText:
                        'Giá phòng riêng (mặc định ${AppFormatters.currency(detail.roomPrice)})'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: areaCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                    labelText:
                        'Diện tích riêng (mặc định ${detail.area.toStringAsFixed(0)}m²)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: electricCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                    labelText:
                        'Giá điện riêng (mặc định ${AppFormatters.currency(detail.electricPrice)})'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: waterCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                    labelText:
                        'Giá nước riêng (mặc định ${AppFormatters.currency(detail.waterPrice)})'),
              ),
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

    if (saved != true) return;
    double? parse(String s) =>
        s.trim().isEmpty ? null : double.tryParse(s.trim());

    final updated = room.copyWith(
      customRoomPrice: () => parse(roomPriceCtrl.text),
      customArea: () => parse(areaCtrl.text),
      customElectricPrice: () => parse(electricCtrl.text),
      customWaterPrice: () => parse(waterCtrl.text),
    );
    await ref.read(roomRepositoryProvider).updateRoom(updated);
    _load();
  }

  Future<void> _changeRoomType() async {
    if (_roomTypes.isEmpty) return;
    final selected = await showDialog<RoomType>(
      context: context,
      builder: (ctx) => SimpleDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md)),
        title: const Text('Chọn loại phòng'),
        children: _roomTypes
            .map((rt) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, rt),
                  child: Text(rt.name),
                ))
            .toList(),
      ),
    );
    if (selected == null) return;
    await ref
        .read(roomRepositoryProvider)
        .updateRoom(_detail!.room.copyWith(roomTypeId: selected.id));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_detail == null) {
      return const Scaffold(body: Center(child: Text('Không tìm thấy phòng')));
    }
    final detail = _detail!;
    final room = detail.room;
    final isOccupied = room.status == RoomStatus.dangThue;
    final statusColor =
        isOccupied ? AppColors.roomOccupied : AppColors.roomEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text('Phòng ${room.roomNumber}')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                boxShadow: AppShadows.colored(AppColors.primary),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Phòng ${room.roomNumber}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: _changeRoomType,
                          child: Row(
                            children: [
                              Text('Loại: ${detail.roomTypeName}',
                                  style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: 13)),
                              const SizedBox(width: 4),
                              const Icon(Icons.edit,
                                  size: 12, color: Colors.white70),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  StatusBadge(
                    label: room.status.label,
                    color: Colors.white,
                    icon:
                        isOccupied ? Icons.person : Icons.check_circle_outline,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              icon: Icons.info_outline,
              iconColor: AppColors.primary,
              title: 'Thông tin & giá',
              child: Column(
                children: [
                  _InfoRow(Icons.square_foot, 'Diện tích',
                      '${detail.area.toStringAsFixed(0)} m²',
                      overridden: room.customArea != null),
                  _InfoRow(Icons.home_outlined, 'Giá phòng',
                      AppFormatters.currency(detail.roomPrice),
                      overridden: room.customRoomPrice != null),
                  _InfoRow(Icons.bolt_outlined, 'Giá điện',
                      '${AppFormatters.currency(detail.electricPrice)}/kWh',
                      overridden: room.customElectricPrice != null),
                  _InfoRow(Icons.water_drop_outlined, 'Giá nước',
                      '${AppFormatters.currency(detail.waterPrice)}/m³',
                      overridden: room.customWaterPrice != null),
                  _InfoRow(Icons.wifi, 'Internet',
                      '${AppFormatters.currency(detail.internetPrice)}/tháng'),
                  _InfoRow(Icons.delete_outline, 'Tiền rác',
                      '${AppFormatters.currency(detail.garbagePrice)}/tháng'),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _editOverride,
                      icon: const Icon(Icons.tune, size: 18),
                      label: const Text('Ghi đè giá riêng cho phòng này'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              icon: Icons.badge_outlined,
              iconColor: AppColors.info,
              title: 'Người thuê',
              trailing: TextButton.icon(
                onPressed: () => context
                    .push('/room/${room.id}/tenant')
                    .then((_) => _load()),
                icon: Icon(_tenant == null ? Icons.add : Icons.edit, size: 16),
                label: Text(_tenant == null ? 'Thêm' : 'Sửa'),
              ),
              child: _tenant == null
                  ? const Text('Chưa có người thuê',
                      style: TextStyle(color: AppColors.textSecondary))
                  : Column(
                      children: [
                        _InfoRow(
                            Icons.person_outline, 'Họ tên', _tenant!.fullName),
                        _InfoRow(Icons.credit_card, 'CCCD', _tenant!.cccd),
                        _InfoRow(Icons.phone_outlined, 'SĐT', _tenant!.phone),
                        _InfoRow(Icons.event_outlined, 'Ngày dọn vào',
                            AppFormatters.date(_tenant!.moveInDate)),
                        _InfoRow(Icons.savings_outlined, 'Tiền cọc',
                            AppFormatters.currency(_tenant!.deposit)),
                      ],
                    ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _toggleStatus,
              style: OutlinedButton.styleFrom(
                  foregroundColor: statusColor,
                  side: BorderSide(color: statusColor.withOpacity(0.4))),
              icon: Icon(isOccupied ? Icons.logout : Icons.login),
              label: Text(isOccupied
                  ? 'Đánh dấu phòng Trống (khách trả phòng)'
                  : 'Đánh dấu Đang thuê'),
            ),
            const SizedBox(height: 22),
            const Text('Thao tác nhanh',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => context.push('/room/${room.id}/meter'),
              icon: const Icon(Icons.speed_outlined),
              label: const Text('Chốt điện nước tháng này'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => context.push('/invoices'),
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Text('Xem hóa đơn'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  // value is a string representation of the value to display
  final String value;
  final bool overridden;
  const _InfoRow(this.icon, this.label, this.value, {this.overridden = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13.5)),
          ),
          Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
          if (overridden) ...[
            const SizedBox(width: 6),
            const Tooltip(
              message: 'Giá riêng (đã ghi đè)',
              child: Icon(Icons.push_pin, size: 13, color: AppColors.accent),
            ),
          ],
        ],
      ),
    );
  }
}
