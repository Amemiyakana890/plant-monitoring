import 'package:flutter/material.dart';

import '../models/plant.dart';
import '../theme/app_dimensions.dart';
import '../utils/plant_status.dart';

/// 「静かに見守る」コンセプトに沿って、状態(アイコン+短いメッセージ)を
/// 数値より優先して大きく表示するカード。
class StatusHeroCard extends StatelessWidget {
  final Plant plant;

  const StatusHeroCard({super.key, required this.plant});

  @override
  Widget build(BuildContext context) {
    final info = plantStatusInfo[plant.status]!;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 204,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _PlantHeroPhoto(speciesKey: plant.speciesKey),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x330D1B10), Color(0xC9001007)],
                    ),
                  ),
                ),
                Positioned(
                  top: AppSpacing.medium,
                  left: AppSpacing.medium,
                  right: AppSpacing.medium,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${plant.careProfile.seasonLabel}のケア',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Flexible(
                        child: Text(
                          '更新 ${plant.updatedAtDisplay}',
                          textAlign: TextAlign.end,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: AppSpacing.large,
                  right: AppSpacing.large,
                  bottom: AppSpacing.large,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (plant.speciesInfo.name != plant.name) ...[
                        Text(
                          plant.speciesInfo.name,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                      ],
                      Text(
                        plant.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.extraSmall),
                      Row(
                        children: [
                          Icon(info.icon, size: 18, color: info.color),
                          const SizedBox(width: AppSpacing.extraSmall),
                          Flexible(
                            child: Text(
                              info.message,
                              style: TextStyle(
                                color: info.color,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.medium,
              AppSpacing.medium,
              AppSpacing.medium,
              AppSpacing.medium,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final note = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plant.soilMoisture <= plant.careProfile.soilNeedsCareMax
                          ? '水やりを確認してください'
                          : '今日も元気に育っています',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '土壌水分を${plant.soilMoisture}%で記録しています',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF64755E),
                      ),
                    ),
                  ],
                );
                final moistureBadge = Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7EDEE),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        '土壌水分',
                        style: TextStyle(
                          color: Color(0xFF9A5A55),
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        '${plant.soilMoisture}%',
                        style: const TextStyle(
                          color: Color(0xFF9E4444),
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                );

                if (constraints.maxWidth < 340) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.water_drop_outlined,
                            color: Color(0xFF638253),
                          ),
                          const SizedBox(width: AppSpacing.small),
                          Expanded(child: note),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.small),
                      Align(
                        alignment: Alignment.centerRight,
                        child: moistureBadge,
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    const Icon(
                      Icons.water_drop_outlined,
                      color: Color(0xFF638253),
                    ),
                    const SizedBox(width: AppSpacing.small),
                    Expanded(child: note),
                    const SizedBox(width: AppSpacing.small),
                    moistureBadge,
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PlantHeroPhoto extends StatelessWidget {
  const _PlantHeroPhoto({required this.speciesKey});

  final String? speciesKey;

  @override
  Widget build(BuildContext context) {
    const photoSpeciesKeys = {'monstera', 'pachira', 'sansevieria', 'pothos'};
    final hasPhoto = photoSpeciesKeys.contains(speciesKey);

    if (!hasPhoto) {
      return _fallback(context);
    }

    return Image.asset(
      'images/plant_photos/$speciesKey.jpg',
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => _fallback(context),
    );
  }

  Widget _fallback(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primary,
            const Color(0xFF829D69),
          ],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.local_florist_rounded,
          size: 76,
          color: Colors.white70,
        ),
      ),
    );
  }
}
