import 'package:flutter/material.dart';

import '../dashboard/dashboard_screen.dart';
import '../floor/floor_list_screen.dart';
import '../invoice/invoice_list_screen.dart';
import '../settings/settings_screen.dart';

/// Khung chính của app sau khi đăng nhập: bottom navigation 4 tab.
///
/// LƯU Ý QUAN TRỌNG: mỗi tab tự tải dữ liệu 1 lần trong initState (không
/// dùng Riverpod FutureProvider theo dõi thay đổi real-time). Nếu chỉ dùng
/// IndexedStack thông thường, Flutter sẽ giữ nguyên State của cả 4 tab
/// suốt vòng đời app -> dữ liệu tải 1 lần đầu rồi thôi, dẫn tới tình trạng
/// "tạo hóa đơn ở màn hình khác xong quay lại tab Hóa đơn vẫn không thấy
/// gì" (dữ liệu cũ/stale). Để sửa, mỗi khi người dùng BẤM vào 1 tab, ta
/// đổi `ValueKey` của tab đó -> Flutter buộc phải hủy widget cũ và tạo
/// widget MỚI cho tab đó -> initState chạy lại -> dữ liệu luôn mới khi
/// mở lại tab, mà vẫn giữ được cảm giác mượt của IndexedStack.
class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _index = 0;

  // Mỗi tab có 1 "epoch" riêng, tăng lên mỗi lần tab đó được chọn.
  final Map<int, int> _epoch = {0: 0, 1: 0, 2: 0, 3: 0};

  void _onDestinationSelected(int i) {
    setState(() {
      _index = i;
      _epoch[i] = (_epoch[i] ?? 0) + 1;
    });
  }

  List<Widget> _buildTabs() {
    return [
      DashboardScreen(key: ValueKey('dashboard-${_epoch[0]}')),
      FloorListScreen(key: ValueKey('floors-${_epoch[1]}')),
      InvoiceListScreen(key: ValueKey('invoices-${_epoch[2]}')),
      SettingsScreen(key: ValueKey('settings-${_epoch[3]}')),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _buildTabs()),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _onDestinationSelected,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Tổng quan',
          ),
          NavigationDestination(
            icon: Icon(Icons.apartment_outlined),
            selectedIcon: Icon(Icons.apartment),
            label: 'Tầng & phòng',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Hóa đơn',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Cài đặt',
          ),
        ],
      ),
    );
  }
}
