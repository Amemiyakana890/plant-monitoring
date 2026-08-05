import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';

/// 植物の育成アドバイス(ケアポイント)を表示するカード。
///
/// v1では植物種ごとの出し分けは行わず、呼び出し側が渡した文言を
/// そのまま表示するだけの単純な作りにしている
/// (現状は植物情報画面からモンステラ固定の文言を渡している)。
/// 将来的には植物種マスタや外部データソースから動的に
/// 取得する形へ差し替える想定(企画書11章「今後の展望」参照)。
class CareTipsCard extends StatelessWidget {
  final String title;
  final List<String> tips;

  const CareTipsCard({super.key, required this.title, required this.tips});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppColors.secondary.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.medium),
        side: BorderSide(color: AppColors.secondary.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.medium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.eco, size: 20, color: AppColors.primary),
                const SizedBox(width: AppSpacing.extraSmall),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.small),
            for (final tip in tips)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.extraSmall),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 7, right: 8),
                      child: CircleAvatar(
                        radius: 3,
                        backgroundColor: AppColors.primary,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        tip,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
