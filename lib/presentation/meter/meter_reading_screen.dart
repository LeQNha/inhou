import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../core/id_generator.dart';
import '../../domain/entities/invoice.dart';
import '../../domain/entities/meter_reading.dart';
import '../../domain/entities/room.dart';
import '../../domain/entities/tenant.dart';
import '../providers/providers.dart';
import '../widgets/section_card.dart';

/// CÁCH HOẠT ĐỘNG CỦA "CHỐT ĐIỆN NƯỚC":
/// - Chỉ số CŨ của tháng này = chỉ số MỚI đã lưu của tháng liền trước
///   (tự động, khóa cứng không cho sửa) để đảm bảo chuỗi số liệu liên tục,
///   không ai vô tình sửa sai lịch sử.
/// - NGOẠI LỆ: nếu phòng CHƯA TỪNG chốt điện nước tháng nào trước đó (lần
///   đầu tiên), thì không có gì để "kế thừa" cả -> chỉ số CŨ phải do chủ
///   trọ tự nhập tay đúng bằng số hiển thị trên đồng hồ lúc bàn giao phòng
///   (vì đồng hồ điện/nước thường KHÔNG reset về 0 khi có khách mới).
/// - Tiền điện/nước = (chỉ số mới - chỉ số cũ) × đơn giá. Hóa đơn hiện tại
///   tính theo THÁNG TRỌN VẸN (tiền phòng/rác/internet không chia theo số
///   ngày ở thực tế trong tháng) - đây là giới hạn hiện tại, có thể làm
///   thêm "tính tiền theo số ngày ở" nếu cần sau này.
/// - Màn hình này chặn thao tác nếu phòng chưa có người thuê, hoặc người
///   thuê có ngày dọn vào trong TƯƠNG LAI (chưa thực sự ở), để tránh tạo
///   hóa đơn cho thời gian phòng chưa được thuê.
class MeterReadingScreen extends ConsumerStatefulWidget {
  final String roomId;
  const MeterReadingScreen({super.key, required this.roomId});

  @override
  ConsumerState<MeterReadingScreen> createState() => _MeterReadingScreenState();
}

class _MeterReadingScreenState extends ConsumerState<MeterReadingScreen> {
  final _oldElectricCtrl = TextEditingController();
  final _oldWaterCtrl = TextEditingController();
  final _newElectricCtrl = TextEditingController();
  final _newWaterCtrl = TextEditingController();

  RoomDetail? _detail;
  Tenant? _tenant;
  MeterReading? _existingThisMonth;
  bool _oldValuesEditable = false;
  bool _loading = true;
  bool _saving = false;
  String? _blockReason;

  String get _monthKey => AppFormatters.monthKey(DateTime.now());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _oldElectricCtrl.dispose();
    _oldWaterCtrl.dispose();
    _newElectricCtrl.dispose();
    _newWaterCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final roomRepo = ref.read(roomRepositoryProvider);
    final meterRepo = ref.read(meterReadingRepositoryProvider);
    final tenantRepo = ref.read(tenantRepositoryProvider);

    final detail = await roomRepo.getRoomDetailById(widget.roomId);
    final tenant = await tenantRepo.getTenantByRoom(widget.roomId);
    final existing =
        await meterRepo.getByRoomAndMonth(widget.roomId, _monthKey);
    final previous =
        await meterRepo.getLatestBeforeMonth(widget.roomId, _monthKey);

    // Chặn nếu phòng chưa có người thuê, hoặc người thuê chưa tới ngày dọn vào.
    String? blockReason;
    if (tenant == null) {
      blockReason =
          'Phòng chưa có người thuê. Vui lòng thêm thông tin người thuê trước khi chốt điện nước.';
    } else if (tenant.moveInDate.isAfter(DateTime.now())) {
      blockReason =
          'Người thuê có ngày dọn vào ${AppFormatters.date(tenant.moveInDate)} (chưa tới). '
          'Chưa thể chốt điện nước / tạo hóa đơn cho tới khi khách chính thức dọn vào.';
    }

