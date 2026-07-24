import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_theme.dart';
import '../../core/id_generator.dart';
import '../../domain/entities/floor.dart';
import '../../domain/entities/room.dart';
import '../../domain/entities/room_type.dart';
import '../providers/providers.dart';

class FloorListScreen extends ConsumerStatefulWidget {
  const FloorListScreen({super.key});

  @override
  ConsumerState<FloorListScreen> createState() => _FloorListScreenState();
}

class _FloorListScreenState extends ConsumerState<FloorListScreen> {
  List<Floor> _floors = [];
  Map<String, List<Room>> _roomsByFloor = {};
  List<RoomType> _roomTypes = [];
  bool _loading = true;
  String? _motelId;
  final Set<String> _expanded = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final owner = ref.read(authRepositoryProvider).currentUser!;
    final motelRepo = ref.read(motelRepositoryProvider);
    final motels = await motelRepo.getMotelsByOwner(owner.id);
    final motelId = ref.read(selectedMotelIdProvider) ?? motels.first.id;
    _motelId = motelId;

    final floorRepo = ref.read(floorRepositoryProvider);
    final roomRepo = ref.read(roomRepositoryProvider);
    final roomTypeRepo = ref.read(roomTypeRepositoryProvider);

    final floors = await floorRepo.getFloorsByMotel(motelId);
    final roomTypes = await roomTypeRepo.getRoomTypesByMotel(motelId);
    final map = <String, List<Room>>{};
    for (final f in floors) {
      map[f.id] = await roomRepo.getRoomsByFloor(f.id);
    }

