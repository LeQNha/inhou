import '../entities/owner.dart';

/// Interface xác thực (đăng nhập/đăng ký/đăng xuất), tách khỏi phần cài
/// đặt cụ thể theo đúng Repository Pattern dùng chung cho cả app. Hiện
/// tại được cài đặt bởi AuthRepositorySqlite (lưu tài khoản trực tiếp
/// trong SQLite cùng database với dữ liệu nghiệp vụ).
abstract class AuthRepository {
  Stream<Owner?> authStateChanges();

  Owner? get currentUser;

  Future<Owner> signIn({required String email, required String password});

  Future<Owner> signUp({
    required String email,
    required String password,
    required String displayName,
  });

  Future<void> signOut();

  Future<void> sendPasswordResetEmail(String email);
}
