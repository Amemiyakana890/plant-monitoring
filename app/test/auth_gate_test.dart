import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
  }) async {
    final authStore = AuthStore(firebaseAuth: fakeAuth);
    addTearDown(authStore.dispose);
    final plantStore = PlantStore(DummyPlantRepository());
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
