// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';

// import 'core/app_theme.dart';
// import 'presentation/router/app_router.dart';

// void main() {
//   runApp(const ProviderScope(child: SmartMotelManagerApp()));
// }

// class SmartMotelManagerApp extends StatelessWidget {
//   const SmartMotelManagerApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp.router(
//       title: 'Smart Motel Manager',
//       debugShowCheckedModeBanner: false,
//       theme: AppTheme.light,
//       routerConfig: appRouter,
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_theme.dart';
import 'presentation/router/app_router.dart';

void main() {
  runApp(const ProviderScope(child: SmartMotelManagerApp()));
}

class SmartMotelManagerApp extends StatelessWidget {
  const SmartMotelManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Smart Motel Manager',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: appRouter,
      // Giới hạn hệ số phóng chữ (Text Scale) trong khoảng 0.9x - 1.15x.
      // Nguyên nhân của lỗi "BOTTOM OVERFLOWED" ở Dashboard là do máy đang
      // đặt cỡ chữ hệ thống lớn hơn bình thường, khiến nội dung trong các
      // khung có chiều cao cố định (thẻ thống kê...) bị tràn. Thay vì để
      // mỗi màn hình tự chống tràn, chặn ở đây 1 lần cho toàn bộ app.
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        final clampedScaler =
            mq.textScaler.clamp(minScaleFactor: 0.9, maxScaleFactor: 1.15);
        return MediaQuery(
          data: mq.copyWith(textScaler: clampedScaler),
          child: child!,
        );
      },
    );
  }
}
