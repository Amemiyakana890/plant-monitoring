import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plant_monitoring_app/main.dart';
import 'package:plant_monitoring_app/theme/app_colors.dart';

void main() {
  testWidgets('ホームで植物の状態とセンサー値を確認できる', (tester) async {
    await tester.pumpWidget(const PlantMonitoringApp());

    expect(find.text('モンステラ'), findsOneWidget);
    expect(find.text('少し乾いています'), findsOneWidget);
    expect(find.text('環境データ'), findsOneWidget);
    expect(find.text('24.5℃'), findsOneWidget);
  });

  testWidgets('ボトムナビゲーションで主要画面を切り替えられる', (tester) async {
    await tester.pumpWidget(const PlantMonitoringApp());

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
    await tester.pumpWidget(const PlantMonitoringApp());

    await tester.tap(find.text('植物'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('編集する'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, '植物名'), 'パキラ');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('パキラ'), findsOneWidget);
  });

  testWidgets('共通テーマがアプリに適用される', (tester) async {
    await tester.pumpWidget(const PlantMonitoringApp());

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));

    expect(materialApp.theme?.colorScheme.primary, AppColors.primary);
    expect(materialApp.theme?.scaffoldBackgroundColor, AppColors.background);
  });
}
