import '../entities/owner.dart';

/// Interface viết theo "hình dạng" của Firebase Authentication
/// (signIn/signUp/signOut/currentUser/authStateChanges) dù hiện tại bên
/// dưới chỉ là mock local. Khi có Firebase project thật, chỉ cần viết
/// AuthRepositoryFirebase implements AuthRepository, không cần sửa UI.
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
