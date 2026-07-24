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

  /// GET /notifications のレスポンス(設計書5-6)から変換する。
  /// is_read はSQLite上0/1のINTEGERで保存される(設計書6章)ため、
  /// bool以外(0/1や数値)で届いた場合にも対応できるようにしている。
  factory PlantNotification.fromJson(Map<String, dynamic> json) {
    final rawIsRead = json['is_read'];
    return PlantNotification(
      id: json['id'] as int,
      plantId: json['plant_id'] as int,
      message: json['message'] as String,
      isRead: rawIsRead == true || rawIsRead == 1,
      createdAt: json['created_at'] as String? ?? '',
    );
  }

  /// PATCH /notifications/:id 向け(設計書5-6)。
  Map<String, dynamic> toReadJson() => {'is_read': true};
}
