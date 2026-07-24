import 'package:go_router/go_router.dart';

import '../auth/login_screen.dart';
import '../auth/signup_screen.dart';
import '../dashboard/main_shell_screen.dart';
import '../floor/floor_list_screen.dart';
import '../invoice/invoice_detail_screen.dart';
import '../invoice/invoice_list_screen.dart';
import '../invoice/vietqr_screen.dart';
import '../meter/meter_reading_screen.dart';
import '../meter/ocr_meter_screen.dart';
import '../room/room_detail_screen.dart';
import '../room_type/room_type_list_screen.dart';
import '../settings/backup_restore_screen.dart';
import '../tenant/qr_cccd_scan_screen.dart';
import '../tenant/tenant_form_screen.dart';
import '../wizard/setup_wizard_screen.dart';

/// Điều hướng đơn giản, không dùng redirect guard phức tạp: mỗi màn hình
/// tự quyết định điều hướng tiếp theo (ví dụ LoginScreen tự kiểm tra đã có
/// nhà trọ hay chưa để quyết định vào /wizard hay /dashboard). Phù hợp với
/// quy mô đồ án và tránh các lỗi khó debug với async redirect.
final appRouter = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(
        path: '/signup', builder: (context, state) => const SignupScreen()),
    GoRoute(
        path: '/wizard', builder: (context, state) => const SetupWizardScreen()),
    GoRoute(
        path: '/dashboard', builder: (context, state) => const MainShellScreen()),
    GoRoute(
        path: '/floors',
        builder: (context, state) => const FloorListScreen()),
    GoRoute(
        path: '/room-types',
        builder: (context, state) => const RoomTypeListScreen()),
    GoRoute(
      path: '/room/:roomId',
      builder: (context, state) =>
          RoomDetailScreen(roomId: state.pathParameters['roomId']!),
    ),
    GoRoute(
      path: '/room/:roomId/tenant',
      builder: (context, state) =>
          TenantFormScreen(roomId: state.pathParameters['roomId']!),
    ),
    GoRoute(
      path: '/room/:roomId/qr-scan',
      builder: (context, state) =>
          QrCccdScanScreen(roomId: state.pathParameters['roomId']!),
    ),
    GoRoute(
      path: '/room/:roomId/meter',
      builder: (context, state) =>
          MeterReadingScreen(roomId: state.pathParameters['roomId']!),
    ),
    GoRoute(
      path: '/room/:roomId/meter/ocr',
      builder: (context, state) =>
          OcrMeterScreen(roomId: state.pathParameters['roomId']!),
    ),
    GoRoute(
        path: '/invoices',
        builder: (context, state) => const InvoiceListScreen()),
    GoRoute(
      path: '/invoice/:invoiceId',
      builder: (context, state) =>
          InvoiceDetailScreen(invoiceId: state.pathParameters['invoiceId']!),
    ),
    GoRoute(
      path: '/invoice/:invoiceId/vietqr',
      builder: (context, state) =>
          VietQrScreen(invoiceId: state.pathParameters['invoiceId']!),
    ),
    GoRoute(
        path: '/backup',
        builder: (context, state) => const BackupRestoreScreen()),
  ],
);
