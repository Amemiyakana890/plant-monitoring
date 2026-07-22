import 'package:flutter/material.dart';

import '../models/plant.dart';
import '../theme/app_colors.dart';

/// 植物の状態(PlantStatus)を、画面表示用のアイコン・色・メッセージに変換する。
/// サーバーの判定ロジック(設計書5-7)は healthy / thirsty / dry の3段階。
class PlantStatusInfo {
  final String message;
  final IconData icon;
  final Color color;

  const PlantStatusInfo({
    required this.message,
    required this.icon,
    required this.color,
  });
}

const Map<PlantStatus, PlantStatusInfo> plantStatusInfo = {
  PlantStatus.healthy: PlantStatusInfo(
    message: '元気です',
    icon: Icons.eco,
    color: AppColors.success,
  ),
  PlantStatus.thirsty: PlantStatusInfo(
    message: '少し乾いています',
    icon: Icons.grass,
    color: AppColors.warning,
  ),
  PlantStatus.dry: PlantStatusInfo(
    message: '乾燥しています',
    icon: Icons.warning_amber_rounded,
    color: AppColors.error,
  ),
};
