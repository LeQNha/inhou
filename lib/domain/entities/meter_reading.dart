class MeterReading {
  final String id;
  final String roomId;
  final String monthKey; // yyyy-MM
  final double oldElectric;
  final double newElectric;
  final double oldWater;
  final double newWater;

  const MeterReading({
    required this.id,
    required this.roomId,
    required this.monthKey,
    required this.oldElectric,
    required this.newElectric,
    required this.oldWater,
    required this.newWater,
  });

  double get electricUsage => newElectric - oldElectric;
  double get waterUsage => newWater - oldWater;

  bool get isValid => newElectric >= oldElectric && newWater >= oldWater;

  factory MeterReading.fromMap(Map<String, dynamic> map) => MeterReading(
        id: map['id'] as String,
        roomId: map['room_id'] as String,
        monthKey: map['month_key'] as String,
        oldElectric: (map['old_electric'] as num).toDouble(),
        newElectric: (map['new_electric'] as num).toDouble(),
        oldWater: (map['old_water'] as num).toDouble(),
        newWater: (map['new_water'] as num).toDouble(),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'room_id': roomId,
        'month_key': monthKey,
        'old_electric': oldElectric,
        'new_electric': newElectric,
        'old_water': oldWater,
        'new_water': newWater,
      };
}
