import '../entities/invoice.dart';
import '../entities/payment.dart';

abstract class InvoiceRepository {
  Future<List<Invoice>> getInvoicesByMotel(String motelId, {String? monthKey});
  Future<List<Invoice>> getInvoicesByRoom(String roomId);
  Future<Invoice?> getInvoiceById(String id);

  Future<void> addInvoice(Invoice invoice);
  Future<void> updateInvoiceStatus(String id, InvoiceStatus status);

  Future<void> addPayment(Payment payment);
  Future<List<Payment>> getPaymentsByInvoice(String invoiceId);
}
