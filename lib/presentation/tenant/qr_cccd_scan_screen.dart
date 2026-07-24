import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/app_theme.dart';

/// ⭐ WOW #1 - Quét QR CCCD bằng camera thật (package `mobile_scanner`).
///
/// Mã QR mặt sau thẻ CCCD gắn chip của Việt Nam mã hóa các trường thông
/// tin phân cách bởi dấu "|" theo thứ tự:
///   0: Số CCCD (12 số)
///   1: Số CMND cũ (có thể rỗng)
///   2: Họ và tên (viết hoa không dấu)
///   3: Ngày sinh (ddMMyyyy)
///   4: Giới tính
///   5: Địa chỉ thường trú
///   6: Ngày cấp (ddMMyyyy)
/// Đây là định dạng công khai do Bộ Công an quy định cho QR trên CCCD,
/// không phải thông tin riêng tư/bí mật.
class QrCccdScanScreen extends StatefulWidget {
  final String roomId;
  const QrCccdScanScreen({super.key, required this.roomId});

  @override
  State<QrCccdScanScreen> createState() => _QrCccdScanScreenState();
}

class _QrCccdScanScreenState extends State<QrCccdScanScreen> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );
  bool _handled = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    if (capture.barcodes.isEmpty) return;
    final raw = capture.barcodes.first.rawValue;
    if (raw == null || raw.isEmpty) return;

    final parsed = _parseCccdQr(raw);
    if (parsed == null) {
      setState(() => _error = 'Mã QR không đúng định dạng CCCD. Vui lòng thử lại.');
      return;
    }

    _handled = true;
    _controller.stop();
    context.pop(parsed);
  }

  /// Parse chuỗi QR CCCD thành Map để điền vào form người thuê.
  /// Trả về null nếu không đủ dữ liệu tối thiểu (số CCCD + họ tên).
  Map<String, String>? _parseCccdQr(String raw) {
    final parts = raw.split('|');
    if (parts.length < 3) return null;

    final cccd = parts[0].trim();
    final fullName = parts[2].trim();
    if (cccd.isEmpty || fullName.isEmpty) return null;

    String? dobIso;
    if (parts.length > 3 && parts[3].trim().length == 8) {
      final d = parts[3].trim();
      final day = d.substring(0, 2);
      final month = d.substring(2, 4);
      final year = d.substring(4, 8);
      dobIso = DateTime.tryParse('$year-$month-${day}T00:00:00')?.toIso8601String();
    }

    return {
      'cccd': cccd,
      'fullName': fullName,
      if (dobIso != null) 'dob': dobIso,
    };
  }

  Future<void> _manualFallback() async {
    // Máy demo/giả lập không có camera thật -> cho phép nhập tay chuỗi QR
    // để vẫn kiểm thử được luồng parse mà không cần CCCD thật.
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        title: const Text('Nhập chuỗi QR CCCD (demo)'),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: '079201012345|001201001234|NGUYEN VAN A|12051998|Nam|...|010120',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Dùng chuỗi này')),
        ],
      ),
    );
    if (result == null || result.trim().isEmpty) return;
    final parsed = _parseCccdQr(result.trim());
    if (parsed == null) {
      setState(() => _error = 'Chuỗi không đúng định dạng.');
      return;
    }
    if (!mounted) return;
    context.pop(parsed);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Quét QR CCCD'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch_outlined),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                MobileScanner(controller: _controller, onDetect: _onDetect),
                IgnorePointer(
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.greenAccent, width: 2.5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                const Positioned(
                  bottom: 16,
                  child: Text(
                    'Đưa mã QR mặt sau CCCD vào khung hình',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
                if (_error != null)
                  Positioned(
                    top: 16,
                    left: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(_error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 13)),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            color: const Color(0xFF111111),
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _manualFallback,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white30),
                ),
                icon: const Icon(Icons.keyboard_outlined),
                label: const Text('Không có camera? Nhập chuỗi QR thủ công'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
