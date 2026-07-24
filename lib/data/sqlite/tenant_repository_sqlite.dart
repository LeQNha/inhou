import '../../domain/entities/tenant.dart';
import '../../domain/repositories/tenant_repository.dart';
import 'database_helper.dart';

class TenantRepositorySqlite implements TenantRepository {
  final DatabaseHelper _helper;
  TenantRepositorySqlite(this._helper);

  @override
  Future<Tenant?> getTenantByRoom(String roomId) async {
    final db = await _helper.database;
    final rows =
        await db.query('tenants', where: 'room_id = ?', whereArgs: [roomId]);
    if (rows.isEmpty) return null;
    return Tenant.fromMap(rows.first);
  }

  @override
  Future<void> addTenant(Tenant tenant) async {
    final db = await _helper.database;
    await db.insert('tenants', tenant.toMap());
  }

  @override
  Future<void> updateTenant(Tenant tenant) async {
    final db = await _helper.database;
    await db.update('tenants', tenant.toMap(),
        where: 'id = ?', whereArgs: [tenant.id]);
  }

  @override
  Future<void> deleteTenant(String id) async {
    final db = await _helper.database;
    await db.delete('tenants', where: 'id = ?', whereArgs: [id]);
  }
}
