import '../entities/meter_reading.dart';

abstract class MeterReadingRepository {
  Future<List<MeterReading>> getHistoryByRoom(String roomId);
  Future<MeterReading?> getByRoomAndMonth(String roomId, String monthKey);

  /// Lấy chỉ số MỚI của tháng liền trước để gợi ý làm chỉ số CŨ của tháng này.
  Future<MeterReading?> getLatestBeforeMonth(String roomId, String monthKey);

  Future<void> addReading(MeterReading reading);
  Future<void> updateReading(MeterReading reading);
}
