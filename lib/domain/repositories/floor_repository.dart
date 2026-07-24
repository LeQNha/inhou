import '../entities/floor.dart';

abstract class FloorRepository {
  Future<List<Floor>> getFloorsByMotel(String motelId);
  Future<void> addFloor(Floor floor);
  Future<void> updateFloor(Floor floor);

  /// Trả về false (và không xóa) nếu tầng còn phòng đang có người thuê.
  Future<bool> deleteFloor(String id);
}
