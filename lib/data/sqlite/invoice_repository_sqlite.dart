import '../../domain/entities/invoice.dart';
import '../../domain/entities/payment.dart';
import '../../domain/repositories/invoice_repository.dart';
import 'database_helper.dart';

class InvoiceRepositorySqlite implements InvoiceRepository {
  final DatabaseHelper _helper;
  InvoiceRepositorySqlite(this._helper);

  @override
  Future<List<Invoice>> getInvoicesByMotel(String motelId,
      {String? monthKey}) async {
    final db = await _helper.database;
    final where = StringBuffer('''
      r.floor_id IN (SELECT id FROM floors WHERE motel_id = ?)
    ''');
    final args = <Object?>[motelId];
    if (monthKey != null) {
      where.write(' AND i.month_key = ?');
      args.add(monthKey);
    }
    final rows = await db.rawQuery('''
      SELECT i.* FROM invoices i
      JOIN rooms r ON i.room_id = r.id
      WHERE $where
      ORDER BY i.created_at DESC
    ''', args);
    return rows.map(Invoice.fromMap).toList();
  }

  @override
  Future<List<Invoice>> getInvoicesByRoom(String roomId) async {
    final db = await _helper.database;
    final rows = await db.query('invoices',
        where: 'room_id = ?', whereArgs: [roomId], orderBy: 'month_key DESC');
    return rows.map(Invoice.fromMap).toList();
  }

  @override
  Future<Invoice?> getInvoiceById(String id) async {
    final db = await _helper.database;
    final rows = await db.query('invoices', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Invoice.fromMap(rows.first);
  }

  @override
  Future<void> addInvoice(Invoice invoice) async {
    final db = await _helper.database;
    await db.insert('invoices', invoice.toMap());
  }

  @override
  Future<void> updateInvoiceStatus(String id, InvoiceStatus status) async {
    final db = await _helper.database;
    await db.update('invoices', {'status': status.toDb()},
        where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> addPayment(Payment payment) async {
    final db = await _helper.database;
    await db.insert('payments', payment.toMap());
  }

  @override
  Future<List<Payment>> getPaymentsByInvoice(String invoiceId) async {
    final db = await _helper.database;
    final rows = await db.query('payments',
        where: 'invoice_id = ?', whereArgs: [invoiceId], orderBy: 'paid_at DESC');
    return rows.map(Payment.fromMap).toList();
  }
}