    // Chỉ số cũ: nếu có lịch sử tháng trước -> khóa cứng, kế thừa từ đó.
    // Nếu KHÔNG có (lần chốt đầu tiên của phòng) -> cho nhập tay.
    final oldValuesEditable = previous == null;
    double oldElectric = 0;
    double oldWater = 0;

    if (existing != null) {
      oldElectric = existing.oldElectric;
      oldWater = existing.oldWater;
      _newElectricCtrl.text = existing.newElectric.toStringAsFixed(0);
      _newWaterCtrl.text = existing.newWater.toStringAsFixed(0);
    } else if (previous != null) {
      oldElectric = previous.newElectric;
      oldWater = previous.newWater;
    }
    _oldElectricCtrl.text =
        oldElectric == 0 ? '' : oldElectric.toStringAsFixed(0);
    _oldWaterCtrl.text = oldWater == 0 ? '' : oldWater.toStringAsFixed(0);

    if (!mounted) return;
    setState(() {
      _detail = detail;
      _tenant = tenant;
      _existingThisMonth = existing;
      _oldValuesEditable = oldValuesEditable;
      _blockReason = blockReason;
      _loading = false;
    });
  }

  Future<void> _openOcr() async {
    final result = await context
        .push<Map<String, String>>('/room/${widget.roomId}/meter/ocr');
    if (result == null) return;
    setState(() {
      if (result['electric'] != null)
        _newElectricCtrl.text = result['electric']!;
      if (result['water'] != null) _newWaterCtrl.text = result['water']!;
    });
  }

  Future<void> _saveAndCreateInvoice() async {
    final oldElectric = double.tryParse(_oldElectricCtrl.text);
    final oldWater = double.tryParse(_oldWaterCtrl.text);
    final newElectric = double.tryParse(_newElectricCtrl.text);
    final newWater = double.tryParse(_newWaterCtrl.text);

    if (oldElectric == null || oldWater == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Vui lòng nhập đủ chỉ số cũ (chỉ số lúc bàn giao phòng).')));
      return;
    }
    if (newElectric == null || newWater == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng nhập đủ chỉ số mới.')));
      return;
    }
    if (newElectric < oldElectric || newWater < oldWater) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Lỗi: chỉ số mới không được nhỏ hơn chỉ số cũ.'),
      ));
      return;
    }

    setState(() => _saving = true);
    try {
      final meterRepo = ref.read(meterReadingRepositoryProvider);
      final reading = MeterReading(
        id: _existingThisMonth?.id ?? IdGenerator.newId(),
        roomId: widget.roomId,
        monthKey: _monthKey,
        oldElectric: oldElectric,
        newElectric: newElectric,
        oldWater: oldWater,
        newWater: newWater,
      );
      if (_existingThisMonth == null) {
        await meterRepo.addReading(reading);
      } else {
        await meterRepo.updateReading(reading);
      }

      final invoiceRepo = ref.read(invoiceRepositoryProvider);
      final detail = _detail!;
      final electricAmount = reading.electricUsage * detail.electricPrice;
      final waterAmount = reading.waterUsage * detail.waterPrice;

      final existingInvoices =
          await invoiceRepo.getInvoicesByRoom(widget.roomId);
      Invoice? existingInvoiceThisMonth;
      for (final inv in existingInvoices) {
        if (inv.monthKey == _monthKey) {
          existingInvoiceThisMonth = inv;
          break;
        }
      }

      final invoice = Invoice(
        id: existingInvoiceThisMonth?.id ?? IdGenerator.newId(),
        roomId: widget.roomId,
        monthKey: _monthKey,
        roomPrice: detail.roomPrice,
        electricAmount: electricAmount,
        waterAmount: waterAmount,
        garbagePrice: detail.garbagePrice,
        internetPrice: detail.internetPrice,
        otherFee: 0,
        status: existingInvoiceThisMonth?.status ?? InvoiceStatus.chuaThanhToan,
        createdAt: existingInvoiceThisMonth?.createdAt ?? DateTime.now(),
      );
      await invoiceRepo.addInvoice(invoice);

      if (!mounted) return;
      context.pushReplacement('/invoice/${invoice.id}');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
    final blocked = _blockReason != null;

    final previewElectric = (double.tryParse(_newElectricCtrl.text) ?? 0) -
        (double.tryParse(_oldElectricCtrl.text) ?? 0);
    final previewWater = (double.tryParse(_newWaterCtrl.text) ?? 0) -
        (double.tryParse(_oldWaterCtrl.text) ?? 0);
    final previewTotal =
        (previewElectric > 0 ? previewElectric : 0) * detail.electricPrice +
            (previewWater > 0 ? previewWater : 0) * detail.waterPrice;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
          title: Text('Chốt điện nước - Phòng ${detail.room.roomNumber}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Tháng ${AppFormatters.month(DateTime.now())}',
              style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          if (blocked) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.dangerSoft,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.danger.withOpacity(0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.block, color: AppColors.danger, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(_blockReason!,
                        style: const TextStyle(
                            color: AppColors.danger,
                            fontSize: 13,
                            height: 1.4)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],
          InkWell(
            onTap: blocked ? null : _openOcr,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Opacity(
              opacity: blocked ? 0.5 : 1,
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
                      child: const Icon(Icons.camera_alt_outlined,
                          color: Colors.white),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Chụp ảnh đồng hồ (OCR)',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15)),
                          SizedBox(height: 2),
                          Text('Tự động đọc số bằng AI, đỡ phải gõ tay',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.white),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          IgnorePointer(
            ignoring: blocked,
            child: Opacity(
              opacity: blocked ? 0.5 : 1,
              child: Column(
                children: [
                  SectionCard(
                    icon: Icons.bolt_outlined,
                    iconColor: AppColors.accent,
                    title: 'Điện',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _oldElectricCtrl,
                                enabled: _oldValuesEditable,
                                keyboardType: TextInputType.number,
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                  labelText: 'Chỉ số cũ (kWh)',
                                  hintText: _oldValuesEditable
                                      ? 'Nhập số trên đồng hồ'
                                      : null,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _newElectricCtrl,
                                keyboardType: TextInputType.number,
                                onChanged: (_) => setState(() {}),
                                decoration: const InputDecoration(
                                    labelText: 'Chỉ số mới (kWh)'),
                              ),
                            ),
                          ],
                        ),
                        if (_oldValuesEditable) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'Đây là lần chốt điện đầu tiên của phòng này: nhập đúng số hiển thị '
                            'trên đồng hồ điện lúc bàn giao cho khách (đồng hồ thường KHÔNG reset về 0).',
                            style: TextStyle(
                                fontSize: 11.5, color: AppColors.textSecondary),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  SectionCard(
                    icon: Icons.water_drop_outlined,
                    iconColor: AppColors.info,
                    title: 'Nước',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _oldWaterCtrl,
                                enabled: _oldValuesEditable,
                                keyboardType: TextInputType.number,
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                  labelText: 'Chỉ số cũ (m³)',
                                  hintText: _oldValuesEditable
                                      ? 'Nhập số trên đồng hồ'
                                      : null,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _newWaterCtrl,
                                keyboardType: TextInputType.number,
                                onChanged: (_) => setState(() {}),
                                decoration: const InputDecoration(
                                    labelText: 'Chỉ số mới (m³)'),
                              ),
                            ),
                          ],
                        ),
                        if (_oldValuesEditable) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'Tương tự, nhập đúng số trên đồng hồ nước lúc bàn giao phòng.',
                            style: TextStyle(
                                fontSize: 11.5, color: AppColors.textSecondary),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.infoSoft,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Xem trước tiền điện nước',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(
                    'Giá điện: ${AppFormatters.currency(detail.electricPrice)}/kWh • Giá nước: ${AppFormatters.currency(detail.waterPrice)}/m³',
                    style: const TextStyle(
                        fontSize: 12.5, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                Text(
                    'Ước tính điện + nước tháng này: ${AppFormatters.currency(previewTotal)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColors.primary)),
              ],
            ),
          ),
          const SizedBox(height: 22),
          ElevatedButton(
            onPressed: (_saving || blocked) ? null : _saveAndCreateInvoice,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Lưu chỉ số & Tạo/Cập nhật hóa đơn'),
          ),
        ],
      ),
    );
  }
}
