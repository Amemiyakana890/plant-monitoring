import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plant_monitoring_app/main.dart';
import 'package:plant_monitoring_app/repositories/dummy_plant_repository.dart';
import 'package:plant_monitoring_app/state/plant_store.dart';
import 'package:plant_monitoring_app/theme/app_colors.dart';
import 'package:plant_monitoring_app/widgets/plant_card.dart';

/// [PlantStore]の初期読み込み(ダミーの非同期通信を含む)を先に済ませてから
/// アプリを組み立てるためのヘルパー。
/// main.dart本体は読み込み完了を待たずに runApp するが、
/// テストでは結果を決定的にするため先に await している。
Future<void> _pumpApp(WidgetTester tester) async {
  final store = PlantStore(DummyPlantRepository());
  await store.loadInitial();
  await tester.pumpWidget(PlantMonitoringApp(store: store));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('ホームで植物の状態とセンサー値を確認できる', (tester) async {
    await _pumpApp(tester);

    expect(find.text('モンステラ'), findsOneWidget);
    expect(find.text('少し乾いています'), findsOneWidget);
    expect(find.text('環境データ'), findsOneWidget);

    // v1は1株のみの構成のため、SummaryCard(今日のまとめ)とPlantCard
    // (環境データ)に同じ値が重複して表示される。'24.5℃'だけで探すと
    // 画面全体では2件ヒットするため、PlantCard配下に絞って確認する。
    expect(
      find.descendant(
        of: find.byType(PlantCard),
        matching: find.text('24.5℃'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('ボトムナビゲーションで主要画面を切り替えられる', (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.text('植物'));
    await tester.pumpAndSettle();
    expect(find.text('植物情報'), findsWidgets);

    await tester.tap(find.text('履歴').last);
    await tester.pumpAndSettle();
    expect(find.text('🌡 温度'), findsOneWidget);

    await tester.tap(find.text('通知').last);
    await tester.pumpAndSettle();
    expect(find.text('室温が30℃を超えました'), findsOneWidget);

    await tester.tap(find.text('設定').last);
    await tester.pumpAndSettle();
    expect(find.text('デバイス接続'), findsOneWidget);
  });

  testWidgets('植物情報画面で植物名・植物種を編集できる', (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.text('植物'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('編集する'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, '植物名'), 'パキラ');
    await tester.tap(find.text('保存'));
    // store.updatePlant() はダミーの非同期通信(300ms)を経て反映されるため、
    // pumpAndSettle でその完了を待つ。
    await tester.pumpAndSettle();

    expect(find.text('パキラ'), findsOneWidget);
  });

  testWidgets('共通テーマがアプリに適用される', (tester) async {
    await _pumpApp(tester);

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));

    expect(materialApp.theme?.colorScheme.primary, AppColors.primary);
    expect(materialApp.theme?.scaffoldBackgroundColor, AppColors.background);
  });
}
