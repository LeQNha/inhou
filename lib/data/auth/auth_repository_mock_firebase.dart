import 'dart:async';

import '../../core/id_generator.dart';
import '../../domain/entities/owner.dart';
import '../../domain/repositories/auth_repository.dart';

/// Đây là "trick" được nhắc tới trong yêu cầu: implement AuthRepository
/// với đúng hình dạng API của Firebase Authentication (signIn / signUp /
/// signOut / currentUser / authStateChanges / sendPasswordResetEmail),
/// nhưng bên dưới chỉ lưu tài khoản trong bộ nhớ (RAM), không cần
/// kết nối Internet hay cấu hình Firebase project.
///
/// Có sẵn 1 tài khoản demo để đăng nhập ngay:
///   email:    admin@motel.com
///   password: 123456
///
/// KHI MUỐN CHUYỂN SANG FIREBASE THẬT:
/// 1. Thêm package `firebase_auth` + cấu hình FlutterFire.
/// 2. Viết class AuthRepositoryFirebase implements AuthRepository, gọi
///    FirebaseAuth.instance cho từng method tương ứng.
/// 3. Đổi duy nhất 1 dòng trong providers.dart (authRepositoryProvider).
/// Toàn bộ UI, Riverpod state, và các repository khác giữ nguyên không đổi,
/// vì chúng chỉ phụ thuộc vào abstract class AuthRepository.
class AuthRepositoryMockFirebase implements AuthRepository {
  AuthRepositoryMockFirebase() {
    _seedDemoAccount();
  }

  // "Bảng" tài khoản giả lập, key = email
  final Map<String, _MockAccount> _accounts = {};

  Owner? _currentUser;
  final _controller = StreamController<Owner?>.broadcast();

  void _seedDemoAccount() {
    const demoOwnerId = 'demo-owner-id';
    const demoEmail = 'admin@motel.com';
    _accounts[demoEmail] = _MockAccount(
      owner: const Owner(
        id: demoOwnerId,
        email: demoEmail,
        displayName: 'Chủ trọ Demo',
      ),
      password: '123456',
    );
  }

  @override
  Stream<Owner?> authStateChanges() => _controller.stream;

  @override
  Owner? get currentUser => _currentUser;

  @override
  Future<Owner> signIn({required String email, required String password}) async {
    // Giả lập độ trễ mạng như gọi Firebase thật.
    await Future.delayed(const Duration(milliseconds: 500));

    final account = _accounts[email.trim().toLowerCase()];
    if (account == null) {
      throw AuthException('Tài khoản không tồn tại.');
    }
    if (account.password != password) {
      throw AuthException('Sai mật khẩu.');
    }

    _currentUser = account.owner;
    _controller.add(_currentUser);
    return account.owner;
  }

  @override
  Future<Owner> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));

    final key = email.trim().toLowerCase();
    if (_accounts.containsKey(key)) {
      throw AuthException('Email này đã được đăng ký.');
    }
    if (password.length < 6) {
      throw AuthException('Mật khẩu phải có ít nhất 6 ký tự.');
    }

    final owner = Owner(
      id: IdGenerator.newId(),
      email: key,
      displayName: displayName,
    );
    _accounts[key] = _MockAccount(owner: owner, password: password);

    _currentUser = owner;
    _controller.add(_currentUser);
    return owner;
  }

  @override
  Future<void> signOut() async {
    await Future.delayed(const Duration(milliseconds: 200));
    _currentUser = null;
    _controller.add(null);
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    await Future.delayed(const Duration(milliseconds: 400));
    if (!_accounts.containsKey(email.trim().toLowerCase())) {
      throw AuthException('Không tìm thấy tài khoản với email này.');
    }
    // Mock: không gửi email thật, chỉ giả lập thành công.
  }
}

class _MockAccount {
  final Owner owner;
  final String password;
  _MockAccount({required this.owner, required this.password});
}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => message;
}
