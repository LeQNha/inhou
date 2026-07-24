class Motel {
  final String id;
  final String ownerId;
  final String name;
  final String address;
  final double defaultElectricPrice;
  final double defaultWaterPrice;
  final double defaultGarbagePrice;

  const Motel({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.address,
    required this.defaultElectricPrice,
    required this.defaultWaterPrice,
    required this.defaultGarbagePrice,
  });

  Motel copyWith({
    String? name,
    String? address,
    double? defaultElectricPrice,
    double? defaultWaterPrice,
    double? defaultGarbagePrice,
  }) {
    return Motel(
      id: id,
      ownerId: ownerId,
      name: name ?? this.name,
      address: address ?? this.address,
      defaultElectricPrice: defaultElectricPrice ?? this.defaultElectricPrice,
      defaultWaterPrice: defaultWaterPrice ?? this.defaultWaterPrice,
      defaultGarbagePrice: defaultGarbagePrice ?? this.defaultGarbagePrice,
    );
  }

  factory Motel.fromMap(Map<String, dynamic> map) => Motel(
        id: map['id'] as String,
        ownerId: map['owner_id'] as String,
        name: map['name'] as String,
        address: map['address'] as String,
        defaultElectricPrice: (map['default_electric_price'] as num).toDouble(),
        defaultWaterPrice: (map['default_water_price'] as num).toDouble(),
        defaultGarbagePrice: (map['default_garbage_price'] as num).toDouble(),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'owner_id': ownerId,
        'name': name,
        'address': address,
        'default_electric_price': defaultElectricPrice,
        'default_water_price': defaultWaterPrice,
        'default_garbage_price': defaultGarbagePrice,
      };
}
