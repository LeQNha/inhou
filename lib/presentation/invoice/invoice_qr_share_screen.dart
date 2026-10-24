import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
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

/// Builds one shareable image containing invoice summary and the VietQR code.
class InvoiceQrShareScreen extends StatefulWidget {
  final Invoice invoice;
  final RoomDetail room;
  const InvoiceQrShareScreen({super.key, required this.invoice, required this.room});

  @override
  State<InvoiceQrShareScreen> createState() => _InvoiceQrShareScreenState();
}

class _InvoiceQrShareScreenState extends State<InvoiceQrShareScreen> {
  final ScreenshotController _controller = ScreenshotController();
  bool _loading = true;
  bool _sharing = false;
  VietQrBank _bank = vietQrBanks.first;
  String _account = '';
  String _name = '';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final bin = prefs.getString('vietqr_bank_bin');
    if (!mounted) return;
    setState(() {
      _bank = vietQrBanks.firstWhere((b) => b.bin == bin, orElse: () => vietQrBanks.first);
      _account = prefs.getString('vietqr_account_number') ?? '';
      _name = prefs.getString('vietqr_account_name') ?? '';
      _loading = false;
    });
  }

  String _payload() => VietQrGenerator.build(
    bankBin: _bank.bin,
    accountNumber: _account,
    amount: widget.invoice.total,
    description: 'Thanh toan phong ${widget.room.room.roomNumber} thang ${widget.invoice.monthKey}',
  );

  Future<void> _share() async {
    if (_account.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hãy mở màn hình VietQR và lưu thông tin ngân hàng trước khi chia sẻ.')));
      return;
    }
    setState(() => _sharing = true);
    try {
      final Uint8List? bytes = await _controller.capture(pixelRatio: 3);
      if (bytes == null) throw Exception('Không tạo được ảnh.');
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, 'hoadon_qr_phong${widget.room.room.roomNumber}_${widget.invoice.monthKey}.png'));
      await file.writeAsBytes(bytes, flush: true);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Hóa đơn phòng ${widget.room.room.roomNumber} tháng ${widget.invoice.monthKey}: ${AppFormatters.currency(widget.invoice.total)}',
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không thể chia sẻ: $e')));
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final invoice = widget.invoice;
    final room = widget.room;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Chia sẻ hóa đơn + QR')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Screenshot(
          controller: _controller,
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.all(22),
            child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
              const Text('HÓA ĐƠN TIỀN PHÒNG', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.black)),
              const SizedBox(height: 8),
              Text('Phòng ${room.room.roomNumber} • Tháng ${invoice.monthKey}', style: const TextStyle(color: Colors.black87)),
              const SizedBox(height: 8),
              const Divider(color: Colors.black26),
              _summaryLine('Tiền phòng', invoice.roomPrice),
              _summaryLine('Tiền điện', invoice.electricAmount),
              _summaryLine('Tiền nước', invoice.waterAmount),
              _summaryLine('Tiền rác', invoice.garbagePrice),
              if (invoice.internetPrice > 0) _summaryLine('Internet', invoice.internetPrice),
              if (invoice.otherFee > 0) _summaryLine('Phụ thu khác', invoice.otherFee),
              const Divider(color: Colors.black26),
              _summaryLine('TỔNG CỘNG', invoice.total, bold: true),
              const SizedBox(height: 16),
              const Text('QUÉT MÃ ĐỂ THANH TOÁN', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
              const SizedBox(height: 8),
              QrImageView(data: _payload(), version: QrVersions.auto, size: 220, backgroundColor: Colors.white),
              Text(_name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
              Text('${_bank.shortName} • $_account', style: const TextStyle(color: Colors.black87)),
              const SizedBox(height: 4),
              Text('Nội dung: Thanh toan phong ${room.room.roomNumber} thang ${invoice.monthKey}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Colors.black54)),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _sharing ? null : _share,
          icon: _sharing ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.share_outlined),
          label: Text(_sharing ? 'Đang tạo ảnh...' : 'Chia sẻ ảnh hóa đơn + QR'),
        ),
      ]),
    );
  }

  Widget _summaryLine(String label, double amount, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(color: Colors.black87, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
      Text(AppFormatters.currency(amount), style: TextStyle(color: Colors.black, fontWeight: bold ? FontWeight.w800 : FontWeight.w500)),
    ]),
  );
}
