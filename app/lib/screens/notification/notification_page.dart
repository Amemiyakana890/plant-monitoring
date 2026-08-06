import 'package:flutter/material.dart';

import '../../state/plant_store_scope.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';

/// 通知/アラート画面(要件定義書F-05・F-06)。
/// データは[PlantStore]経由で取得し、タップで既読にする
/// (設計書5-6 PATCH /notifications/:id 相当)。
class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  bool _requested = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requested) return;
    _requested = true;

    // history_page.dartと同じ理由(PlantStore.loadNotifications()が
    // notifyListeners()を同期的に呼び出すため)で、
    // 今のフレームの構築が完了した直後まで呼び出しを遅らせる。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final store = PlantStoreScope.of(context);
      if (store.notifications.isEmpty && !store.isLoadingNotifications) {
        store.loadNotifications();
      }
    });
  }

  IconData _iconFor(String message) {
    if (message.contains('水分') || message.contains('湿度')) {
      return Icons.water_drop;
    }
    if (message.contains('温')) {
      return Icons.thermostat;
    }
    return Icons.notifications;
  }

  /// created_at(ISO8601、例: '2026-08-04T23:22:00Z')を
  /// 通知一覧表示用の「8月4日 23:22」形式に整形する。
  /// パースできない場合は元の文字列をそのまま返す(表示が崩れないようにするため)。
  String _formatDateTime(String isoString) {
    final parsed = DateTime.tryParse(isoString);
    if (parsed == null) return isoString;
    final local = parsed.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.month}月${local.day}日 $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final store = PlantStoreScope.of(context);
    final notifications = store.notifications;

    if (store.isLoadingNotifications && notifications.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (store.notificationsErrorMessage != null && notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(store.notificationsErrorMessage!),
            const SizedBox(height: AppSpacing.small),
            OutlinedButton(
              onPressed: () => store.loadNotifications(),
              child: const Text('再読み込み'),
            ),
          ],
        ),
      );
    }

    final unreadCount = notifications.where((n) => !n.isRead).length;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.medium),
      children: [
        Row(
          children: [
            Text('通知', style: Theme.of(context).textTheme.headlineLarge),
            if (unreadCount > 0) ...[
              const SizedBox(width: AppSpacing.small),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$unreadCount件未読',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.large),
        if (store.notificationsErrorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.small),
            child: Text(
              store.notificationsErrorMessage!,
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        if (notifications.isEmpty) const Text('通知はありません'),
        for (final notification in notifications) ...[
          Card(
            child: ListTile(
              leading: Icon(
                _iconFor(notification.message),
                color: notification.isRead ? Colors.grey : AppColors.warning,
              ),
              title: Text(notification.message),
              subtitle: Text(_formatDateTime(notification.createdAt)),
              trailing: notification.isRead
                  ? null
                  : const Icon(Icons.circle, size: 10, color: AppColors.error),
              onTap: notification.isRead
                  ? null
                  : () => store.markNotificationRead(notification.id),
            ),
          ),
          const SizedBox(height: AppSpacing.small),
        ],
      ],
    );
  }
}
