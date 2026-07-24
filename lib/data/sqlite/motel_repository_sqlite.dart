import '../../domain/entities/motel.dart';
import '../../domain/repositories/motel_repository.dart';
import 'database_helper.dart';

class MotelRepositorySqlite implements MotelRepository {
  final DatabaseHelper _helper;
  MotelRepositorySqlite(this._helper);

  @override
  Future<List<Motel>> getMotelsByOwner(String ownerId) async {
    final db = await _helper.database;
    final rows =
        await db.query('motels', where: 'owner_id = ?', whereArgs: [ownerId]);
    return rows.map(Motel.fromMap).toList();
  }

  @override
  Future<Motel?> getMotelById(String id) async {
    final db = await _helper.database;
    final rows = await db.query('motels', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Motel.fromMap(rows.first);
  }

  @override
  Future<void> addMotel(Motel motel) async {
    final db = await _helper.database;
    await db.insert('motels', motel.toMap());
  }

  @override
  Future<void> updateMotel(Motel motel) async {
    final db = await _helper.database;
    await db.update('motels', motel.toMap(),
        where: 'id = ?', whereArgs: [motel.id]);
  }

  @override
  Future<void> deleteMotel(String id) async {
    final db = await _helper.database;
    await db.delete('motels', where: 'id = ?', whereArgs: [id]);
  }
}
