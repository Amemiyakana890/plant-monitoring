import 'package:flutter/widgets.dart';

import 'main_tab_controller.dart';

/// [MainTabController]をウィジェットツリー全体に配布するInheritedWidget。
/// [ThemeControllerScope]と同じ考え方(`InheritedNotifier`のみで実現)。
class MainTabControllerScope extends InheritedNotifier<MainTabController> {
  const MainTabControllerScope({
    super.key,
    required MainTabController controller,
    required super.child,
  }) : super(notifier: controller);

  static MainTabController of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<MainTabControllerScope>();
    assert(
      scope != null,
      'MainTabControllerScope が見つかりません(main.dartの設定を確認してください)',
    );
    return scope!.notifier!;
  }
}
