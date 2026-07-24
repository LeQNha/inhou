import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_theme.dart';
import '../../core/id_generator.dart';
import '../../domain/entities/room.dart';
import '../../domain/entities/tenant.dart';
import '../providers/providers.dart';
import '../widgets/section_card.dart';

class TenantFormScreen extends ConsumerStatefulWidget {
  final String roomId;
  const TenantFormScreen({super.key, required this.roomId});

  @override
  ConsumerState<TenantFormScreen> createState() => _TenantFormScreenState();
}

class _TenantFormScreenState extends ConsumerState<TenantFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _cccdCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _depositCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  DateTime? _dob;
  DateTime _moveInDate = DateTime.now();
  Tenant? _existing;
  bool _loading = true;
  bool _saving = false;
  bool _justScanned = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final tenant =
        await ref.read(tenantRepositoryProvider).getTenantByRoom(widget.roomId);
    if (tenant != null) {
      _existing = tenant;
      _nameCtrl.text = tenant.fullName;
      _cccdCtrl.text = tenant.cccd;
      _phoneCtrl.text = tenant.phone;
      _depositCtrl.text = tenant.deposit.toStringAsFixed(0);
      _noteCtrl.text = tenant.note;
      _dob = tenant.dob;
      _moveInDate = tenant.moveInDate;
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _scanCccd() async {
    final result = await context.push<Map<String, String>>(
        '/room/${widget.roomId}/qr-scan');
    if (result == null) return;
    setState(() {
      _nameCtrl.text = result['fullName'] ?? _nameCtrl.text;
      _cccdCtrl.text = result['cccd'] ?? _cccdCtrl.text;
      if (result['dob'] != null) {
        _dob = DateTime.tryParse(result['dob']!);
      }
      _justScanned = true;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('✅ Đã tự động điền thông tin từ CCCD.'),
      ));
    }
  }

  Future<void> _pickDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1930),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _pickMoveInDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _moveInDate,
      firstDate: DateTime(2015),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _moveInDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final tenant = Tenant(
        id: _existing?.id ?? IdGenerator.newId(),
        roomId: widget.roomId,
        fullName: _nameCtrl.text.trim(),
        cccd: _cccdCtrl.text.trim(),
        dob: _dob,
        phone: _phoneCtrl.text.trim(),
        moveInDate: _moveInDate,
        deposit: double.tryParse(_depositCtrl.text) ?? 0,
        note: _noteCtrl.text.trim(),
      );

      final tenantRepo = ref.read(tenantRepositoryProvider);
      if (_existing == null) {
        await tenantRepo.addTenant(tenant);
      } else {
        await tenantRepo.updateTenant(tenant);
      }

      final roomRepo = ref.read(roomRepositoryProvider);
      final detail = await roomRepo.getRoomDetailById(widget.roomId);
      if (detail != null && detail.room.status == RoomStatus.trong) {
        await roomRepo.updateRoom(
            detail.room.copyWith(status: RoomStatus.dangThue));
      }

      if (!mounted) return;
      context.pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(_existing == null ? 'Thêm người thuê' : 'Sửa người thuê')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            InkWell(
              onTap: _scanCccd,
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  boxShadow: AppShadows.colored(AppColors.primary),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.qr_code_scanner, color: Colors.white),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Quét QR trên thẻ CCCD',
                              style: TextStyle(
                                  color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                          SizedBox(height: 2),
                          Text('Tự động điền họ tên, số CCCD, ngày sinh',
                              style: TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.white),
                  ],
                ),
              ),
            ),
            if (_justScanned) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.successSoft,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, size: 16, color: AppColors.success),
                    SizedBox(width: 8),
                    Text('Dữ liệu bên dưới đã được điền từ CCCD, kiểm tra lại trước khi lưu.',
                        style: TextStyle(fontSize: 12, color: AppColors.textPrimary)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            SectionCard(
              icon: Icons.person_outline,
              iconColor: AppColors.info,
              title: 'Thông tin cá nhân',
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Họ tên', prefixIcon: Icon(Icons.badge_outlined)),
                    validator: (v) => (v == null || v.isEmpty) ? 'Nhập họ tên' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _cccdCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Số CCCD', prefixIcon: Icon(Icons.credit_card)),
                    keyboardType: TextInputType.number,
                    validator: (v) => (v == null || v.isEmpty) ? 'Nhập số CCCD' : null,
                  ),
                  const SizedBox(height: 12),
                  _DateTile(
                    icon: Icons.cake_outlined,
                    label: 'Ngày sinh',
                    value: _dob == null ? 'Chưa chọn' : '${_dob!.day}/${_dob!.month}/${_dob!.year}',
                    onTap: _pickDob,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phoneCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Số điện thoại', prefixIcon: Icon(Icons.phone_outlined)),
                    keyboardType: TextInputType.phone,
                    validator: (v) => (v == null || v.isEmpty) ? 'Nhập số điện thoại' : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              icon: Icons.home_work_outlined,
              iconColor: AppColors.accent,
              title: 'Hợp đồng thuê',
              child: Column(
                children: [
                  _DateTile(
                    icon: Icons.event_outlined,
                    label: 'Ngày dọn vào',
                    value: '${_moveInDate.day}/${_moveInDate.month}/${_moveInDate.year}',
                    onTap: _pickMoveInDate,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _depositCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Tiền cọc (đ)', prefixIcon: Icon(Icons.savings_outlined)),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _noteCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Ghi chú', prefixIcon: Icon(Icons.note_outlined)),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  const _DateTile({required this.icon, required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 10),
            Expanded(child: Text(label)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(width: 6),
            const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
