import 'package:flutter/widgets.dart';

import 'plant_store.dart';

/// [PlantStore]をウィジェットツリー全体に配布するためのInheritedWidget。
///
/// provider等のパッケージを追加せず、Flutter標準の`InheritedNotifier`だけで
/// 「状態を共有し、ストアが更新されたら参照している画面だけ再ビルドする」を
/// 実現している。使い方は各画面で `PlantStoreScope.of(context)` と呼ぶだけ。
class PlantStoreScope extends InheritedNotifier<PlantStore> {
  const PlantStoreScope({
    super.key,
    required PlantStore store,
    required super.child,
  }) : super(notifier: store);

  static PlantStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<PlantStoreScope>();
    assert(scope != null, 'PlantStoreScope が見つかりません(main.dartの設定を確認してください)');
    return scope!.notifier!;
  }
}
