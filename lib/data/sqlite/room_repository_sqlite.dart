import 'package:sqflite/sqflite.dart';

import '../../core/id_generator.dart';
import '../../domain/entities/room.dart';
import '../../domain/repositories/room_repository.dart';
import 'database_helper.dart';

class RoomRepositorySqlite implements RoomRepository {
  final DatabaseHelper _helper;
  RoomRepositorySqlite(this._helper);

  @override
  Future<List<Room>> getRoomsByFloor(String floorId) async {
    final db = await _helper.database;
    final rows = await db.query('rooms',
        where: 'floor_id = ?', whereArgs: [floorId], orderBy: 'room_number ASC');
    return rows.map(Room.fromMap).toList();
  }

  /// Đây chính là nơi "ráp" Room + RoomType, áp dụng logic override:
  /// customXxx ?? roomType.xxx. Toàn bộ logic này nằm ở tầng data, tầng
  /// domain/UI chỉ nhận về RoomDetail đã tính sẵn.
  @override
  Future<List<RoomDetail>> getRoomDetailsByFloor(String floorId) async {
    final db = await _helper.database;
    final rows = await db.rawQuery('''
      SELECT r.*, rt.name as rt_name, rt.area as rt_area,
             rt.room_price as rt_room_price, rt.electric_price as rt_electric_price,
             rt.water_price as rt_water_price, rt.internet_price as rt_internet_price,
             rt.garbage_price as rt_garbage_price
      FROM rooms r
      JOIN room_types rt ON r.room_type_id = rt.id
      WHERE r.floor_id = ?
      ORDER BY r.room_number ASC
    ''', [floorId]);
    return rows.map(_mapRowToDetail).toList();
  }

  @override
  Future<RoomDetail?> getRoomDetailById(String roomId) async {
    final db = await _helper.database;
    final rows = await db.rawQuery('''
      SELECT r.*, rt.name as rt_name, rt.area as rt_area,
             rt.room_price as rt_room_price, rt.electric_price as rt_electric_price,
             rt.water_price as rt_water_price, rt.internet_price as rt_internet_price,
             rt.garbage_price as rt_garbage_price
      FROM rooms r
      JOIN room_types rt ON r.room_type_id = rt.id
      WHERE r.id = ?
    ''', [roomId]);
    if (rows.isEmpty) return null;
    return _mapRowToDetail(rows.first);
  }

  RoomDetail _mapRowToDetail(Map<String, Object?> row) {
    final room = Room.fromMap(row);
    return RoomDetail(
      room: room,
      roomTypeName: row['rt_name'] as String,
      area: room.customArea ?? (row['rt_area'] as num).toDouble(),
      roomPrice:
          room.customRoomPrice ?? (row['rt_room_price'] as num).toDouble(),
      electricPrice: room.customElectricPrice ??
          (row['rt_electric_price'] as num).toDouble(),
      waterPrice:
          room.customWaterPrice ?? (row['rt_water_price'] as num).toDouble(),
      internetPrice: (row['rt_internet_price'] as num).toDouble(),
      garbagePrice: (row['rt_garbage_price'] as num).toDouble(),
    );
  }

  @override
  Future<void> addRoom(Room room) async {
    final db = await _helper.database;
    await db.insert('rooms', room.toMap());
  }

  @override
  Future<void> addRoomsBulk({
    required String floorId,
    required String roomTypeId,
    required List<String> roomNumbers,
  }) async {
    final db = await _helper.database;
    final batch = db.batch();
    for (final number in roomNumbers) {
      final room = Room(
        id: IdGenerator.newId(),
        floorId: floorId,
        roomTypeId: roomTypeId,
        roomNumber: number,
        status: RoomStatus.trong,
      );
      batch.insert('rooms', room.toMap());
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<void> updateRoom(Room room) async {
    final db = await _helper.database;
    await db.update('rooms', room.toMap(), where: 'id = ?', whereArgs: [room.id]);
  }

  @override
  Future<bool> deleteRoom(String id) async {
    final db = await _helper.database;
    final rows = await db.query('rooms', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return true;
    final status = RoomStatusX.fromDb(rows.first['status'] as String);
    if (status == RoomStatus.dangThue) return false;
    await db.delete('rooms', where: 'id = ?', whereArgs: [id]);
    return true;
  }
}
