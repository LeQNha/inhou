import '../entities/room_type.dart';

abstract class RoomTypeRepository {
  Future<List<RoomType>> getRoomTypesByMotel(String motelId);
  Future<RoomType?> getRoomTypeById(String id);
  Future<void> addRoomType(RoomType roomType);
  Future<void> updateRoomType(RoomType roomType);
  Future<void> deleteRoomType(String id);
}
