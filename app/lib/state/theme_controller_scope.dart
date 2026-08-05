import 'package:flutter/widgets.dart';

import 'theme_controller.dart';

/// [ThemeController]をウィジェットツリー全体に配布するためのInheritedWidget。
/// [PlantStoreScope]と同じ考え方(`InheritedNotifier`のみで実現)。
class ThemeControllerScope extends InheritedNotifier<ThemeController> {
  const ThemeControllerScope({
    super.key,
    required ThemeController controller,
    required super.child,
  }) : super(notifier: controller);

  static ThemeController of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<ThemeControllerScope>();
    assert(
      scope != null,
      'ThemeControllerScope が見つかりません(main.dartの設定を確認してください)',
    );
    return scope!.notifier!;
  }
}
