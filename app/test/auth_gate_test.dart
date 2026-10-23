import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:plant_monitoring_app/repositories/dummy_plant_repository.dart';
import 'package:plant_monitoring_app/screens/app_root.dart';
import 'package:plant_monitoring_app/screens/auth/login_page.dart';
import 'package:plant_monitoring_app/screens/auth_gate.dart';
import 'package:plant_monitoring_app/state/auth_store.dart';
import 'package:plant_monitoring_app/state/auth_store_scope.dart';
import 'package:plant_monitoring_app/state/plant_store.dart';
import 'package:plant_monitoring_app/state/plant_store_scope.dart';

import 'support/fake_firebase_auth.dart';

/// [AuthGate]がFirebase Authのログイン状態に応じて正しい画面へ
/// 振り分けることを検証する。
///
/// widget_test.dart・app_root_test.dartは[TestApp](support/test_app.dart)で
/// [AuthGate]自体を取り除いた簡易シェルを使っているため、ログイン画面の
/// 出し分けそのものはカバーされていない(test_app.dartのコメント参照)。
/// このファイルはその対になる、AuthGate専用のテスト。
///
/// 本物のFirebase初期化(`Firebase.initializeApp()`)を避けるため、
/// [AuthStore]へ[FakeFirebaseAuth]を注入している。
void main() {
  /// [AuthGate]を、本物のmain.dartと同じ並び順のScope
  /// (AuthStoreScope → PlantStoreScope)でラップして描画する。
  ///
  /// [AppRoot]配下(ログイン済みの場合に表示される)は`PlantStoreScope`を
  /// 参照するため、ダミーのPlantStoreを併せて用意する。ここでは
  /// AuthGateの出し分け自体の検証が目的なので、PlantStore側の読み込み完了は
  /// 待たない(=AppRootが出ていることさえ確認できればよい)。
  Future<AuthStore> pumpAuthGate(
    WidgetTester tester, {
    required FakeFirebaseAuth fakeAuth,
    bool needsPlantRegistration = false,
  }) async {
    final authStore = AuthStore(firebaseAuth: fakeAuth);
    addTearDown(authStore.dispose);
    final plantStore = PlantStore(DummyPlantRepository());
    plantStore.needsRegistration = needsPlantRegistration;
    addTearDown(plantStore.dispose);

    await tester.pumpWidget(
      AuthStoreScope(
        store: authStore,
        child: PlantStoreScope(
          store: plantStore,
          child: const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: AuthGate(),
          ),
        ),
      ),
    );
    return authStore;
  }

  testWidgets('FirebaseAuthからの初回通知が来るまではローディング表示のみ', (tester) async {
    final fakeAuth = FakeFirebaseAuth();
    addTearDown(fakeAuth.dispose);

    // emit()を一度も呼ばない = authStateChanges()がまだ何も発火していない状態。
    await pumpAuthGate(tester, fakeAuth: fakeAuth);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(LoginPage), findsNothing);
    expect(find.byType(AppRoot), findsNothing);
  });

  testWidgets('未ログインの場合はLoginPageを表示する', (tester) async {
    final fakeAuth = FakeFirebaseAuth();
    addTearDown(fakeAuth.dispose);

    await pumpAuthGate(tester, fakeAuth: fakeAuth);
    fakeAuth.emit(null);
    await tester.pump();

    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.byType(AppRoot), findsNothing);
  });

  testWidgets('植物登録画面から確認後ログアウトしてログイン画面へ戻れる', (tester) async {
    final fakeAuth = FakeFirebaseAuth();
    addTearDown(fakeAuth.dispose);

    await pumpAuthGate(
      tester,
      fakeAuth: fakeAuth,
      needsPlantRegistration: true,
    );
    fakeAuth.emit(FakeUser());
    await tester.pumpAndSettle();

    expect(find.text('植物を登録'), findsOneWidget);
    await tester.tap(find.byTooltip('ログアウトしてログイン画面へ戻る'));
    await tester.pumpAndSettle();

    expect(find.text('植物登録を中断しますか？'), findsOneWidget);
    expect(find.textContaining('アカウント作成は完了しています'), findsOneWidget);
    await tester.tap(find.text('中断してログアウト'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.text('おかえりなさい'), findsOneWidget);
  });

  testWidgets('ログイン画面で新規登録へ切り替え、パスワード表示を変更できる', (tester) async {
    final fakeAuth = FakeFirebaseAuth();
    addTearDown(fakeAuth.dispose);

    await pumpAuthGate(tester, fakeAuth: fakeAuth);
    fakeAuth.emit(null);
    await tester.pumpAndSettle();

    expect(find.text('おかえりなさい'), findsOneWidget);
    expect(find.text('ログインする'), findsOneWidget);

    await tester.ensureVisible(find.text('はじめての方はこちら（新規登録）'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('はじめての方はこちら（新規登録）'));
    await tester.pumpAndSettle();
    expect(find.text('はじめまして'), findsOneWidget);
    expect(find.text('アカウントを作成する'), findsOneWidget);

    await tester.ensureVisible(find.text('← ログインに戻る'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('← ログインに戻る'));
    await tester.pumpAndSettle();
    expect(find.text('おかえりなさい'), findsOneWidget);

    await tester.ensureVisible(find.byTooltip('パスワードを表示'));
    await tester.pumpAndSettle();
    final passwordField = tester.widget<TextField>(find.byType(TextField).last);
    expect(passwordField.obscureText, isTrue);
    await tester.tap(find.byTooltip('パスワードを表示'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField).last).obscureText,
      isFalse,
    );
  });

  testWidgets('未登録アカウントのログイン失敗時に新規作成を案内し、戻れる', (tester) async {
    final fakeAuth = FakeFirebaseAuth()
      ..signInError = FirebaseAuthException(code: 'user-not-found');
    addTearDown(fakeAuth.dispose);

    await pumpAuthGate(tester, fakeAuth: fakeAuth);
    fakeAuth.emit(null);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'new@example.com');
    await tester.enterText(find.byType(TextField).last, 'password123');
    await tester.ensureVisible(find.text('ログインする'));
    await tester.tap(find.text('ログインする'));
    await tester.pumpAndSettle();

    expect(find.text('ログインできませんでした'), findsOneWidget);
    expect(find.text('新規作成へ'), findsOneWidget);
    await tester.tap(find.text('新規作成へ'));
    await tester.pumpAndSettle();

    expect(find.text('はじめまして'), findsOneWidget);
    expect(find.text('アカウントを作成する'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      'new@example.com',
    );
    await tester.ensureVisible(find.text('← ログインに戻る'));
    await tester.tap(find.text('← ログインに戻る'));
    await tester.pumpAndSettle();

    expect(find.text('おかえりなさい'), findsOneWidget);
    expect(find.text('ログインする'), findsOneWidget);
  });

  testWidgets('狭い画面幅でもログイン画面がオーバーフローしない', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final width in [220.0, 188.0]) {
      tester.view.physicalSize = Size(width, 600);
      final fakeAuth = FakeFirebaseAuth();
      addTearDown(fakeAuth.dispose);

      await pumpAuthGate(tester, fakeAuth: fakeAuth);
      fakeAuth.emit(null);
      await tester.pumpAndSettle();

      expect(find.byType(LoginPage), findsOneWidget);
      expect(tester.takeException(), isNull, reason: '画面幅: $width');
    }

    addTearDown(tester.view.resetPhysicalSize);
  });

  testWidgets('ログイン時に入力値の形式を検証する', (tester) async {
    final fakeAuth = FakeFirebaseAuth();
    addTearDown(fakeAuth.dispose);

    await pumpAuthGate(tester, fakeAuth: fakeAuth);
    fakeAuth.emit(null);
    await tester.pumpAndSettle();

    await tester.tap(find.text('ログインする'));
    await tester.pumpAndSettle();

    expect(find.text('メールアドレスを正しく入力してください'), findsOneWidget);
    expect(find.text('パスワードは6文字以上で入力してください'), findsOneWidget);
  });

  testWidgets('ログイン済みの場合はAppRootへ切り替わる', (tester) async {
    final fakeAuth = FakeFirebaseAuth();
    addTearDown(fakeAuth.dispose);

    await pumpAuthGate(tester, fakeAuth: fakeAuth);
    fakeAuth.emit(FakeUser());
    await tester.pump();

    expect(find.byType(AppRoot), findsOneWidget);
    expect(find.byType(LoginPage), findsNothing);
  });

  testWidgets('ログイン中にサインアウトするとLoginPageへ切り替わる', (tester) async {
    final fakeAuth = FakeFirebaseAuth();
    addTearDown(fakeAuth.dispose);

    await pumpAuthGate(tester, fakeAuth: fakeAuth);
    fakeAuth.emit(FakeUser());
    await tester.pump();
    expect(find.byType(AppRoot), findsOneWidget);

    // AuthStore.signOut()自体はFirebaseAuth側の内部状態を変えるだけで、
    // 実際の画面切り替えはauthStateChanges()がnullを流すことで起きる
    // (本物のFirebaseAuthも同様の設計)。ここではその発火を直接模擬する。
    fakeAuth.emit(null);
    await tester.pump();

    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.byType(AppRoot), findsNothing);
  });
}
