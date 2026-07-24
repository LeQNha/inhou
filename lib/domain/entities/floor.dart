class Floor {
  final String id;
  final String motelId;
  final String name; // ví dụ: "Tầng 1"
  final int order;

  const Floor({
    required this.id,
    required this.motelId,
    required this.name,
    required this.order,
  });

  factory Floor.fromMap(Map<String, dynamic> map) => Floor(
        id: map['id'] as String,
        motelId: map['motel_id'] as String,
        name: map['name'] as String,
        order: map['sort_order'] as int,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'motel_id': motelId,
        'name': name,
        'sort_order': order,
      };
}
