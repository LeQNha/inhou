import '../../domain/entities/meter_reading.dart';
import '../../domain/repositories/meter_reading_repository.dart';
import 'database_helper.dart';

class MeterReadingRepositorySqlite implements MeterReadingRepository {
  final DatabaseHelper _helper;
  MeterReadingRepositorySqlite(this._helper);

  @override
  Future<List<MeterReading>> getHistoryByRoom(String roomId) async {
    final db = await _helper.database;
    final rows = await db.query('meter_readings',
        where: 'room_id = ?', whereArgs: [roomId], orderBy: 'month_key DESC');
    return rows.map(MeterReading.fromMap).toList();
  }

  @override
  Future<MeterReading?> getByRoomAndMonth(String roomId, String monthKey) async {
    final db = await _helper.database;
    final rows = await db.query('meter_readings',
        where: 'room_id = ? AND month_key = ?', whereArgs: [roomId, monthKey]);
    if (rows.isEmpty) return null;
    return MeterReading.fromMap(rows.first);
  }

  @override
  Future<MeterReading?> getLatestBeforeMonth(
      String roomId, String monthKey) async {
    final db = await _helper.database;
    final rows = await db.query(
      'meter_readings',
      where: 'room_id = ? AND month_key < ?',
      whereArgs: [roomId, monthKey],
      orderBy: 'month_key DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return MeterReading.fromMap(rows.first);
  }

  @override
  Future<void> addReading(MeterReading reading) async {
    final db = await _helper.database;
    await db.insert('meter_readings', reading.toMap());
  }

  @override
  Future<void> updateReading(MeterReading reading) async {
    final db = await _helper.database;
    await db.update('meter_readings', reading.toMap(),
        where: 'id = ?', whereArgs: [reading.id]);
  }
}
