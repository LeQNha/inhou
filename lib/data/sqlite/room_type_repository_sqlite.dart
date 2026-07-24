import '../../domain/entities/room_type.dart';
import '../../domain/repositories/room_type_repository.dart';
import 'database_helper.dart';

class RoomTypeRepositorySqlite implements RoomTypeRepository {
  final DatabaseHelper _helper;
  RoomTypeRepositorySqlite(this._helper);

  @override
  Future<List<RoomType>> getRoomTypesByMotel(String motelId) async {
    final db = await _helper.database;
    final rows = await db
        .query('room_types', where: 'motel_id = ?', whereArgs: [motelId]);
    return rows.map(RoomType.fromMap).toList();
  }

  @override
  Future<RoomType?> getRoomTypeById(String id) async {
    final db = await _helper.database;
    final rows =
        await db.query('room_types', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return RoomType.fromMap(rows.first);
  }

  @override
  Future<void> addRoomType(RoomType roomType) async {
    final db = await _helper.database;
    await db.insert('room_types', roomType.toMap());
  }

  @override
  Future<void> updateRoomType(RoomType roomType) async {
    final db = await _helper.database;
    await db.update('room_types', roomType.toMap(),
        where: 'id = ?', whereArgs: [roomType.id]);
  }

  @override
  Future<void> deleteRoomType(String id) async {
    final db = await _helper.database;
    await db.delete('room_types', where: 'id = ?', whereArgs: [id]);
  }
}
