import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

/// 未スタブのメンバー呼び出しをUnimplementedErrorに変換するための土台。
///
/// `mockito`の`Mock`クラスと同じ考え方: `implements`で本物のクラスの型を
/// 名乗りつつ、noSuchMethodを用意しておくことで「使うメンバーだけ
/// overrideすれば残りは実装不要」にできる。テスト用に新しいpub依存を
/// 追加せずに済ませるため、ここだけ手書きにしている。
class _NoSuchMethodFallback {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError(
      'このテスト用フェイクでは ${invocation.memberName} をスタブしていません。'
      '必要になったら fake_firebase_auth.dart 側でoverrideしてください。',
    );
  }
}

/// [FirebaseAuth]の最小限のフェイク実装。
///
/// [AuthStore]のコンストラクタが`FirebaseAuth?`を受け取れる設計になっている
/// ことを利用し、本物の`FirebaseAuth.instance`(=`Firebase.initializeApp()`が
/// 必要)を経由せずに`authStateChanges()`の発火タイミングを完全にテスト側で
/// 制御する。
///
/// 使い方: [emit]でログイン状態の変化(ユーザーあり/なし)を模擬する。
/// 一度も[emit]しなければ「FirebaseAuthからの最初の通知がまだ来ていない」
/// 状態(=[AuthStore.hasResolvedInitialState]がfalseのまま)を再現できる。
class FakeFirebaseAuth extends _NoSuchMethodFallback implements FirebaseAuth {
  FakeFirebaseAuth() : _controller = StreamController<User?>.broadcast();

  final StreamController<User?> _controller;

  /// authStateChanges()経由でログイン状態の変化を流す。
  /// nullを渡すと「未ログイン」、[FakeUser]等の非null値で「ログイン済み」を表す。
  void emit(User? user) => _controller.add(user);

  @override
  Stream<User?> authStateChanges() => _controller.stream;

  @override
  User? get currentUser => null;

  @override
  Future<void> signOut() async {}

  void dispose() => _controller.close();
}

/// [User]の最小限のフェイク実装。中身は使わず「非null=ログイン済み」の
/// 目印としてのみ使う(AuthGateの分岐は`currentUser != null`しか見ないため)。
class FakeUser extends _NoSuchMethodFallback implements User {}
