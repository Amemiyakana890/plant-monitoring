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
    final store = PlantStoreScope.of(context);
    if (store.notifications.isEmpty && !store.isLoadingNotifications) {
      store.loadNotifications();
    }
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

  @override
  Widget build(BuildContext context) {
    final store = PlantStoreScope.of(context);
    final notifications = store.notifications;

    if (store.isLoadingNotifications && notifications.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.medium),
      children: [
        Text('通知', style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: AppSpacing.large),
        if (notifications.isEmpty) const Text('通知はありません'),
        for (final notification in notifications) ...[
          Card(
            child: ListTile(
              leading: Icon(
                _iconFor(notification.message),
                color: notification.isRead ? Colors.grey : AppColors.warning,
              ),
              title: Text(notification.message),
              subtitle: Text(notification.createdAt),
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
