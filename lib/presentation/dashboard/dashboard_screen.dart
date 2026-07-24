import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../domain/entities/invoice.dart';
import '../../domain/entities/room.dart';
import '../providers/providers.dart';
import '../widgets/section_card.dart';

class _MonthlyRevenue {
  final String monthKey;
  final double amount;
  _MonthlyRevenue(this.monthKey, this.amount);

  String get shortLabel {
    final d = AppFormatters.parseMonthKey(monthKey);
    return 'T${d.month}';
  }
}

class _DashboardStats {
  final int totalRooms;
  final int occupied;
  final int empty;
  final double revenueThisMonth; // đã thu (paid)
  final double unpaidAmountThisMonth; // chưa thu (unpaid)
  final int unpaidInvoices;
  final int unclosedMeterRooms;
  final String motelName;
  final List<_MonthlyRevenue> revenueTrend; // 6 tháng gần nhất (đã thu)

  _DashboardStats({
    required this.totalRooms,
    required this.occupied,
    required this.empty,
    required this.revenueThisMonth,
    required this.unpaidAmountThisMonth,
    required this.unpaidInvoices,
    required this.unclosedMeterRooms,
    required this.motelName,
    required this.revenueTrend,
  });
}

final _dashboardStatsProvider =
    FutureProvider.autoDispose<_DashboardStats>((ref) async {
  final owner = ref.watch(authRepositoryProvider).currentUser!;
  final motelRepo = ref.watch(motelRepositoryProvider);
  final floorRepo = ref.watch(floorRepositoryProvider);
  final roomRepo = ref.watch(roomRepositoryProvider);
  final invoiceRepo = ref.watch(invoiceRepositoryProvider);
  final meterRepo = ref.watch(meterReadingRepositoryProvider);

  var motelId = ref.watch(selectedMotelIdProvider);
  final motels = await motelRepo.getMotelsByOwner(owner.id);
  final motel = motels.firstWhere(
    (m) => m.id == motelId,
    orElse: () => motels.first,
  );
  motelId = motel.id;

  final floors = await floorRepo.getFloorsByMotel(motelId);
  int total = 0, occupied = 0, empty = 0, unclosedMeter = 0;
  final monthKey = AppFormatters.monthKey(DateTime.now());

  for (final floor in floors) {
    final rooms = await roomRepo.getRoomsByFloor(floor.id);
    for (final room in rooms) {
      total++;
      if (room.status == RoomStatus.dangThue) {
        occupied++;
        final reading = await meterRepo.getByRoomAndMonth(room.id, monthKey);
        if (reading == null) unclosedMeter++;
      } else {
        empty++;
      }
    }
  }

  // Hóa đơn tháng hiện tại (để tính đã thu / chưa thu)
  final invoicesThisMonth =
      await invoiceRepo.getInvoicesByMotel(motelId, monthKey: monthKey);
  final revenue = invoicesThisMonth
      .where((i) => i.status == InvoiceStatus.daThanhToan)
      .fold<double>(0, (sum, i) => sum + i.total);
  final unpaidAmount = invoicesThisMonth
      .where((i) => i.status == InvoiceStatus.chuaThanhToan)
      .fold<double>(0, (sum, i) => sum + i.total);
  final unpaidCount = invoicesThisMonth
      .where((i) => i.status == InvoiceStatus.chuaThanhToan)
      .length;

  // Doanh thu (đã thu) 6 tháng gần nhất, gồm cả tháng hiện tại.
  final allInvoices = await invoiceRepo.getInvoicesByMotel(motelId);
  final now = DateTime.now();
  final trend = <_MonthlyRevenue>[];
  for (var i = 5; i >= 0; i--) {
    final d = DateTime(now.year, now.month - i, 1);
    final key = AppFormatters.monthKey(d);
    final sum = allInvoices
        .where((inv) =>
            inv.monthKey == key && inv.status == InvoiceStatus.daThanhToan)
        .fold<double>(0, (s, inv) => s + inv.total);
    trend.add(_MonthlyRevenue(key, sum));
  }

  return _DashboardStats(
    totalRooms: total,
    occupied: occupied,
    empty: empty,
    revenueThisMonth: revenue,
    unpaidAmountThisMonth: unpaidAmount,
    unpaidInvoices: unpaidCount,
    unclosedMeterRooms: unclosedMeter,
    motelName: motel.name,
    revenueTrend: trend,
  );
});

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(_dashboardStatsProvider);
    final owner = ref.watch(authRepositoryProvider).currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(_dashboardStatsProvider),
          child: statsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text('Lỗi: $e')),
            data: (stats) => ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                _HeroHeader(
                    motelName: stats.motelName,
                    greetingName: owner?.displayName ?? ''),
                const SizedBox(height: 18),
                GridView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    mainAxisExtent: 104,
                  ),
                  children: [
                    _StatCard(
                        label: 'Tổng phòng',
                        value: '${stats.totalRooms}',
                        icon: Icons.door_front_door_outlined,
                        color: AppColors.primary),
                    _StatCard(
                        label: 'Đang thuê',
                        value: '${stats.occupied}',
                        icon: Icons.person,
                        color: AppColors.roomOccupied),
                    _StatCard(
                        label: 'Phòng trống',
                        value: '${stats.empty}',
                        icon: Icons.meeting_room_outlined,
                        color: AppColors.success),
                    _StatCard(
                        label: 'Doanh thu tháng',
                        value: AppFormatters.currency(stats.revenueThisMonth),
                        icon: Icons.payments_outlined,
                        color: AppColors.accent),
                  ],
                ),
                if (stats.unclosedMeterRooms > 0 ||
                    stats.unpaidInvoices > 0) ...[
                  const SizedBox(height: 18),
                  SectionCard(
                    icon: Icons.notifications_active_outlined,
                    iconColor: AppColors.warning,
                    title: 'Thông báo',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (stats.unclosedMeterRooms > 0)
                          _NoticeRow(
                              icon: Icons.speed_outlined,
                              text:
                                  'Còn ${stats.unclosedMeterRooms} phòng chưa chốt điện nước tháng này.'),
                        if (stats.unpaidInvoices > 0)
                          _NoticeRow(
                              icon: Icons.receipt_long_outlined,
                              text:
                                  'Có ${stats.unpaidInvoices} hóa đơn chưa thanh toán.'),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                SectionCard(
                  icon: Icons.pie_chart_outline,
                  iconColor: AppColors.info,
                  title: 'Tỷ lệ lấp đầy',
                  child: SizedBox(
                    height: 170,
                    child: stats.totalRooms == 0
                        ? const Center(child: Text('Chưa có dữ liệu phòng'))
                        : Row(
                            children: [
                              Expanded(
                                child: PieChart(
                                  PieChartData(
                                    sectionsSpace: 3,
                                    centerSpaceRadius: 34,
                                    sections: [
                                      PieChartSectionData(
                                        value: stats.occupied.toDouble(),
                                        color: AppColors.roomOccupied,
                                        title: '${stats.occupied}',
                                        radius: 46,
                                        titleStyle: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13),
                                      ),
                                      PieChartSectionData(
                                        value: stats.empty.toDouble(),
                                        color: AppColors.success,
                                        title: '${stats.empty}',
                                        radius: 46,
                                        titleStyle: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _LegendDot(
                                      color: AppColors.roomOccupied,
                                      label: 'Đang thuê'),
                                  const SizedBox(height: 10),
                                  _LegendDot(
                                      color: AppColors.success, label: 'Trống'),
                                ],
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 18),
                SectionCard(
                  icon: Icons.bar_chart_rounded,
                  iconColor: AppColors.primary,
                  title: 'Doanh thu 6 tháng gần nhất',
                  child: SizedBox(
                    height: 170,
                    child: !stats.revenueTrend.any((t) => t.amount > 0)
                        ? const Center(child: Text('Chưa có dữ liệu doanh thu'))
                        : _RevenueBarChart(trend: stats.revenueTrend),
                  ),
                ),
                const SizedBox(height: 18),
                SectionCard(
                  icon: Icons.account_balance_wallet_outlined,
                  iconColor: AppColors.accent,
                  title: 'Tình hình thu tiền tháng này',
                  child: _PaymentProgress(
                    paid: stats.revenueThisMonth,
                    unpaid: stats.unpaidAmountThisMonth,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroHeader extends StatelessWidget {
  final String motelName;
  final String greetingName;
  const _HeroHeader({required this.motelName, required this.greetingName});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.colored(AppColors.primary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            greetingName.isEmpty ? 'Xin chào 👋' : 'Xin chào, $greetingName 👋',
            style:
                TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13),
          ),
          const SizedBox(height: 6),
          Text(motelName,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(AppFormatters.month(DateTime.now()),
              style: TextStyle(
                  color: Colors.white.withOpacity(0.85), fontSize: 13)),
        ],
      ),
    );
  }
}

/// Thẻ thống kê chống tràn: FittedBox tự thu nhỏ chữ nếu không đủ chỗ
/// (cả chiều ngang lẫn dọc), label giới hạn 1 dòng + ellipsis. An toàn kể
/// cả khi máy người dùng đặt cỡ chữ hệ thống lớn hơn bình thường.
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(9)),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(height: 2),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                label,
                maxLines: 1,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 11.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoticeRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _NoticeRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.warning),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13.5))),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 13)),
      ],
    );
  }
}

