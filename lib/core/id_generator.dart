import 'package:uuid/uuid.dart';

/// Tất cả ID trong app đều sinh dạng String UUID (không dùng auto-increment int).
///
/// Lý do: SQLite thích INTEGER AUTOINCREMENT, nhưng Firestore dùng String
/// document ID. Nếu dùng int ngay từ đầu, khi migrate sang Firebase sau này
/// sẽ phải remap toàn bộ khóa ngoại. Dùng UUID ngay từ đầu giúp migrate
/// không cần đổi schema.
class IdGenerator {
  static const _uuid = Uuid();
  static String newId() => _uuid.v4();
}
