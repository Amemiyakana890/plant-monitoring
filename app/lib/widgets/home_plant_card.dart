import 'package:flutter/material.dart';

import '../models/plant.dart';
import '../utils/plant_status.dart';

/// 植物一覧([PlantsPage]など、複数植物対応時の画面)で使う、
/// 1件分の植物をコンパクトに表示するカード。
///
/// アイコン・色・メッセージは[StatusHeroCard]と同じ[plantStatusInfo]から
/// 取得しており、画面をまたいでも状態の表現を統一している。
class HomePlantCard extends StatelessWidget {
  final Plant plant;
  final VoidCallback? onTap;

  const HomePlantCard({super.key, required this.plant, this.onTap});

  @override
  Widget build(BuildContext context) {
    final info = plantStatusInfo[plant.status]!;

    return Card(
      child: ListTile(
        onTap: onTap,
        leading: Icon(info.icon, color: info.color),
        title: Text(plant.name),
        subtitle: Text(info.message),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
