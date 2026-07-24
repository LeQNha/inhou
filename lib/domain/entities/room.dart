enum RoomStatus { trong, dangThue }

extension RoomStatusX on RoomStatus {
  String get label => this == RoomStatus.trong ? 'Trống' : 'Đang thuê';

  static RoomStatus fromDb(String v) =>
      v == 'dang_thue' ? RoomStatus.dangThue : RoomStatus.trong;

  String toDb() => this == RoomStatus.dangThue ? 'dang_thue' : 'trong';
}

/// Room có thể override từng trường giá/diện tích riêng so với RoomType.
/// Nếu customXxx == null thì lấy giá trị từ RoomType tương ứng.
class Room {
  final String id;
  final String floorId;
  final String roomTypeId;
  final String roomNumber; // 101, 102...
  final RoomStatus status;
  final double? customRoomPrice;
  final double? customArea;
  final double? customElectricPrice;
  final double? customWaterPrice;

  const Room({
    required this.id,
    required this.floorId,
    required this.roomTypeId,
    required this.roomNumber,
    required this.status,
    this.customRoomPrice,
    this.customArea,
    this.customElectricPrice,
    this.customWaterPrice,
  });

  Room copyWith({
    String? roomTypeId,
    String? roomNumber,
    RoomStatus? status,
    double? Function()? customRoomPrice,
    double? Function()? customArea,
    double? Function()? customElectricPrice,
    double? Function()? customWaterPrice,
  }) {
    return Room(
      id: id,
      floorId: floorId,
      roomTypeId: roomTypeId ?? this.roomTypeId,
      roomNumber: roomNumber ?? this.roomNumber,
      status: status ?? this.status,
      customRoomPrice:
          customRoomPrice != null ? customRoomPrice() : this.customRoomPrice,
      customArea: customArea != null ? customArea() : this.customArea,
      customElectricPrice: customElectricPrice != null
          ? customElectricPrice()
          : this.customElectricPrice,
      customWaterPrice:
          customWaterPrice != null ? customWaterPrice() : this.customWaterPrice,
    );
  }

  factory Room.fromMap(Map<String, dynamic> map) => Room(
        id: map['id'] as String,
        floorId: map['floor_id'] as String,
        roomTypeId: map['room_type_id'] as String,
        roomNumber: map['room_number'] as String,
        status: RoomStatusX.fromDb(map['status'] as String),
        customRoomPrice: (map['custom_room_price'] as num?)?.toDouble(),
        customArea: (map['custom_area'] as num?)?.toDouble(),
        customElectricPrice:
            (map['custom_electric_price'] as num?)?.toDouble(),
        customWaterPrice: (map['custom_water_price'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'floor_id': floorId,
        'room_type_id': roomTypeId,
        'room_number': roomNumber,
        'status': status.toDb(),
        'custom_room_price': customRoomPrice,
        'custom_area': customArea,
        'custom_electric_price': customElectricPrice,
        'custom_water_price': customWaterPrice,
      };
}

/// Room đã "ráp sẵn" thông tin RoomType (áp dụng override nếu có).
/// Đây là ví dụ cho nguyên tắc: repository trả về entity đã join sẵn ở
/// tầng data, để tầng trên không quan tâm bên dưới là SQL JOIN hay
/// nhiều lần get() của Firestore.
class RoomDetail {
  final Room room;
  final String roomTypeName;
  final double area;
  final double roomPrice;
  final double electricPrice;
  final double waterPrice;
  final double internetPrice;
  final double garbagePrice;

  const RoomDetail({
    required this.room,
    required this.roomTypeName,
    required this.area,
    required this.roomPrice,
    required this.electricPrice,
    required this.waterPrice,
    required this.internetPrice,
    required this.garbagePrice,
  });
}