    if (!mounted) return;
    setState(() {
      _floors = floors;
      _roomsByFloor = map;
      _roomTypes = roomTypes;
      _loading = false;
      if (_expanded.isEmpty && floors.isNotEmpty) _expanded.add(floors.first.id);
    });
  }

  Future<void> _addFloor() async {
    final nameCtrl = TextEditingController(text: 'Tầng ${_floors.length + 1}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        title: const Text('Thêm tầng'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: 'Tên tầng'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Thêm')),
        ],
      ),
    );
    if (ok != true || nameCtrl.text.trim().isEmpty) return;

    final floor = Floor(
      id: IdGenerator.newId(),
      motelId: _motelId!,
      name: nameCtrl.text.trim(),
      order: _floors.length + 1,
    );
    await ref.read(floorRepositoryProvider).addFloor(floor);
    _expanded.add(floor.id);
    _load();
  }

  Future<void> _deleteFloor(Floor floor) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        title: const Text('Xóa tầng?'),
        content: Text('Bạn có chắc muốn xóa "${floor.name}"?'),
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

    final success = await ref.read(floorRepositoryProvider).deleteFloor(floor.id);
    if (!mounted) return;
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Không thể xóa: tầng còn phòng đang có người thuê.'),
      ));
    } else {
      _load();
    }
  }

  Future<void> _addRoomsToFloor(Floor floor) async {
    if (_roomTypes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Chưa có Loại phòng nào. Vào "Cài đặt > Loại phòng" để tạo trước.'),
      ));
      return;
    }
    final fromCtrl = TextEditingController();
    final toCtrl = TextEditingController();
    RoomType selectedType = _roomTypes.first;

    final result = await showModalBottomSheet<bool>(
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
        child: StatefulBuilder(
          builder: (ctx, setSheetState) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sheetHandle(),
              Text('Thêm phòng hàng loạt vào ${floor.name}',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: fromCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Từ phòng số'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: toCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Đến phòng số'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<RoomType>(
                value: selectedType,
                decoration: const InputDecoration(labelText: 'Loại phòng'),
                items: _roomTypes
                    .map((rt) => DropdownMenuItem(value: rt, child: Text(rt.name)))
                    .toList(),
                onChanged: (v) => setSheetState(() => selectedType = v!),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Tạo phòng'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (result != true) return;
    final from = int.tryParse(fromCtrl.text);
    final to = int.tryParse(toCtrl.text);
    if (from == null || to == null || to < from) return;

    final roomNumbers = [for (var i = from; i <= to; i++) '$i'];
    await ref.read(roomRepositoryProvider).addRoomsBulk(
          floorId: floor.id,
          roomTypeId: selectedType.id,
          roomNumbers: roomNumbers,
        );
    _load();
  }

  Widget _sheetHandle() {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Tầng & phòng')),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(28),
          boxShadow: AppShadows.colored(AppColors.primary),
        ),
        child: FloatingActionButton.extended(
          onPressed: _addFloor,
          backgroundColor: Colors.transparent,
          elevation: 0,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('Thêm tầng', style: TextStyle(color: Colors.white)),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _floors.isEmpty
              ? _EmptyState(onAdd: _addFloor)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 90),
                    itemCount: _floors.length,
                    itemBuilder: (context, index) {
                      final floor = _floors[index];
                      final rooms = _roomsByFloor[floor.id] ?? [];
                      final occupied =
                          rooms.where((r) => r.status == RoomStatus.dangThue).length;
                      final isExpanded = _expanded.contains(floor.id);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: AppColors.border),
                          boxShadow: AppShadows.soft,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            InkWell(
                              onTap: () => setState(() {
                                if (isExpanded) {
                                  _expanded.remove(floor.id);
                                } else {
                                  _expanded.add(floor.id);
                                }
                              }),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 42,
                                      height: 42,
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      alignment: Alignment.center,
                                      child: Icon(Icons.layers_outlined,
                                          color: AppColors.primary, size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(floor.name,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w700, fontSize: 15.5)),
                                          const SizedBox(height: 2),
                                          Text('${rooms.length} phòng • $occupied đang thuê',
                                              style: const TextStyle(
                                                  color: AppColors.textSecondary, fontSize: 12.5)),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () => _deleteFloor(floor),
                                      icon: const Icon(Icons.delete_outline,
                                          color: AppColors.danger, size: 20),
                                    ),
                                    AnimatedRotation(
                                      turns: isExpanded ? 0.5 : 0,
                                      duration: const Duration(milliseconds: 200),
                                      child: const Icon(Icons.keyboard_arrow_down,
                                          color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            AnimatedCrossFade(
                              duration: const Duration(milliseconds: 200),
                              crossFadeState:
                                  isExpanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                              firstChild: Padding(
                                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                                child: Column(
                                  children: [
                                    const Divider(height: 20),
                                    if (rooms.isEmpty)
                                      const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 12),
                                        child: Text('Chưa có phòng nào ở tầng này',
                                            style: TextStyle(color: AppColors.textSecondary)),
                                      )
                                    else
                                      GridView.builder(
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        gridDelegate:
                                            const SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 4,
                                          mainAxisSpacing: 10,
                                          crossAxisSpacing: 10,
                                          childAspectRatio: 0.95,
                                        ),
                                        itemCount: rooms.length,
                                        itemBuilder: (context, i) {
                                          final room = rooms[i];
                                          final isOccupied =
                                              room.status == RoomStatus.dangThue;
                                          final color = isOccupied
                                              ? AppColors.roomOccupied
                                              : AppColors.roomEmpty;
                                          return InkWell(
                                            borderRadius: BorderRadius.circular(14),
                                            onTap: () =>
                                                context.push('/room/${room.id}').then(
                                                    (_) => _load()),
                                            onLongPress: () => _deleteRoomConfirm(room),
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: color.withOpacity(0.09),
                                                border: Border.all(color: color.withOpacity(0.4)),
                                                borderRadius: BorderRadius.circular(14),
                                              ),
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    isOccupied
                                                        ? Icons.person
                                                        : Icons.meeting_room_outlined,
                                                    size: 16,
                                                    color: color,
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    room.roomNumber,
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.w700,
                                                      fontSize: 12.5,
                                                      color: color,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        onPressed: () => _addRoomsToFloor(floor),
                                        icon: const Icon(Icons.add, size: 18),
                                        label: const Text('Thêm phòng'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              secondChild: const SizedBox(width: double.infinity),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Future<void> _deleteRoomConfirm(Room room) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        title: Text('Xóa phòng ${room.roomNumber}?'),
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
    final success = await ref.read(roomRepositoryProvider).deleteRoom(room.id);
    if (!mounted) return;
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Không thể xóa: phòng đang có người thuê.'),
      ));
    } else {
      _load();
    }
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.layers_outlined, size: 48, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            const Text('Chưa có tầng nào', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 8),
            const Text('Bấm "Thêm tầng" để bắt đầu tạo cấu trúc nhà trọ.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
