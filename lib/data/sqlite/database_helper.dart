import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Toàn bộ dữ liệu nghiệp vụ (Motel -> Floor -> RoomType -> Room -> Tenant
/// -> MeterReading -> Invoice -> Payment) được lưu ở SQLite, cùng chung 1
/// database với bảng `owners` (tài khoản đăng nhập cục bộ).

/// - Mọi khóa chính đều là TEXT (UUID), không dùng AUTOINCREMENT.
/// - Ngày giờ lưu dạng TEXT ISO8601.
/// - Bảng `owners` lưu mật khẩu dạng đã băm (SHA-256), không lưu plaintext.
class DatabaseHelper {
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'smart_motel_manager.db');
    return openDatabase(
      path,
      version: 2,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE owners (
            id TEXT PRIMARY KEY,
            email TEXT UNIQUE NOT NULL,
            display_name TEXT NOT NULL,
            password_hash TEXT NOT NULL
          )
        ''');
        await _seedDemoOwner(db);

        await db.execute('''
          CREATE TABLE motels (
            id TEXT PRIMARY KEY,
            owner_id TEXT NOT NULL,
            name TEXT NOT NULL,
            address TEXT NOT NULL,
            default_electric_price REAL NOT NULL,
            default_water_price REAL NOT NULL,
            default_garbage_price REAL NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE floors (
            id TEXT PRIMARY KEY,
            motel_id TEXT NOT NULL,
            name TEXT NOT NULL,
            sort_order INTEGER NOT NULL,
            FOREIGN KEY (motel_id) REFERENCES motels (id) ON DELETE CASCADE
          )
        ''');

        await db.execute('''
          CREATE TABLE room_types (
            id TEXT PRIMARY KEY,
            motel_id TEXT NOT NULL,
            name TEXT NOT NULL,
            area REAL NOT NULL,
            room_price REAL NOT NULL,
            electric_price REAL NOT NULL,
            water_price REAL NOT NULL,
            internet_price REAL NOT NULL,
            garbage_price REAL NOT NULL,
            FOREIGN KEY (motel_id) REFERENCES motels (id) ON DELETE CASCADE
          )
        ''');

        await db.execute('''
          CREATE TABLE rooms (
            id TEXT PRIMARY KEY,
            floor_id TEXT NOT NULL,
            room_type_id TEXT NOT NULL,
            room_number TEXT NOT NULL,
            status TEXT NOT NULL,
            custom_room_price REAL,
            custom_area REAL,
            custom_electric_price REAL,
            custom_water_price REAL,
            FOREIGN KEY (floor_id) REFERENCES floors (id) ON DELETE CASCADE,
            FOREIGN KEY (room_type_id) REFERENCES room_types (id)
          )
        ''');

        await db.execute('''
          CREATE TABLE tenants (
            id TEXT PRIMARY KEY,
            room_id TEXT NOT NULL,
            full_name TEXT NOT NULL,
            cccd TEXT NOT NULL,
            dob TEXT,
            phone TEXT NOT NULL,
            move_in_date TEXT NOT NULL,
            deposit REAL NOT NULL,
            note TEXT,
            FOREIGN KEY (room_id) REFERENCES rooms (id) ON DELETE CASCADE
          )
        ''');

        await db.execute('''
          CREATE TABLE meter_readings (
            id TEXT PRIMARY KEY,
            room_id TEXT NOT NULL,
            month_key TEXT NOT NULL,
            old_electric REAL NOT NULL,
            new_electric REAL NOT NULL,
            old_water REAL NOT NULL,
            new_water REAL NOT NULL,
            FOREIGN KEY (room_id) REFERENCES rooms (id) ON DELETE CASCADE,
            UNIQUE (room_id, month_key)
          )
        ''');

        await db.execute('''
          CREATE TABLE invoices (
            id TEXT PRIMARY KEY,
            room_id TEXT NOT NULL,
            month_key TEXT NOT NULL,
            room_price REAL NOT NULL,
            electric_amount REAL NOT NULL,
            water_amount REAL NOT NULL,
            garbage_price REAL NOT NULL,
            internet_price REAL NOT NULL,
            other_fee REAL NOT NULL,
            status TEXT NOT NULL,
            created_at TEXT NOT NULL,
            FOREIGN KEY (room_id) REFERENCES rooms (id) ON DELETE CASCADE,
            UNIQUE (room_id, month_key)
          )
        ''');

        await db.execute('''
          CREATE TABLE payments (
            id TEXT PRIMARY KEY,
            invoice_id TEXT NOT NULL,
            amount REAL NOT NULL,
            paid_at TEXT NOT NULL,
            method TEXT NOT NULL,
            FOREIGN KEY (invoice_id) REFERENCES invoices (id) ON DELETE CASCADE
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // Nâng cấp từ bản trước (chưa có bảng owners) -> thêm bảng owners
        // mà KHÔNG đụng tới dữ liệu nhà trọ/phòng/hóa đơn đã có sẵn.
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS owners (
              id TEXT PRIMARY KEY,
              email TEXT UNIQUE NOT NULL,
              display_name TEXT NOT NULL,
              password_hash TEXT NOT NULL
            )
          ''');
          await _seedDemoOwner(db);
        }
      },
    );
  }

  /// Tài khoản demo có sẵn: admin@motel.com / 123456
  /// (hash SHA-256 của "123456" được tính sẵn, không hash lúc chạy để
  /// tránh phải import package crypto ngay trong migration).
  Future<void> _seedDemoOwner(DatabaseExecutor db) async {
    await db.insert(
      'owners',
      {
        'id': 'demo-owner-id',
        'email': 'admin@motel.com',
        'display_name': 'Chủ trọ Demo',
        'password_hash':
            '8d969eef6ecad3c29a3a629280e686cf0c3f5d5a86aff3ca12020c923adc6c92',
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// Dùng cho chức năng sao lưu/khôi phục: xóa sạch để nạp lại từ file backup.
  Future<void> wipeAllData() async {
    final db = await database;
    await db.transaction((txn) async {
      for (final table in [
        'payments',
        'invoices',
        'meter_readings',
        'tenants',
        'rooms',
        'room_types',
        'floors',
        'motels',
      ]) {
        await txn.delete(table);
      }
    });
  }

  // Lưu ý: KHÔNG đưa 'owners' vào wipeAllData() ở trên, vì khôi phục dữ
  // liệu nhà trọ không nên xóa mất tài khoản đăng nhập hiện tại. Bảng
  // owners vẫn được export/import đầy đủ trong exportAll()/importAll()
  // bên dưới để 1 file backup có thể khôi phục TOÀN BỘ (kể cả tài khoản)
  // trên một thiết bị mới.

  static const _backupTables = [
    'owners',
    'motels',
    'floors',
    'room_types',
    'rooms',
    'tenants',
    'meter_readings',
    'invoices',
    'payments',
  ];

  /// Xuất toàn bộ dữ liệu (kể cả tài khoản đăng nhập) ra Map, encode JSON
  /// ở tầng trên. Nhờ vậy 1 file backup duy nhất là đủ để khôi phục toàn
  /// bộ ứng dụng trên thiết bị khác — không cần thêm cơ chế nào khác cho
  /// riêng phần tài khoản.
  Future<Map<String, dynamic>> exportAll() async {
    final db = await database;
    final data = <String, dynamic>{};
    for (final table in _backupTables) {
      data[table] = await db.query(table);
    }
    return data;
  }

  /// Xóa dữ liệu hiện tại và nạp lại toàn bộ từ file backup (kể cả owners).
  Future<void> importAll(Map<String, dynamic> data) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final table in _backupTables.reversed) {
        await txn.delete(table);
      }
      for (final table in _backupTables) {
        final rows = (data[table] as List?) ?? [];
        for (final row in rows) {
          await txn.insert(
            table,
            Map<String, dynamic>.from(row as Map),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    });
  }
}
