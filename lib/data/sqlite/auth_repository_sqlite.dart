import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../core/id_generator.dart';
import '../../domain/entities/owner.dart';
import '../../domain/repositories/auth_repository.dart';
import 'database_helper.dart';

/// Đăng nhập/đăng ký lưu trực tiếp trong SQLite (bảng `owners`), cùng
/// chung 1 database với toàn bộ dữ liệu nghiệp vụ. Tài khoản vì vậy tồn
/// tại vĩnh viễn qua các lần tắt/mở app, và tự động được gộp vào tính
/// năng sao lưu/khôi phục JSON sẵn có — không cần cơ chế lưu trữ riêng.
///
/// Mật khẩu được băm bằng SHA-256 (package `crypto`) trước khi lưu,
/// không bao giờ lưu plaintext.
///
/// Có sẵn 1 tài khoản demo (được seed sẵn trong DatabaseHelper):
///   email:    admin@motel.com
///   password: 123456
class AuthRepositorySqlite implements AuthRepository {
  final DatabaseHelper _helper;
  AuthRepositorySqlite(this._helper);

  Owner? _currentUser;
  final _controller = StreamController<Owner?>.broadcast();

  String _hash(String raw) => sha256.convert(utf8.encode(raw)).toString();

  @override
  Stream<Owner?> authStateChanges() => _controller.stream;

  @override
  Owner? get currentUser => _currentUser;

  @override
  Future<Owner> signIn(
      {required String email, required String password}) async {
    final db = await _helper.database;
    final key = email.trim().toLowerCase();

    final rows = await db.query('owners', where: 'email = ?', whereArgs: [key]);
    if (rows.isEmpty) {
      throw AuthException('Tài khoản không tồn tại.');
    }

    final row = rows.first;
    if (row['password_hash'] != _hash(password)) {
      throw AuthException('Sai mật khẩu.');
    }

    final owner = Owner(
      id: row['id'] as String,
      email: row['email'] as String,
      displayName: row['display_name'] as String,
    );
    _currentUser = owner;
    _controller.add(owner);
    return owner;
  }

  @override
  Future<Owner> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final db = await _helper.database;
    final key = email.trim().toLowerCase();

    final existing =
        await db.query('owners', where: 'email = ?', whereArgs: [key]);
    if (existing.isNotEmpty) {
      throw AuthException('Email này đã được đăng ký.');
    }
    if (password.length < 6) {
      throw AuthException('Mật khẩu phải có ít nhất 6 ký tự.');
    }

    final owner =
        Owner(id: IdGenerator.newId(), email: key, displayName: displayName);
    await db.insert('owners', {
      'id': owner.id,
      'email': owner.email,
      'display_name': owner.displayName,
      'password_hash': _hash(password),
    });

    _currentUser = owner;
    _controller.add(owner);
    return owner;
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
    _controller.add(null);
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    final db = await _helper.database;
    final rows = await db.query('owners',
        where: 'email = ?', whereArgs: [email.trim().toLowerCase()]);
    if (rows.isEmpty) {
      throw AuthException('Không tìm thấy tài khoản với email này.');
    }
    // Chưa gửi email thật (app chạy offline-first). Nếu cần khôi phục mật
    // khẩu thực sự, có thể bổ sung màn hình "đổi mật khẩu trực tiếp" sau
    // khi xác minh qua CCCD/số điện thoại đã lưu, thay vì gửi email.
  }
}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => message;
}
