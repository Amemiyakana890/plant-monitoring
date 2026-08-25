import 'package:flutter/widgets.dart';

import 'auth_store.dart';

/// [AuthStore]をウィジェットツリー全体に配布するためのInheritedWidget。
/// [PlantStoreScope](plant_store_scope.dart)と全く同じパターン。
class AuthStoreScope extends InheritedNotifier<AuthStore> {
  const AuthStoreScope({
    super.key,
    required AuthStore store,
    required super.child,
  }) : super(notifier: store);

  static AuthStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AuthStoreScope>();
    assert(scope != null, 'AuthStoreScope が見つかりません(main.dartの設定を確認してください)');
    return scope!.notifier!;
  }
}
