/// Sinh chuỗi VietQR chuẩn EMVCo / NAPAS (dùng chung bởi tất cả app ngân
/// hàng ở Việt Nam để quét chuyển khoản nhanh). Đây là chuẩn công khai do
/// NAPAS công bố, không phải thông tin bí mật của riêng ngân hàng nào.
///
/// Cấu trúc payload gồm các "field" dạng TLV (Tag-Length-Value):
///   00  Payload Format Indicator      = "01"
///   01  Point of Initiation Method    = "12" (QR động - có số tiền cố định)
///   38  Merchant Account Information  = nested field chứa GUID NAPAS + BIN
///       ngân hàng + số tài khoản + loại giao dịch
///   53  Currency                      = "704" (VND)
///   54  Amount                        = số tiền (nếu có)
///   58  Country Code                  = "VN"
///   62  Additional Data               = nested field chứa nội dung chuyển khoản
///   63  CRC                           = checksum CRC16-CCITT (XModem) của
///                                        toàn bộ chuỗi phía trước (kể cả tag+len của chính field 63)
class VietQrBank {
  final String bin; // Mã ngân hàng theo chuẩn NAPAS
  final String shortName;
  final String fullName;
  const VietQrBank(this.bin, this.shortName, this.fullName);
}

/// Danh sách một số ngân hàng phổ biến kèm mã BIN NAPAS công khai.
const List<VietQrBank> vietQrBanks = [
  VietQrBank('970436', 'Vietcombank', 'Ngân hàng TMCP Ngoại thương Việt Nam'),
  VietQrBank('970415', 'VietinBank', 'Ngân hàng TMCP Công thương Việt Nam'),
  VietQrBank('970418', 'BIDV', 'Ngân hàng TMCP Đầu tư và Phát triển VN'),
  VietQrBank('970405', 'Agribank', 'Ngân hàng Nông nghiệp và PTNT VN'),
  VietQrBank('970407', 'Techcombank', 'Ngân hàng TMCP Kỹ Thương Việt Nam'),
  VietQrBank('970422', 'MB Bank', 'Ngân hàng TMCP Quân đội'),
  VietQrBank('970416', 'ACB', 'Ngân hàng TMCP Á Châu'),
  VietQrBank('970432', 'VPBank', 'Ngân hàng TMCP Việt Nam Thịnh Vượng'),
  VietQrBank('970403', 'Sacombank', 'Ngân hàng TMCP Sài Gòn Thương Tín'),
  VietQrBank('970423', 'TPBank', 'Ngân hàng TMCP Tiên Phong'),
  VietQrBank('970441', 'VIB', 'Ngân hàng TMCP Quốc tế Việt Nam'),
  VietQrBank('970448', 'OCB', 'Ngân hàng TMCP Phương Đông'),
  VietQrBank('970431', 'Eximbank', 'Ngân hàng TMCP Xuất Nhập Khẩu VN'),
  VietQrBank('970437', 'HDBank', 'Ngân hàng TMCP Phát triển TP.HCM'),
  VietQrBank('970454', 'VietCapitalBank', 'Ngân hàng TMCP Bản Việt'),
];

class VietQrGenerator {
  static const _guid = 'A000000727'; // GUID cố định của NAPAS
  static const _serviceCodeToAccount = 'QRIBFTTA'; // chuyển tới số TÀI KHOẢN

  static String _tlv(String tag, String value) {
    final len = value.length.toString().padLeft(2, '0');
    return '$tag$len$value';
  }

  /// Build chuỗi payload đầy đủ (đã bao gồm CRC ở cuối) để encode ra QR.
  static String build({
    required String bankBin,
    required String accountNumber,
    required double amount,
    required String description,
  }) {
    final merchantAccountInfo = _tlv('00', _guid) +
        _tlv('01', _tlv('00', bankBin) + _tlv('01', accountNumber)) +
        _tlv('02', _serviceCodeToAccount);

    final additionalData = _tlv('08', _sanitize(description));

    final amountStr = amount > 0 ? amount.round().toString() : '';

    final buffer = StringBuffer()
      ..write(_tlv('00', '01'))
      ..write(_tlv('01', '12'))
      ..write(_tlv('38', merchantAccountInfo))
      ..write(_tlv('53', '704'));

    if (amountStr.isNotEmpty) {
      buffer.write(_tlv('54', amountStr));
    }

    buffer
      ..write(_tlv('58', 'VN'))
      ..write(_tlv('62', additionalData));

    // Field 63 (CRC) luôn được tính trên toàn bộ chuỗi trước đó CỘNG với
    // tag+length "6304" của chính nó (nhưng chưa gồm 4 ký tự CRC).
    final withCrcTag = '${buffer.toString()}6304';
    final crc = _crc16Ccitt(withCrcTag);
    return '$withCrcTag$crc';
  }

  /// Loại bỏ ký tự có dấu tiếng Việt vì chuẩn EMVCo yêu cầu payload là
  /// ASCII (giống cách các app ngân hàng tự chuyển "Chuyển khoản" ->
  /// "Chuyen khoan" khi sinh mã).
  static String _sanitize(String input) {
    const from =
        'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ'
        'ÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴÈÉẸẺẼÊỀẾỆỂỄÌÍỊỈĨÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠÙÚỤỦŨƯỪỨỰỬỮỲÝỴỶỸĐ';
    const to =
        'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiioooooooooooooooooouuuuuuuuuuuyyyyyd'
        'AAAAAAAAAAAAAAAAAEEEEEEEEEEEIIIIIOOOOOOOOOOOOOOOOOUUUUUUUUUUUYYYYYD';
    var result = input;
    for (var i = 0; i < from.length; i++) {
      result = result.replaceAll(from[i], to[i]);
    }
    return result.replaceAll(RegExp(r'[^A-Za-z0-9 ]'), '').trim();
  }

  /// CRC16-CCITT (XModem), polynomial 0x1021, init 0xFFFF - đúng chuẩn EMVCo.
  static String _crc16Ccitt(String data) {
    const polynomial = 0x1021;
    var crc = 0xFFFF;
    for (final byte in data.codeUnits) {
      crc ^= (byte << 8);
      for (var i = 0; i < 8; i++) {
        if ((crc & 0x8000) != 0) {
          crc = ((crc << 1) ^ polynomial) & 0xFFFF;
        } else {
          crc = (crc << 1) & 0xFFFF;
        }
      }
    }
    return crc.toRadixString(16).toUpperCase().padLeft(4, '0');
  }
}
