import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../domain/entities/invoice.dart';
import '../../domain/entities/meter_reading.dart';
import '../../domain/entities/room.dart';
import '../providers/providers.dart';
import 'invoice_qr_share_screen.dart';
import '../widgets/dashed_divider.dart';
import '../widgets/status_badge.dart';

class InvoiceDetailScreen extends ConsumerStatefulWidget {
  final String invoiceId;
  const InvoiceDetailScreen({super.key, required this.invoiceId});

  @override
  ConsumerState<InvoiceDetailScreen> createState() =>
      _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends ConsumerState<InvoiceDetailScreen> {
  Invoice? _invoice;
  RoomDetail? _room;
  MeterReading? _reading;
  bool _loading = true;
  bool _exporting = false;

  final ScreenshotController _screenshotController = ScreenshotController();

  Future<void> _shareInvoiceWithQr() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InvoiceQrShareScreen(invoice: _invoice!, room: _room!),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final invoice = await ref
        .read(invoiceRepositoryProvider)
        .getInvoiceById(widget.invoiceId);
    RoomDetail? room;
    MeterReading? reading;
    if (invoice != null) {
      room = await ref
          .read(roomRepositoryProvider)
          .getRoomDetailById(invoice.roomId);
      reading = await ref
          .read(meterReadingRepositoryProvider)
          .getByRoomAndMonth(invoice.roomId, invoice.monthKey);
    }
    if (!mounted) return;
    setState(() {
      _invoice = invoice;
      _room = room;
      _reading = reading;
      _loading = false;
    });
  }

  Future<void> _togglePaid() async {
    final invoice = _invoice!;
    final newStatus = invoice.status == InvoiceStatus.daThanhToan
        ? InvoiceStatus.chuaThanhToan
        : InvoiceStatus.daThanhToan;
    await ref
        .read(invoiceRepositoryProvider)
        .updateInvoiceStatus(invoice.id, newStatus);
    _load();
  }

  /// Chụp Card hóa đơn thành ảnh PNG thật (package `screenshot`)
  Future<File?> _captureReceiptPng() async {
    final bytes = await _screenshotController.capture(pixelRatio: 3);
    if (bytes == null) return null;
    final dir = await getApplicationDocumentsDirectory();
    final fileName =
        'hoadon_phong${_room!.room.roomNumber}_${_invoice!.monthKey}.png';
    final file = File(p.join(dir.path, fileName));
    await file.writeAsBytes(bytes);
    return file;
  }

