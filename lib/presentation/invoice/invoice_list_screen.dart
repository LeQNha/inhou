import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../domain/entities/invoice.dart';
import '../providers/providers.dart';
import '../widgets/status_badge.dart';

class _InvoiceRow {
  final Invoice invoice;
  final String roomNumber;
  _InvoiceRow(this.invoice, this.roomNumber);
}

class InvoiceListScreen extends ConsumerStatefulWidget {
  const InvoiceListScreen({super.key});

  @override
  ConsumerState<InvoiceListScreen> createState() => _InvoiceListScreenState();
}

class _InvoiceListScreenState extends ConsumerState<InvoiceListScreen> {
  List<_InvoiceRow> _rows = [];
  bool _loading = true;
  String _monthKey = AppFormatters.monthKey(DateTime.now());
  InvoiceStatus? _statusFilter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final owner = ref.read(authRepositoryProvider).currentUser!;
    final motels =
        await ref.read(motelRepositoryProvider).getMotelsByOwner(owner.id);
    final motelId = ref.read(selectedMotelIdProvider) ?? motels.first.id;

    final invoices = await ref
        .read(invoiceRepositoryProvider)
        .getInvoicesByMotel(motelId, monthKey: _monthKey);

    final roomRepo = ref.read(roomRepositoryProvider);
    final rows = <_InvoiceRow>[];
    for (final inv in invoices) {
      final detail = await roomRepo.getRoomDetailById(inv.roomId);
      rows.add(_InvoiceRow(inv, detail?.room.roomNumber ?? '?'));
    }
    rows.sort((a, b) => a.roomNumber.compareTo(b.roomNumber));

    if (!mounted) return;
    setState(() {
      _rows = rows;
      _loading = false;
    });
  }

  Future<void> _pickMonth() async {
    final current = AppFormatters.parseMonthKey(_monthKey);
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'Chọn tháng',
    );
    if (picked == null) return;
    setState(() => _monthKey = AppFormatters.monthKey(picked));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _statusFilter == null
        ? _rows
        : _rows.where((r) => r.invoice.status == _statusFilter).toList();
    final totalUnpaid = _rows
        .where((r) => r.invoice.status == InvoiceStatus.chuaThanhToan)
        .fold<double>(0, (s, r) => s + r.invoice.total);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Hóa đơn'),
        actions: [
          TextButton.icon(
            onPressed: _pickMonth,
            icon: const Icon(Icons.calendar_month,
                size: 18, color: AppColors.primary),
            label: Text(
                AppFormatters.month(AppFormatters.parseMonthKey(_monthKey)),
                style: const TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (totalUnpaid > 0)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: AppColors.heroGradient,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      boxShadow: AppShadows.colored(AppColors.primary),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.account_balance_wallet_outlined,
                            color: Colors.white),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Tổng chưa thu tháng này',
                                  style: TextStyle(
                                      color: Colors.white70, fontSize: 12)),
                              Text(AppFormatters.currency(totalUnpaid),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 17)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                SizedBox(
                  height: 42,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _FilterChipButton(
                        label: 'Tất cả',
                        selected: _statusFilter == null,
                        onTap: () => setState(() => _statusFilter = null),
                      ),
                      const SizedBox(width: 8),
                      _FilterChipButton(
                        label: 'Chưa thanh toán',
                        selected: _statusFilter == InvoiceStatus.chuaThanhToan,
                        onTap: () => setState(
                            () => _statusFilter = InvoiceStatus.chuaThanhToan),
                      ),
                      const SizedBox(width: 8),
                      _FilterChipButton(
                        label: 'Đã thanh toán',
                        selected: _statusFilter == InvoiceStatus.daThanhToan,
                        onTap: () => setState(
                            () => _statusFilter = InvoiceStatus.daThanhToan),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(
                          child: Text('Chưa có hóa đơn nào',
                              style: TextStyle(color: AppColors.textSecondary)))
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                            itemCount: filtered.length,
                            itemBuilder: (context, i) {
                              final row = filtered[i];
                              final paid = row.invoice.status ==
                                  InvoiceStatus.daThanhToan;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.md),
                                  border: Border.all(color: AppColors.border),
                                  boxShadow: AppShadows.soft,
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 6),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(AppRadius.md)),
                                  leading: Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: (paid
                                              ? AppColors.success
                                              : AppColors.warning)
                                          .withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    alignment: Alignment.center,
                                    child: Icon(Icons.receipt_long,
                                        color: paid
                                            ? AppColors.success
                                            : AppColors.warning,
                                        size: 20),
                                  ),
                                  title: Text('Phòng ${row.roomNumber}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700)),
                                  subtitle: Text(
                                      AppFormatters.currency(row.invoice.total),
                                      style: const TextStyle(fontSize: 13)),
                                  trailing: StatusBadge(
                                    label: row.invoice.status.label,
                                    color:
                                        paid ? AppTheme.paid : AppTheme.unpaid,
                                  ),
                                  onTap: () => context
                                      .push('/invoice/${row.invoice.id}')
                                      .then((_) => _load()),
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}

/// Chip lọc tự vẽ (không dùng ChoiceChip) để đảm bảo chữ LUÔN hiển thị rõ
/// ràng ở cả 2 trạng thái chọn/không chọn, không phụ thuộc vào cách
/// ChipThemeData của Material 3 tự suy ra màu chữ (từng bị lỗi chữ trong
/// suốt ở trạng thái không được chọn khi override labelStyle ở theme).
class _FilterChipButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChipButton(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
              color: selected ? AppColors.primary : AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
