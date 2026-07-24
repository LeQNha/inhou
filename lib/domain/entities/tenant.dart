class Tenant {
  final String id;
  final String roomId;
  final String fullName;
  final String cccd;
  final DateTime? dob;
  final String phone;
  final DateTime moveInDate;
  final double deposit;
  final String note;

  const Tenant({
    required this.id,
    required this.roomId,
    required this.fullName,
    required this.cccd,
    this.dob,
    required this.phone,
    required this.moveInDate,
    required this.deposit,
    this.note = '',
  });

  factory Tenant.fromMap(Map<String, dynamic> map) => Tenant(
        id: map['id'] as String,
        roomId: map['room_id'] as String,
        fullName: map['full_name'] as String,
        cccd: map['cccd'] as String,
        dob: map['dob'] == null ? null : DateTime.parse(map['dob'] as String),
        phone: map['phone'] as String,
        moveInDate: DateTime.parse(map['move_in_date'] as String),
        deposit: (map['deposit'] as num).toDouble(),
        note: map['note'] as String? ?? '',
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'room_id': roomId,
        'full_name': fullName,
        'cccd': cccd,
        'dob': dob?.toIso8601String(),
        'phone': phone,
        'move_in_date': moveInDate.toIso8601String(),
        'deposit': deposit,
        'note': note,
      };
}