/// Biểu đồ cột doanh thu (đã thu) 6 tháng gần nhất.
class _RevenueBarChart extends StatelessWidget {
  final List<_MonthlyRevenue> trend;
  const _RevenueBarChart({required this.trend});

  @override
  Widget build(BuildContext context) {
    final maxVal = trend.fold<double>(0, (m, t) => t.amount > m ? t.amount : m);
    final maxY = maxVal <= 0 ? 100.0 : maxVal * 1.25;

    return BarChart(
      BarChartData(
        maxY: maxY,
        alignment: BarChartAlignment.spaceAround,
        barTouchData: BarTouchData(enabled: false),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= trend.length)
                  return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(trend[idx].shortLabel,
                      style: const TextStyle(
                          fontSize: 10.5, color: AppColors.textSecondary)),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < trend.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: trend[i].amount,
                  width: 18,
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(6),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: maxY,
                    color: AppColors.primary.withOpacity(0.06),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Thanh so sánh Đã thu / Chưa thu tháng hiện tại (theo số tiền).
class _PaymentProgress extends StatelessWidget {
  final double paid;
  final double unpaid;
  const _PaymentProgress({required this.paid, required this.unpaid});

  @override
  Widget build(BuildContext context) {
    final total = paid + unpaid;
    if (total <= 0) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('Chưa có hóa đơn tháng này',
            style: TextStyle(color: AppColors.textSecondary)),
      );
    }
    final paidRatio = paid / total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 14,
            child: Row(
              children: [
                if (paidRatio > 0)
                  Expanded(
                      flex: (paidRatio * 1000).round().clamp(1, 1000),
                      child: Container(color: AppColors.success)),
                if (paidRatio < 1)
                  Expanded(
                      flex: ((1 - paidRatio) * 1000).round().clamp(1, 1000),
                      child: Container(color: AppColors.warning)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _PaymentLegend(
                  color: AppColors.success, label: 'Đã thu', amount: paid),
            ),
            Expanded(
              child: _PaymentLegend(
                  color: AppColors.warning, label: 'Chưa thu', amount: unpaid),
            ),
          ],
        ),
      ],
    );
  }
}

class _PaymentLegend extends StatelessWidget {
  final Color color;
  final String label;
  final double amount;
  const _PaymentLegend(
      {required this.color, required this.label, required this.amount});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 4),
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
              Text(AppFormatters.currency(amount),
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ],
    );
  }
}
