/// 通知/アラート画面(設計書5-6)で使う通知1件分のデータ。
class PlantNotification {
  final int id;
  final int plantId;
  final String message;
  final bool isRead;
  final String createdAt;

  const PlantNotification({
    required this.id,
    required this.plantId,
    required this.message,
    required this.isRead,
    required this.createdAt,
  });

  PlantNotification copyWith({bool? isRead}) {
    return PlantNotification(
      id: id,
      plantId: plantId,
      message: message,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }
}
