import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../core/vietqr_generator.dart';
import '../../domain/entities/invoice.dart';
import '../../domain/entities/room.dart';
import '../providers/providers.dart';

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
  bool _saving = false;
  bool _sharing = false;

  VietQrBank _selectedBank = vietQrBanks.first;
  final _accountNumberCtrl = TextEditingController();
  final _accountNameCtrl = TextEditingController();
  final ScreenshotController _qrScreenshotController = ScreenshotController();

  static const _bankKey = 'vietqr_bank_bin';
  static const _accountKey = 'vietqr_account_number';
  static const _nameKey = 'vietqr_account_name';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final savedBin = prefs.getString(_bankKey);
    final invoice = await ref
        .read(invoiceRepositoryProvider)
        .getInvoiceById(widget.invoiceId);
    RoomDetail? room;
    if (invoice != null) {
      room = await ref
          .read(roomRepositoryProvider)
          .getRoomDetailById(invoice.roomId);
    }
    if (!mounted) return;
    setState(() {
      _invoice = invoice;
      _room = room;
      _selectedBank = vietQrBanks.firstWhere(
        (bank) => bank.bin == savedBin,
        orElse: () => vietQrBanks.first,
      );
      _accountNumberCtrl.text = prefs.getString(_accountKey) ?? '';
      _accountNameCtrl.text = prefs.getString(_nameKey) ?? '';
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
      description:
          'Thanh toan phong ${room.room.roomNumber} thang ${invoice.monthKey}',
    );
  }

  Future<void> _saveBankDetails() async {
    if (_accountNumberCtrl.text.trim().isEmpty ||
        _accountNameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Vui lòng nhập số tài khoản và tên chủ tài khoản.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_bankKey, _selectedBank.bin);
      await prefs.setString(_accountKey, _accountNumberCtrl.text.trim());
      await prefs.setString(_nameKey, _accountNameCtrl.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã lưu thông tin tài khoản ngân hàng.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<File?> _createQrPng() async {
    final bytes = await _qrScreenshotController.capture(pixelRatio: 3);
    if (bytes == null) return null;
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path,
        'vietqr_${_room!.room.roomNumber}_${_invoice!.monthKey}.png'));
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<void> _saveQrImage() async {
    if (_accountNumberCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập số tài khoản trước.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final file = await _createQrPng();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(file == null
                ? 'Không tạo được ảnh QR.'
                : 'Đã lưu ảnh QR tại: ${file.path}')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _shareQrImage() async {
    setState(() => _sharing = true);
    try {
      final file = await _createQrPng();
      if (file == null) throw Exception('Không tạo được ảnh QR.');
      await Share.shareXFiles(
        [XFile(file.path)],
        text:
            'Mã QR thanh toán phòng ${_room!.room.roomNumber}, tháng ${_invoice!.monthKey}.',
      );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể chia sẻ QR: $e')),
        );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  void dispose() {
    _accountNumberCtrl.dispose();
    _accountNameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_invoice == null || _room == null)
      return const Scaffold(
          body: Center(child: Text('Không tìm thấy hóa đơn')));
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
                boxShadow: AppShadows.colored(AppColors.primary)),
            child: Column(children: [
              Text('Phòng ${room.room.roomNumber}',
                  style: TextStyle(
                      fontSize: 14, color: Colors.white.withOpacity(0.85))),
              const SizedBox(height: 4),
              Text(AppFormatters.currency(invoice.total),
                  style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
              const SizedBox(height: 20),
              Screenshot(
                controller: _qrScreenshotController,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16)),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    QrImageView(
                        data: _payload(), version: QrVersions.auto, size: 220),
                    const SizedBox(height: 6),
                    Text(_accountNameCtrl.text.trim(),
                        style: const TextStyle(
                            color: Colors.black, fontWeight: FontWeight.bold)),
                    Text(
                        '${_selectedBank.shortName} • ${_accountNumberCtrl.text.trim()}',
                        style: const TextStyle(
                            color: Colors.black87, fontSize: 12)),
                  ]),
                ),
              ),
              const SizedBox(height: 10),
              Text('Quét bằng ứng dụng ngân hàng để chuyển khoản',
                  style: TextStyle(
                      fontSize: 11.5, color: Colors.white.withOpacity(0.85))),
            ]),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.border),
                boxShadow: AppShadows.soft),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.account_balance_outlined,
                        size: 18, color: AppColors.primary)),
                const SizedBox(width: 10),
                Text('Thông tin chuyển khoản',
                    style: Theme.of(context).textTheme.titleMedium),
              ]),
              const SizedBox(height: 16),
              DropdownButtonFormField<VietQrBank>(
                value: _selectedBank,
                decoration: const InputDecoration(labelText: 'Ngân hàng'),
                items: vietQrBanks
                    .map((b) => DropdownMenuItem(
                        value: b, child: Text('${b.shortName} (${b.bin})')))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _selectedBank = v);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                  controller: _accountNumberCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Số tài khoản',
                      prefixIcon: Icon(Icons.numbers)),
                  onChanged: (_) => setState(() {})),
              const SizedBox(height: 12),
              TextField(
                  controller: _accountNameCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                      labelText: 'Chủ tài khoản',
                      prefixIcon: Icon(Icons.person_outline)),
                  onChanged: (_) => setState(() {})),
              const SizedBox(height: 14),
              Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(AppRadius.sm)),
                  child: Text(
                      'Nội dung chuyển khoản: "Thanh toan phong ${room.room.roomNumber} thang ${invoice.monthKey}"',
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12.5))),
              const SizedBox(height: 16),
              SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                      onPressed: _saving ? null : _saveBankDetails,
                      icon: const Icon(Icons.save_outlined),
                      label: Text(_saving
                          ? 'Đang xử lý...'
                          : 'Lưu thông tin ngân hàng'))),
              const SizedBox(height: 10),
              SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                      onPressed: _saving ? null : _saveQrImage,
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('Lưu ảnh QR'))),
              const SizedBox(height: 10),
              SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                      onPressed: _sharing ? null : _shareQrImage,
                      icon: const Icon(Icons.share_outlined),
                      label: const Text('Chia sẻ mã QR'))),
            ]),
          ),
        ],
      ),
    );
  }
}
