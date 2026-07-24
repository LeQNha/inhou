import '../entities/room.dart';

abstract class RoomRepository {
  Future<List<Room>> getRoomsByFloor(String floorId);

  /// Trả về entity đã "ráp sẵn" RoomType + áp dụng override, để UI/domain
  /// không cần biết cách ráp dữ liệu bên dưới (SQL JOIN hay Firestore).
  Future<List<RoomDetail>> getRoomDetailsByFloor(String floorId);
  Future<RoomDetail?> getRoomDetailById(String roomId);

  Future<void> addRoom(Room room);

  /// Tạo hàng loạt phòng liên tiếp, ví dụ 201 -> 212, cùng 1 RoomType.
  Future<void> addRoomsBulk({
    required String floorId,
    required String roomTypeId,
    required List<String> roomNumbers,
  });

  Future<void> updateRoom(Room room);

  /// Trả về false nếu phòng đang có người thuê, không cho xóa.
  Future<bool> deleteRoom(String id);
}
