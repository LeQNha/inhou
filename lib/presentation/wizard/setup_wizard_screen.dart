import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_theme.dart';
import '../../core/id_generator.dart';
import '../../domain/entities/floor.dart';
import '../../domain/entities/motel.dart';
import '../../domain/entities/room_type.dart';
import '../providers/providers.dart';

/// Wizard khởi tạo nhà trọ lần đầu: Tên -> Địa chỉ -> Số tầng -> Số phòng/tầng
/// -> Giá điện/nước mặc định -> Hoàn thành. Sau bước này, Database sẽ tự
/// sinh cấu trúc Motel -> Floor -> RoomType ("Tiêu chuẩn") -> Room.
/// Người dùng vẫn có thể thêm/sửa tầng, phòng, loại phòng sau này.
class SetupWizardScreen extends ConsumerStatefulWidget {
  const SetupWizardScreen({super.key});

  @override
  ConsumerState<SetupWizardScreen> createState() => _SetupWizardScreenState();
}

class _SetupWizardScreenState extends ConsumerState<SetupWizardScreen> {
  int _step = 0;
  bool _submitting = false;

  final _nameCtrl = TextEditingController(text: 'Nhà trọ Minh Anh');
  final _addressCtrl = TextEditingController();
  int _floorCount = 3;
  int _roomsPerFloor = 4;
  final _electricCtrl = TextEditingController(text: '3500');
  final _waterCtrl = TextEditingController(text: '15000');
  final _garbageCtrl = TextEditingController(text: '20000');
  final _roomPriceCtrl = TextEditingController(text: '2000000');

  static const _totalSteps = 4;
  static const _stepTitles = ['Nhà trọ', 'Tầng & phòng', 'Giá mặc định', 'Xác nhận'];
  static const _stepIcons = [
    Icons.apartment_rounded,
    Icons.grid_view_rounded,
    Icons.payments_outlined,
    Icons.check_circle_outline,
  ];

  void _next() {
    if (_step < _totalSteps - 1) {
      setState(() => _step++);
    } else {
      _finish();
    }
  }

  void _back() {
    if (_step > 0) setState(() => _step--);
  }

