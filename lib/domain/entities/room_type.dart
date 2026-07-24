/// "Loại phòng" (Room Template) - tránh phải nhập lặp lại giá/diện tích
/// cho từng phòng giống nhau. Mỗi Room chỉ cần tham chiếu tới 1 RoomType,
/// và có thể override từng trường riêng nếu cần (xem Room.customXxx).
class RoomType {
  final String id;
  final String motelId;
  final String name; // Tiêu chuẩn / Góc / VIP / Studio...
  final double area;
  final double roomPrice;
  final double electricPrice;
  final double waterPrice;
  final double internetPrice;
  final double garbagePrice;

  const RoomType({
    required this.id,
    required this.motelId,
    required this.name,
    required this.area,
    required this.roomPrice,
    required this.electricPrice,
    required this.waterPrice,
    required this.internetPrice,
    required this.garbagePrice,
  });

  RoomType copyWith({
    String? name,
    double? area,
    double? roomPrice,
    double? electricPrice,
    double? waterPrice,
    double? internetPrice,
    double? garbagePrice,
  }) {
    return RoomType(
      id: id,
      motelId: motelId,
      name: name ?? this.name,
      area: area ?? this.area,
      roomPrice: roomPrice ?? this.roomPrice,
      electricPrice: electricPrice ?? this.electricPrice,
      waterPrice: waterPrice ?? this.waterPrice,
      internetPrice: internetPrice ?? this.internetPrice,
      garbagePrice: garbagePrice ?? this.garbagePrice,
    );
  }

  factory RoomType.fromMap(Map<String, dynamic> map) => RoomType(
        id: map['id'] as String,
        motelId: map['motel_id'] as String,
        name: map['name'] as String,
        area: (map['area'] as num).toDouble(),
        roomPrice: (map['room_price'] as num).toDouble(),
        electricPrice: (map['electric_price'] as num).toDouble(),
        waterPrice: (map['water_price'] as num).toDouble(),
        internetPrice: (map['internet_price'] as num).toDouble(),
        garbagePrice: (map['garbage_price'] as num).toDouble(),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'motel_id': motelId,
        'name': name,
        'area': area,
        'room_price': roomPrice,
        'electric_price': electricPrice,
        'water_price': waterPrice,
        'internet_price': internetPrice,
        'garbage_price': garbagePrice,
      };
}
