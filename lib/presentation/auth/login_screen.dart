import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_theme.dart';
import '../providers/providers.dart';
import '../widgets/gradient_header.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController(text: 'admin@motel.com');
  final _passwordCtrl = TextEditingController(text: '123456');
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final authRepo = ref.read(authRepositoryProvider);
      final owner = await authRepo.signIn(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );

      if (!mounted) return;

      final motelRepo = ref.read(motelRepositoryProvider);
      final motels = await motelRepo.getMotelsByOwner(owner.id);

      if (!mounted) return;
      if (motels.isEmpty) {
        context.go('/wizard');
      } else {
        ref.read(selectedMotelIdProvider.notifier).state = motels.first.id;
        context.go('/dashboard');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          child: Column(
            children: [
              GradientHeader(
                height: 230,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.apartment_rounded,
                            size: 42, color: Colors.white),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Smart Motel Manager',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Quản lý phòng trọ thông minh',
                        style: TextStyle(color: Colors.white.withOpacity(0.85)),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      boxShadow: AppShadows.soft,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Đăng nhập',
                              style: Theme.of(context).textTheme.headlineSmall),
                          const SizedBox(height: 4),
                          const Text('Chào mừng chủ trọ quay trở lại 👋',
                              style: TextStyle(color: AppColors.textSecondary)),
                          const SizedBox(height: 22),
                          TextFormField(
                            controller: _emailCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) =>
                                (v == null || v.isEmpty) ? 'Nhập email' : null,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _passwordCtrl,
                            decoration: InputDecoration(
                              labelText: 'Mật khẩu',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(_obscure
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined),
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                              ),
                            ),
                            obscureText: _obscure,
                            validator: (v) => (v == null || v.isEmpty)
                                ? 'Nhập mật khẩu'
                                : null,
                          ),
                          const SizedBox(height: 22),
                          ElevatedButton(
                            onPressed: _loading ? null : _handleLogin,
                            child: _loading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text('Đăng nhập'),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () => context.push('/signup'),
                            child:
                                const Text('Chưa có tài khoản? Đăng ký ngay'),
                          ),
                          const SizedBox(height: 12),
                          // Container(
                          //   padding: const EdgeInsets.all(14),
                          //   decoration: BoxDecoration(
                          //     color: AppColors.infoSoft,
                          //     borderRadius: BorderRadius.circular(AppRadius.sm),
                          //   ),
                          //   child: Row(
                          //     crossAxisAlignment: CrossAxisAlignment.start,
                          //     children: [
                          //       const Icon(Icons.info_outline, size: 18, color: AppColors.info),
                          //       const SizedBox(width: 10),
                          //       Expanded(
                          //         child: RichText(
                          //           text: const TextSpan(
                          //             style: TextStyle(fontSize: 12.5, color: AppColors.textPrimary, height: 1.4),
                          //             children: [
                          //               TextSpan(text: 'Tài khoản demo: ', style: TextStyle(fontWeight: FontWeight.w700)),
                          //               TextSpan(text: 'admin@motel.com / 123456\n'),
                          //               TextSpan(text: 'Đang dùng xác thực giả lập cục bộ theo đúng hình dạng Firebase Authentication.'),
                          //             ],
                          //           ),
                          //         ),
                          //       ),
                          //     ],
                          //   ),
                          // ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
