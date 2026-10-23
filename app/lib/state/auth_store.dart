import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Firebase Auth(メール/パスワード)でのログイン状態を管理する。
///
/// Firebase UIDは、サーバーAPIとDBでユーザー所有データを分離するために使う。
/// サインアウト時には通知用のFCMトークン解除を先に試みる。
class AuthStore extends ChangeNotifier {
  AuthStore({FirebaseAuth? firebaseAuth})
    : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance {
    _authSubscription = _firebaseAuth.authStateChanges().listen((user) {
      currentUser = user;
      // FirebaseAuthからの最初のイベントを受け取った、という印。
      // これが立つまでは「未ログイン」と断定せずローディング扱いにする
      // (AuthGate参照。でないと、実際にはログイン済みの端末でも
      // 起動直後の一瞬だけログイン画面がちらつくことになる)。
      hasResolvedInitialState = true;
      notifyListeners();
    });
  }

  final FirebaseAuth _firebaseAuth;
  late final StreamSubscription<User?> _authSubscription;

  User? currentUser;
  bool hasResolvedInitialState = false;

  bool isSubmitting = false;
  String? errorMessage;
  String? _lastErrorCode;
  Future<void> Function()? beforeSignOut;

  bool get isSignedIn => currentUser != null;
  bool get shouldOfferRegistration =>
      _lastErrorCode == 'user-not-found' ||
      _lastErrorCode == 'invalid-credential';

  Future<bool> signIn({required String email, required String password}) {
    return _submit(
      () => _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      ),
    );
  }

  Future<bool> register({required String email, required String password}) {
    return _submit(
      () => _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      ),
    );
  }

  Future<void> signOut() async {
    await beforeSignOut?.call();
    await _firebaseAuth.signOut();
  }

  Future<bool> _submit(Future<UserCredential> Function() action) async {
    isSubmitting = true;
    errorMessage = null;
    _lastErrorCode = null;
    notifyListeners();
    try {
      await action();
      // 成功するとauthStateChangesが発火してcurrentUserが更新されるため、
      // ここで明示的にcurrentUserを代入する必要はない。
      return true;
    } on FirebaseAuthException catch (e) {
      _lastErrorCode = e.code;
      errorMessage = _messageFor(e.code);
      return false;
    } catch (_) {
      errorMessage = '通信エラーが発生しました。もう一度お試しください。';
      return false;
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }

  /// FirebaseAuthExceptionのcode(英語の識別子)を、画面表示用の日本語に変換する。
  /// 参考: https://firebase.google.com/docs/auth/admin/errors
  String _messageFor(String code) {
    switch (code) {
      case 'invalid-email':
        return 'メールアドレスの形式が正しくありません';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'メールアドレスまたはパスワードが正しくありません';
      case 'user-disabled':
        return 'このアカウントは無効化されています';
      case 'email-already-in-use':
        return 'このメールアドレスは既に登録されています';
      case 'weak-password':
        return 'パスワードは6文字以上で設定してください';
      case 'too-many-requests':
        return '試行回数が多すぎます。しばらくしてからお試しください';
      case 'network-request-failed':
        return '通信エラーが発生しました。ネットワーク接続を確認してください';
      case 'api-key-not-valid':
        return 'FirebaseのAPIキーが無効です。.envのFIREBASE_WEB_API_KEYをFirebase Consoleから再コピーしてください';
      default:
        return '認証できませんでした($code)';
    }
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }
}
