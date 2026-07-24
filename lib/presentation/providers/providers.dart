import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/auth/auth_repository_mock_firebase.dart';
import '../../data/sqlite/database_helper.dart';
import '../../data/sqlite/floor_repository_sqlite.dart';
import '../../data/sqlite/invoice_repository_sqlite.dart';
import '../../data/sqlite/meter_reading_repository_sqlite.dart';
import '../../data/sqlite/motel_repository_sqlite.dart';
import '../../data/sqlite/room_repository_sqlite.dart';
import '../../data/sqlite/room_type_repository_sqlite.dart';
import '../../data/sqlite/tenant_repository_sqlite.dart';
import '../../domain/entities/owner.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/floor_repository.dart';
import '../../domain/repositories/invoice_repository.dart';
import '../../domain/repositories/meter_reading_repository.dart';
import '../../domain/repositories/motel_repository.dart';
import '../../domain/repositories/room_repository.dart';
import '../../domain/repositories/room_type_repository.dart';
import '../../domain/repositories/tenant_repository.dart';

// ---------------------------------------------------------------------------
// ĐÂY LÀ NƠI DUY NHẤT CẦN SỬA KHI MUỐN CHUYỂN SANG FIREBASE.
// Ví dụ: authRepositoryProvider = Provider((ref) => AuthRepositoryFirebase());
//        motelRepositoryProvider = Provider((ref) => MotelRepositoryFirestore());
// Toàn bộ UI/state phía dưới chỉ phụ thuộc vào abstract class, không đổi gì.
// ---------------------------------------------------------------------------

final databaseHelperProvider = Provider<DatabaseHelper>((ref) {
  return DatabaseHelper.instance;
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryMockFirebase();
});

final motelRepositoryProvider = Provider<MotelRepository>((ref) {
  return MotelRepositorySqlite(ref.watch(databaseHelperProvider));
});

final floorRepositoryProvider = Provider<FloorRepository>((ref) {
  return FloorRepositorySqlite(ref.watch(databaseHelperProvider));
});

final roomTypeRepositoryProvider = Provider<RoomTypeRepository>((ref) {
  return RoomTypeRepositorySqlite(ref.watch(databaseHelperProvider));
});

final roomRepositoryProvider = Provider<RoomRepository>((ref) {
  return RoomRepositorySqlite(ref.watch(databaseHelperProvider));
});

final tenantRepositoryProvider = Provider<TenantRepository>((ref) {
  return TenantRepositorySqlite(ref.watch(databaseHelperProvider));
});

final meterReadingRepositoryProvider = Provider<MeterReadingRepository>((ref) {
  return MeterReadingRepositorySqlite(ref.watch(databaseHelperProvider));
});

final invoiceRepositoryProvider = Provider<InvoiceRepository>((ref) {
  return InvoiceRepositorySqlite(ref.watch(databaseHelperProvider));
});

// ---------------------------------------------------------------------------
// Auth state - lắng nghe authStateChanges() giống hệt cách dùng
// FirebaseAuth.instance.authStateChanges() trong thực tế.
// ---------------------------------------------------------------------------

final authStateProvider = StreamProvider<Owner?>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return repo.authStateChanges();
});

/// Nhà trọ hiện đang được chọn (hỗ trợ khả năng nhiều nhà trọ sau này,
/// hiện tại đồ án dùng 1 nhà trọ / owner là chính).
final selectedMotelIdProvider = StateProvider<String?>((ref) => null);
