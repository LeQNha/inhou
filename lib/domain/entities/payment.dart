class Payment {
  final String id;
  final String invoiceId;
  final double amount;
  final DateTime paidAt;
  final String method; // tiền mặt / chuyển khoản...

  const Payment({
    required this.id,
    required this.invoiceId,
    required this.amount,
    required this.paidAt,
    required this.method,
  });

  factory Payment.fromMap(Map<String, dynamic> map) => Payment(
        id: map['id'] as String,
        invoiceId: map['invoice_id'] as String,
        amount: (map['amount'] as num).toDouble(),
        paidAt: DateTime.parse(map['paid_at'] as String),
        method: map['method'] as String,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'invoice_id': invoiceId,
        'amount': amount,
        'paid_at': paidAt.toIso8601String(),
        'method': method,
      };
}
