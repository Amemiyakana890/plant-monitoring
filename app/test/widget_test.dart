import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plant_monitoring_app/main.dart';
import 'package:plant_monitoring_app/theme/app_colors.dart';

void main() {
  testWidgets('ホームから植物詳細を表示できる', (tester) async {
    await tester.pumpWidget(const PlantMonitoringApp());

    expect(find.text('今日のまとめ'), findsOneWidget);
    expect(find.text('マイプランツ'), findsOneWidget);

    await tester.tap(find.text('モンステラ'));
    await tester.pumpAndSettle();

    expect(find.text('現在の状態'), findsOneWidget);
    expect(find.text('24.0 ℃'), findsOneWidget);
    expect(find.text('元気です 🌿'), findsOneWidget);
  });

  testWidgets('ボトムナビゲーションで主要画面を切り替えられる', (tester) async {
    await tester.pumpWidget(const PlantMonitoringApp());

    await tester.tap(find.text('植物'));
    await tester.pumpAndSettle();
    expect(find.text('植物管理'), findsOneWidget);

    await tester.tap(find.text('履歴').last);
    await tester.pumpAndSettle();
    expect(find.text('🌡 温度'), findsOneWidget);

    await tester.tap(find.text('通知').last);
    await tester.pumpAndSettle();
    expect(find.text('温度アラート'), findsOneWidget);

    await tester.tap(find.text('設定').last);
    await tester.pumpAndSettle();
    expect(find.text('通知設定'), findsOneWidget);
  });

  testWidgets('共通テーマがアプリに適用される', (tester) async {
    await tester.pumpWidget(const PlantMonitoringApp());

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));

    expect(materialApp.theme?.colorScheme.primary, AppColors.primary);
    expect(materialApp.theme?.scaffoldBackgroundColor, AppColors.background);
  });
}
