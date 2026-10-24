import 'package:uuid/uuid.dart';

/// Tất cả ID trong app đều sinh dạng String UUID (không dùng auto-increment int).
class IdGenerator {
  static const _uuid = Uuid();
  static String newId() => _uuid.v4();
}
