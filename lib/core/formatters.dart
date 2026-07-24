import 'package:intl/intl.dart';

class AppFormatters {
  static final _currency = NumberFormat.decimalPattern('vi_VN');
  static final _date = DateFormat('dd/MM/yyyy');
  static final _month = DateFormat('MM/yyyy');

  static String currency(num value) => '${_currency.format(value)} đ';

  static String date(DateTime d) => _date.format(d);

  static String month(DateTime d) => _month.format(d);

  /// Chuẩn hóa "tháng" dùng làm khóa lưu trữ, ví dụ: 2026-07
  static String monthKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';

  static DateTime parseMonthKey(String key) {
    final parts = key.split('-');
    return DateTime(int.parse(parts[0]), int.parse(parts[1]));
  }
}
