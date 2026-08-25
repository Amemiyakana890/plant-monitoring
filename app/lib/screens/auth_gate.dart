import 'package:flutter/material.dart';

import '../state/auth_store_scope.dart';
import 'app_root.dart';
import 'auth/login_page.dart';

/// ログイン状態による最初の振り分け役。[AppRoot]よりさらに外側に置く。
///
/// [AppRoot]が「植物が登録済みか」を見て振り分けるのと同じ考え方で、
/// こちらは「ログイン済みか」を見て振り分ける。
///
/// - FirebaseAuthからの最初の状態通知がまだ来ていない
///   ([AuthStore.hasResolvedInitialState]がfalse) → ローディング表示のみ
/// - 未ログイン → [LoginPage]
/// - ログイン済み → [AppRoot](=植物登録状態の判定へ進む)
///
/// v2のログインは「本人確認のゲート」としての導入(パターンA)であり、
/// ユーザーごとにデータを分離する仕組みではないため、[AppRoot]以下・
/// [PlantStore]・サーバー側のAPIは一切変更していない。
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authStore = AuthStoreScope.of(context);

    if (!authStore.hasResolvedInitialState) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!authStore.isSignedIn) {
      return const LoginPage();
    }

    return const AppRoot();
  }
}
