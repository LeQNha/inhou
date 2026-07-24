import '../entities/tenant.dart';

abstract class TenantRepository {
  Future<Tenant?> getTenantByRoom(String roomId);
  Future<void> addTenant(Tenant tenant);
  Future<void> updateTenant(Tenant tenant);
  Future<void> deleteTenant(String id);
}
