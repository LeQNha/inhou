import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../core/vietqr_generator.dart';
import '../../domain/entities/invoice.dart';
import '../../domain/entities/room.dart';
import '../providers/providers.dart';

/// ⭐ WOW #4 - QR chuyển khoản VietQR chuẩn EMVCo/NAPAS thật (xem
/// `lib/core/vietqr_generator.dart` để biết chi tiết cấu trúc payload +
/// CRC16). Người dùng chọn ngân hàng + nhập số tài khoản, mã QR sẽ tự
/// động cập nhật theo đúng số tiền của hóa đơn và nội dung chuyển khoản.
class VietQrScreen extends ConsumerStatefulWidget {
  final String invoiceId;
  const VietQrScreen({super.key, required this.invoiceId});

  @override
  ConsumerState<VietQrScreen> createState() => _VietQrScreenState();
}

class _VietQrScreenState extends ConsumerState<VietQrScreen> {
  Invoice? _invoice;
  RoomDetail? _room;
  bool _loading = true;

  VietQrBank _selectedBank = vietQrBanks.first;
  final _accountNumberCtrl = TextEditingController(text: '0123456789');
  final _accountNameCtrl = TextEditingController(text: 'NGUYEN VAN CHU TRO');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final invoice =
        await ref.read(invoiceRepositoryProvider).getInvoiceById(widget.invoiceId);
    RoomDetail? room;
    if (invoice != null) {
      room = await ref.read(roomRepositoryProvider).getRoomDetailById(invoice.roomId);
    }
    if (!mounted) return;
    setState(() {
      _invoice = invoice;
      _room = room;
      _loading = false;
    });
  }

  String _payload() {
    final invoice = _invoice!;
    final room = _room!;
    return VietQrGenerator.build(
      bankBin: _selectedBank.bin,
      accountNumber: _accountNumberCtrl.text.trim(),
      amount: invoice.total,
      description: 'Thanh toan phong ${room.room.roomNumber} thang ${invoice.monthKey}',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_invoice == null || _room == null) {
      return const Scaffold(body: Center(child: Text('Không tìm thấy hóa đơn')));
    }
    final invoice = _invoice!;
    final room = _room!;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('QR chuyển khoản')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: AppColors.heroGradient,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              boxShadow: AppShadows.colored(AppColors.primary),
            ),
            child: Column(
              children: [
                Text('Phòng ${room.room.roomNumber}',
                    style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.85))),
                const SizedBox(height: 4),
                Text(AppFormatters.currency(invoice.total),
                    style: const TextStyle(
                        fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white)),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: QrImageView(
                    data: _payload(),
                    version: QrVersions.auto,
                    size: 220,
                  ),
                ),
                const SizedBox(height: 10),
                Text('Quét bằng app ngân hàng bất kỳ để chuyển khoản nhanh',
                    style: TextStyle(fontSize: 11.5, color: Colors.white.withOpacity(0.85))),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border),
              boxShadow: AppShadows.soft,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.account_balance_outlined, size: 18, color: AppColors.primary),
                    ),
                    const SizedBox(width: 10),
                    Text('Thông tin chuyển khoản', style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<VietQrBank>(
                  value: _selectedBank,
                  decoration: const InputDecoration(labelText: 'Ngân hàng'),
                  items: vietQrBanks
                      .map((b) => DropdownMenuItem(value: b, child: Text('${b.shortName} (${b.bin})')))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedBank = v!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _accountNumberCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Số tài khoản', prefixIcon: Icon(Icons.numbers)),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _accountNameCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Chủ tài khoản', prefixIcon: Icon(Icons.person_outline)),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    'Nội dung chuyển khoản: "Thanh toan phong ${room.room.roomNumber} thang ${invoice.monthKey}"',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