  Future<void> _finish() async {
    setState(() => _submitting = true);
    try {
      final owner = ref.read(authRepositoryProvider).currentUser!;
      final motelRepo = ref.read(motelRepositoryProvider);
      final floorRepo = ref.read(floorRepositoryProvider);
      final roomTypeRepo = ref.read(roomTypeRepositoryProvider);
      final roomRepo = ref.read(roomRepositoryProvider);

      final electric = double.tryParse(_electricCtrl.text) ?? 0;
      final water = double.tryParse(_waterCtrl.text) ?? 0;
      final garbage = double.tryParse(_garbageCtrl.text) ?? 0;
      final roomPrice = double.tryParse(_roomPriceCtrl.text) ?? 0;

      final motel = Motel(
        id: IdGenerator.newId(),
        ownerId: owner.id,
        name: _nameCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        defaultElectricPrice: electric,
        defaultWaterPrice: water,
        defaultGarbagePrice: garbage,
      );
      await motelRepo.addMotel(motel);

      final defaultRoomType = RoomType(
        id: IdGenerator.newId(),
        motelId: motel.id,
        name: 'Tiêu chuẩn',
        area: 18,
        roomPrice: roomPrice,
        electricPrice: electric,
        waterPrice: water,
        internetPrice: 0,
        garbagePrice: garbage,
      );
      await roomTypeRepo.addRoomType(defaultRoomType);

      for (var i = 1; i <= _floorCount; i++) {
        final floor = Floor(
          id: IdGenerator.newId(),
          motelId: motel.id,
          name: 'Tầng $i',
          order: i,
        );
        await floorRepo.addFloor(floor);

        final roomNumbers = List.generate(
          _roomsPerFloor,
          (idx) => '${i}${(idx + 1).toString().padLeft(2, '0')}',
        );
        await roomRepo.addRoomsBulk(
          floorId: floor.id,
          roomTypeId: defaultRoomType.id,
          roomNumbers: roomNumbers,
        );
      }

      if (!mounted) return;
      ref.read(selectedMotelIdProvider.notifier).state = motel.id;
      context.go('/dashboard');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Thiết lập nhà trọ')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: List.generate(_totalSteps, (i) {
                  final active = i <= _step;
                  return Expanded(
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor:
                              active ? AppColors.primary : AppColors.border,
                          child: Icon(
                            _stepIcons[i],
                            size: 16,
                            color: active ? Colors.white : AppColors.textSecondary,
                          ),
                        ),
                        if (i != _totalSteps - 1)
                          Expanded(
                            child: Container(
                              height: 3,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                color: i < _step ? AppColors.primary : AppColors.border,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(_stepTitles[_step],
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: _buildStep(),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, -4)),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (_step > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _submitting ? null : _back,
                        child: const Text('Quay lại'),
                      ),
                    ),
                  if (_step > 0) const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _next,
                      child: _submitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Text(_step == _totalSteps - 1
                              ? 'Hoàn thành'
                              : 'Tiếp theo'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return _StepCard(
          title: 'Thông tin nhà trọ',
          icon: Icons.apartment_rounded,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                  labelText: 'Tên nhà trọ', prefixIcon: Icon(Icons.storefront_outlined)),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _addressCtrl,
              decoration: const InputDecoration(
                  labelText: 'Địa chỉ', prefixIcon: Icon(Icons.location_on_outlined)),
            ),
          ],
        );
      case 1:
        return _StepCard(
          title: 'Số tầng và số phòng mỗi tầng',
          icon: Icons.grid_view_rounded,
          children: [
            _StepperRow(
              label: 'Số tầng',
              value: _floorCount,
              onChanged: (v) => setState(() => _floorCount = v),
            ),
            const SizedBox(height: 18),
            _StepperRow(
              label: 'Số phòng mỗi tầng',
              value: _roomsPerFloor,
              onChanged: (v) => setState(() => _roomsPerFloor = v),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.infoSoft,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                'App sẽ tự sinh $_floorCount tầng, mỗi tầng $_roomsPerFloor phòng '
                '(tổng ${_floorCount * _roomsPerFloor} phòng), đều thuộc loại '
                '"Tiêu chuẩn". Bạn có thể thêm/sửa/xóa hoặc đổi loại phòng sau.',
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 12.5),
              ),
            ),
          ],
        );
      case 2:
        return _StepCard(
          title: 'Giá mặc định (loại phòng Tiêu chuẩn)',
          icon: Icons.payments_outlined,
          children: [
            TextField(
              controller: _roomPriceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Giá phòng / tháng (đ)', prefixIcon: Icon(Icons.home_outlined)),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _electricCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Giá điện / kWh (đ)', prefixIcon: Icon(Icons.bolt_outlined)),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _waterCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Giá nước / m³ (đ)', prefixIcon: Icon(Icons.water_drop_outlined)),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _garbageCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Tiền rác / tháng (đ)', prefixIcon: Icon(Icons.delete_outline)),
            ),
          ],
        );
      default:
        return _StepCard(
          title: 'Xác nhận & hoàn thành',
          icon: Icons.check_circle_outline,
          children: [
            _SummaryRow('Tên nhà trọ', _nameCtrl.text),
            _SummaryRow('Địa chỉ', _addressCtrl.text.isEmpty ? '(chưa nhập)' : _addressCtrl.text),
            _SummaryRow('Số tầng', '$_floorCount'),
            _SummaryRow('Số phòng mỗi tầng', '$_roomsPerFloor'),
            _SummaryRow('Tổng số phòng', '${_floorCount * _roomsPerFloor}'),
            _SummaryRow('Giá phòng mặc định', '${_roomPriceCtrl.text} đ'),
            _SummaryRow('Giá điện', '${_electricCtrl.text} đ/kWh'),
            _SummaryRow('Giá nước', '${_waterCtrl.text} đ/m³'),
            const SizedBox(height: 10),
            const Text(
              'Bấm "Hoàn thành" để tạo nhà trọ và vào Dashboard.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        );
    }
  }
}

class _StepCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  const _StepCard({required this.title, required this.icon, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.soft,
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(title, style: Theme.of(context).textTheme.titleLarge),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }
}

class _StepperRow extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  const _StepperRow(
      {required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 15))),
          _roundIconButton(Icons.remove, value > 1 ? () => onChanged(value - 1) : null),
          SizedBox(
            width: 40,
            child: Text('$value',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          _roundIconButton(Icons.add, value < 30 ? () => onChanged(value + 1) : null),
        ],
      ),
    );
  }

  Widget _roundIconButton(IconData icon, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: onTap == null ? AppColors.border : AppColors.primary.withOpacity(0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: onTap == null ? AppColors.textSecondary : AppColors.primary),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