  Future<void> _exportPng() async {
    setState(() => _exporting = true);
    try {
      final file = await _captureReceiptPng();
      if (!mounted) return;
      if (file == null) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không tạo được ảnh, thử lại.')));
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã lưu ảnh hóa đơn:\n${file.path}')),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  /// Chia sẻ hóa đơn qua Zalo/Messenger bằng cách mở Share
  Future<void> _shareInvoice() async {
    setState(() => _exporting = true);
    try {
      final file = await _captureReceiptPng();
      if (!mounted) return;
      if (file == null) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không tạo được ảnh, thử lại.')));
        return;
      }
      // await SharePlus.instance.share(
      //   ShareParams(
      //     files: [XFile(file.path)],
      //     text:
      //         'Hóa đơn phòng ${_room!.room.roomNumber} tháng ${_invoice!.monthKey}: '
      //         '${AppFormatters.currency(_invoice!.total)}',
      //   ),
      // );
      await Share.shareXFiles(
        [XFile(file.path)],
        text:
            'Hóa đơn phòng ${_room!.room.roomNumber} tháng ${_invoice!.monthKey}: '
            '${AppFormatters.currency(_invoice!.total)}',
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  // Future<void> _shareInvoiceWithQr() async {
  //   await Navigator.of(context).push(
  //     MaterialPageRoute(
  //       builder: (_) => InvoiceQrShareScreen(invoice: _invoice!, room: _room!),
  //     ),
  //   );
  // }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_invoice == null || _room == null) {
      return const Scaffold(
          body: Center(child: Text('Không tìm thấy hóa đơn')));
    }
    final invoice = _invoice!;
    final room = _room!;
    final paid = invoice.status == InvoiceStatus.daThanhToan;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Chi tiết hóa đơn')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Screenshot(
            controller: _screenshotController,
            child: Container(
              color: AppColors.background,
              padding: const EdgeInsets.all(4),
              child: _ReceiptCard(
                  invoice: invoice, room: room, reading: _reading, paid: paid),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _togglePaid,
            icon: Icon(paid ? Icons.undo : Icons.check_circle_outline),
            label: Text(
                paid ? 'Đánh dấu Chưa thanh toán' : 'Đánh dấu Đã thanh toán'),
          ),
          const SizedBox(height: 24),
          const Text('Xuất & chia sẻ',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _exporting ? null : _exportPng,
            icon: _exporting
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.image_outlined),
            label: const Text('Xuất hóa đơn thành ảnh PNG'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _exporting ? null : _shareInvoice,
            icon: const Icon(Icons.share_outlined),
            label: const Text('Chia sẻ qua Zalo / Messenger'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _exporting ? null : _shareInvoiceWithQr,
            icon: const Icon(Icons.qr_code_2),
            label: const Text('Chia sẻ hóa đơn kèm mã QR'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => context.push('/invoice/${invoice.id}/vietqr'),
            icon: const Icon(Icons.account_balance_outlined),
            label: const Text('Tạo / chỉnh sửa mã QR VietQR'),
          ),
        ],
      ),
    );
  }
}

class _ReceiptCard extends StatelessWidget {
  final Invoice invoice;
  final RoomDetail room;
  final MeterReading? reading;
  final bool paid;
  const _ReceiptCard(
      {required this.invoice,
      required this.room,
      required this.reading,
      required this.paid});

  // Future<void> _shareInvoiceWithQr() async {
  //   await Navigator.of(context).push(
  //     MaterialPageRoute(
  //       builder: (_) => InvoiceQrShareScreen(invoice: _invoice!, room: _room!),
  //     ),
  //   );
  // }

  // _shareInvoiceWithQr(context)

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: const BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.receipt_long,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(height: 8),
                const Text('HÓA ĐƠN TIỀN PHÒNG',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: Colors.white,
                        letterSpacing: 0.5)),
                const SizedBox(height: 4),
                Text(
                  'Phòng ${room.room.roomNumber} • Tháng ${AppFormatters.month(AppFormatters.parseMonthKey(invoice.monthKey))}',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.85), fontSize: 12.5),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              children: [
                _LineItem('Tiền phòng', invoice.roomPrice),
                if (reading != null)
                  _LineItem(
                      'Tiền điện (${reading!.electricUsage.toStringAsFixed(0)} kWh)',
                      invoice.electricAmount)
                else
                  _LineItem('Tiền điện', invoice.electricAmount),
                if (reading != null)
                  _LineItem(
                      'Tiền nước (${reading!.waterUsage.toStringAsFixed(0)} m³)',
                      invoice.waterAmount)
                else
                  _LineItem('Tiền nước', invoice.waterAmount),
                _LineItem('Tiền rác', invoice.garbagePrice),
                if (invoice.internetPrice > 0)
                  _LineItem('Internet', invoice.internetPrice),
                if (invoice.otherFee > 0)
                  _LineItem('Phụ thu khác', invoice.otherFee),
                const SizedBox(height: 12),
                const DashedDivider(),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('TỔNG CỘNG',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 15)),
                    Text(
                      AppFormatters.currency(invoice.total),
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 19,
                          color: AppColors.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                StatusBadge(
                  label: invoice.status.label,
                  color: paid ? AppColors.paid : AppColors.unpaid,
                  icon: paid ? Icons.check_circle : Icons.schedule,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LineItem extends StatelessWidget {
  final String label;
  final double amount;
  const _LineItem(this.label, this.amount);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 13.5)),
          Text(AppFormatters.currency(amount),
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
        ],
      ),
    );
  }
}
