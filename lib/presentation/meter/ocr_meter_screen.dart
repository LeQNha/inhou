import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/app_theme.dart';

/// ⭐ WOW #5 - OCR đọc số công tơ điện/nước bằng camera thật.
///
/// Luồng thật: chụp ảnh (image_picker) -> đưa ảnh qua Google ML Kit Text
/// Recognition (chạy on-device, không cần gửi ảnh lên server) -> tìm
/// chuỗi số dài nhất trong kết quả nhận diện (số công tơ thường là dãy số
/// nổi bật nhất trong khung hình) -> cho phép người dùng xem lại/sửa tay
/// trước khi áp dụng, vì số công tơ ảnh hưởng trực tiếp đến tiền phải thu.
class OcrMeterScreen extends StatefulWidget {
  final String roomId;
  const OcrMeterScreen({super.key, required this.roomId});

  @override
  State<OcrMeterScreen> createState() => _OcrMeterScreenState();
}

enum _MeterKind { electric, water }

class _OcrMeterScreenState extends State<OcrMeterScreen> {
  _MeterKind _kind = _MeterKind.electric;
  final _picker = ImagePicker();
  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  File? _imageFile;
  bool _processing = false;
  String? _error;
  String? _recognizedValue;
  final _manualCtrl = TextEditingController();

  @override
  void dispose() {
    _recognizer.close();
    _manualCtrl.dispose();
    super.dispose();
  }

  Future<void> _captureAndRecognize({required ImageSource source}) async {
    setState(() {
      _error = null;
      _recognizedValue = null;
    });

    final picked = await _picker.pickImage(source: source, imageQuality: 90);
    if (picked == null) return;

    setState(() {
      _imageFile = File(picked.path);
      _processing = true;
    });

    try {
      final inputImage = InputImage.fromFilePath(picked.path);
      final result = await _recognizer.processImage(inputImage);
      final value = _extractMeterNumber(result.text);

      if (!mounted) return;
      setState(() {
        _recognizedValue = value;
        _manualCtrl.text = value ?? '';
        _processing = false;
        if (value == null) {
          _error = 'Không tìm thấy dãy số rõ ràng trong ảnh. Vui lòng chụp lại '
              'gần hơn hoặc nhập tay bên dưới.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _error = 'Lỗi xử lý ảnh: $e';
      });
    }
  }

  /// Heuristic: số công tơ thường là dãy chữ số DÀI NHẤT nhận diện được
  /// trong ảnh (bỏ qua các số lẻ tẻ như mã model, đơn vị "kWh"...).
  String? _extractMeterNumber(String recognizedText) {
    final matches = RegExp(r'\d+').allMatches(recognizedText).map((m) => m.group(0)!).toList();
    if (matches.isEmpty) return null;
    matches.sort((a, b) => b.length.compareTo(a.length));
    return matches.first;
  }

  void _confirmResult() {
    final value = _manualCtrl.text.trim();
    if (value.isEmpty || double.tryParse(value) == null) {
      setState(() => _error = 'Vui lòng nhập một số hợp lệ.');
      return;
    }
    context.pop({_kind == _MeterKind.electric ? 'electric' : 'water': value});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Chụp ảnh đồng hồ (OCR)'),
      ),
      body: Column(
        children: [
          Container(
            color: const Color(0xFF1A1A1A),
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ChoiceChip(
                  label: const Text('Đồng hồ điện'),
                  selected: _kind == _MeterKind.electric,
                  onSelected: (_) => setState(() => _kind = _MeterKind.electric),
                ),
                const SizedBox(width: 12),
                ChoiceChip(
                  label: const Text('Đồng hồ nước'),
                  selected: _kind == _MeterKind.water,
                  onSelected: (_) => setState(() => _kind = _MeterKind.water),
                ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: Container(
                width: 300,
                constraints: const BoxConstraints(maxHeight: 320),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.orangeAccent, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.antiAlias,
                child: _processing
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: Colors.orangeAccent),
                          SizedBox(height: 12),
                          Text('Đang nhận diện chỉ số...',
                              style: TextStyle(color: Colors.white)),
                        ],
                      )
                    : _imageFile != null
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.file(_imageFile!, fit: BoxFit.cover),
                              if (_recognizedValue != null)
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: Container(
                                    color: Colors.black54,
                                    padding: const EdgeInsets.all(10),
                                    child: Text(
                                      'Đọc được: $_recognizedValue',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16),
                                    ),
                                  ),
                                ),
                            ],
                          )
                        : const Icon(Icons.speed, color: Colors.white24, size: 90),
              ),
            ),
          ),
          Container(
            color: const Color(0xFF1A1A1A),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_error != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
                    ),
                    child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12.5)),
                  ),
                ],
                if (_imageFile != null) ...[
                  TextField(
                    controller: _manualCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Chỉ số (có thể sửa tay)',
                      labelStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.06),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _captureAndRecognize(source: ImageSource.camera),
                        style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white, side: const BorderSide(color: Colors.white30)),
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: const Text('Chụp ảnh'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _captureAndRecognize(source: ImageSource.gallery),
                        style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white, side: const BorderSide(color: Colors.white30)),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Thư viện'),
                      ),
                    ),
                  ],
                ),
                if (_imageFile != null && !_processing) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                      onPressed: _confirmResult,
                      child: const Text('Dùng kết quả này'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
