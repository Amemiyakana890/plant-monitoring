import 'package:flutter/material.dart';

import '../state/plant_store_scope.dart';
import 'main_page.dart';
import 'onboarding/plant_registration_page.dart';

/// アプリ起動時の最初の振り分け役。
///
/// README記載のユーザーフロー(①起動→②デバイス接続→③植物登録→④ホーム)の
/// うち、③の前後で画面を分けるための入り口。`PlantStore.loadPlant()`の
/// 結果に応じて以下の4状態を出し分ける:
///
/// - 初回のGET /plantsがまだ完了していない → ローディング表示のみ
///   (通信エラーか未登録かがこの時点ではまだ判別できないため)
/// - 通信エラー([PlantStore.errorMessage]) → エラー表示+再試行ボタン
/// - 未登録([PlantStore.needsRegistration]) → [PlantRegistrationPage]
/// - それ以外(植物が取得できた) → [MainPage]
class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    final store = PlantStoreScope.of(context);

    if (store.plant != null) {
      return const MainPage();
    }

    if (store.needsRegistration) {
      return const PlantRegistrationPage();
    }

    if (store.errorMessage != null && !store.isLoadingPlant) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(store.errorMessage!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => store.loadPlant(),
                  child: const Text('再試行'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 上記のどれにも該当しない = 初回読み込み中。
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
