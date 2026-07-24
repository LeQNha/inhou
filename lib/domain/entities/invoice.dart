enum InvoiceStatus { chuaThanhToan, daThanhToan }

extension InvoiceStatusX on InvoiceStatus {
  String get label =>
      this == InvoiceStatus.daThanhToan ? 'Đã thanh toán' : 'Chưa thanh toán';

  static InvoiceStatus fromDb(String v) =>
      v == 'da_thanh_toan' ? InvoiceStatus.daThanhToan : InvoiceStatus.chuaThanhToan;

  String toDb() =>
      this == InvoiceStatus.daThanhToan ? 'da_thanh_toan' : 'chua_thanh_toan';
}

class Invoice {
  final String id;
  final String roomId;
  final String monthKey;
  final double roomPrice;
  final double electricAmount;
  final double waterAmount;
  final double garbagePrice;
  final double internetPrice;
  final double otherFee;
  final InvoiceStatus status;
  final DateTime createdAt;

  const Invoice({
    required this.id,
    required this.roomId,
    required this.monthKey,
    required this.roomPrice,
    required this.electricAmount,
    required this.waterAmount,
    required this.garbagePrice,
    required this.internetPrice,
    required this.otherFee,
    required this.status,
    required this.createdAt,
  });

  double get total =>
      roomPrice + electricAmount + waterAmount + garbagePrice + internetPrice + otherFee;

  Invoice copyWith({InvoiceStatus? status}) => Invoice(
        id: id,
        roomId: roomId,
        monthKey: monthKey,
        roomPrice: roomPrice,
        electricAmount: electricAmount,
        waterAmount: waterAmount,
        garbagePrice: garbagePrice,
        internetPrice: internetPrice,
        otherFee: otherFee,
        status: status ?? this.status,
        createdAt: createdAt,
      );

  factory Invoice.fromMap(Map<String, dynamic> map) => Invoice(
        id: map['id'] as String,
        roomId: map['room_id'] as String,
        monthKey: map['month_key'] as String,
        roomPrice: (map['room_price'] as num).toDouble(),
        electricAmount: (map['electric_amount'] as num).toDouble(),
        waterAmount: (map['water_amount'] as num).toDouble(),
        garbagePrice: (map['garbage_price'] as num).toDouble(),
        internetPrice: (map['internet_price'] as num).toDouble(),
        otherFee: (map['other_fee'] as num).toDouble(),
        status: InvoiceStatusX.fromDb(map['status'] as String),
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'room_id': roomId,
        'month_key': monthKey,
        'room_price': roomPrice,
        'electric_amount': electricAmount,
        'water_amount': waterAmount,
        'garbage_price': garbagePrice,
        'internet_price': internetPrice,
        'other_fee': otherFee,
        'status': status.toDb(),
        'created_at': createdAt.toIso8601String(),
      };
}
