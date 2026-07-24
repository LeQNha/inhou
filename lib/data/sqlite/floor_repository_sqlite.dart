import 'package:sqflite/sqflite.dart';

import '../../domain/entities/floor.dart';
import '../../domain/entities/room.dart';
import '../../domain/repositories/floor_repository.dart';
import 'database_helper.dart';

class FloorRepositorySqlite implements FloorRepository {
  final DatabaseHelper _helper;
  FloorRepositorySqlite(this._helper);

  @override
  Future<List<Floor>> getFloorsByMotel(String motelId) async {
    final db = await _helper.database;
    final rows = await db.query('floors',
        where: 'motel_id = ?', whereArgs: [motelId], orderBy: 'sort_order ASC');
    return rows.map(Floor.fromMap).toList();
  }

  @override
  Future<void> addFloor(Floor floor) async {
    final db = await _helper.database;
    await db.insert('floors', floor.toMap());
  }

  @override
  Future<void> updateFloor(Floor floor) async {
    final db = await _helper.database;
    await db.update('floors', floor.toMap(),
        where: 'id = ?', whereArgs: [floor.id]);
  }

  @override
  Future<bool> deleteFloor(String id) async {
    final db = await _helper.database;

    // Không cho xóa nếu còn phòng đang có người thuê.
    final occupied = await db.rawQuery('''
      SELECT COUNT(*) as cnt FROM rooms
      WHERE floor_id = ? AND status = ?
    ''', [id, RoomStatus.dangThue.toDb()]);
    final occupiedCount = Sqflite.firstIntValue(occupied) ?? 0;
    if (occupiedCount > 0) return false;

    await db.delete('floors', where: 'id = ?', whereArgs: [id]);
    return true;
  }
}
