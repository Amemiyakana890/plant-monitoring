import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plant_monitoring_app/main.dart';
import 'package:plant_monitoring_app/repositories/dummy_plant_repository.dart';
import 'package:plant_monitoring_app/state/plant_store.dart';
import 'package:plant_monitoring_app/state/theme_controller.dart';
import 'package:plant_monitoring_app/theme/app_colors.dart';
import 'package:plant_monitoring_app/widgets/plant_card.dart';

/// pumpAndSettle()が何らかの理由で終わらない場合でも、テストを何分も
/// ハングさせず数秒で明確なタイムアウトエラーとして落とすためのラッパー。
/// (デフォルトのpumpAndSettle()は内部タイムアウトが10分と長いため、
/// 環境要因等で終わらないケースに気づくまでが長すぎる)
Future<void> _settle(WidgetTester tester) => tester.pumpAndSettle(
  const Duration(milliseconds: 100),
  EnginePhase.sendSemanticsUpdate,
  const Duration(seconds: 5),
);

/// [PlantStore]の初期読み込み(ダミーの非同期通信を含む)を先に済ませてから
/// アプリを組み立てるためのヘルパー。
/// main.dart本体は読み込み完了を待たずに runApp するが、
/// テストでは結果を決定的にするため先に await している。
Future<void> _pumpApp(WidgetTester tester) async {
  final store = PlantStore(DummyPlantRepository());
  addTearDown(store.dispose);
  final themeController = ThemeController();

  await store.loadInitial();
  await tester.pumpWidget(
    PlantMonitoringApp(store: store, themeController: themeController),
  );
  await _settle(tester);
}

void main() {
  testWidgets(
    'ホームで植物の状態とセンサー値を確認できる',
    (tester) async {
      await _pumpApp(tester);

      expect(find.text('モンステラ'), findsOneWidget);
      expect(find.text('少し乾いています'), findsOneWidget);
      expect(find.text('温度'), findsOneWidget);

      // v1は1株のみの構成のため、SummaryCard(今日のまとめ)とPlantCard
      // (環境データ)に同じ値が重複して表示される。'24.5℃'だけで探すと
      // 画面全体では2件ヒットするため、PlantCard配下に絞って確認する。
      expect(
        find.descendant(of: find.byType(PlantCard), matching: find.text('24.5℃')),
        findsOneWidget,
      );
    },
    // テスト全体としても30秒でタイムアウトさせ、CLIの--timeoutに
    // 依存しなくても暴走を防げるようにする。
    timeout: const Timeout(Duration(seconds: 30)),
  );

  testWidgets(
    'ボトムナビゲーションで主要画面を切り替えられる',
    (tester) async {
      await _pumpApp(tester);

      await tester.tap(find.text('植物'));
      await _settle(tester);
      expect(find.text('植物情報'), findsWidgets);

      await tester.tap(find.text('履歴').last);
      await _settle(tester);
      expect(find.text('🌡 温度'), findsOneWidget);

      await tester.tap(find.text('通知').last);
      await _settle(tester);
      expect(find.text('室温が30℃を超えました'), findsOneWidget);

      await tester.tap(find.text('設定').last);
      await _settle(tester);
      expect(find.text('Plant Monitor 01'), findsOneWidget);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  testWidgets(
    '植物情報画面で植物名・植物種を編集できる',
    (tester) async {
      await _pumpApp(tester);

      await tester.tap(find.text('植物'));
      await _settle(tester);

      await tester.tap(find.text('編集する'));
      await _settle(tester);

      await tester.enterText(find.widgetWithText(TextField, '植物名'), 'パキラ');
      await tester.tap(find.text('保存'));
      // store.updatePlant() はダミーの非同期通信(300ms)を経て反映されるため、
      // _settle でその完了を待つ。
      await _settle(tester);

      expect(find.text('パキラ'), findsOneWidget);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  testWidgets(
    '共通テーマがアプリに適用される',
    (tester) async {
      await _pumpApp(tester);

      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));

      expect(materialApp.theme?.colorScheme.primary, AppColors.primary);
      expect(materialApp.theme?.scaffoldBackgroundColor, AppColors.background);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
