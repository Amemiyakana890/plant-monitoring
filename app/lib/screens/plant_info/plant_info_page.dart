import 'package:flutter/material.dart';

import '../../models/plant.dart';
import '../../state/plant_store.dart';
import '../../state/plant_store_scope.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';
import '../../widgets/care_tips_card.dart';

/// 登録した植物(1株のみ)の基本情報を確認・編集する画面。
/// v1は1台のデバイス・1株の植物のみを管理する単独構成のため、
/// 一覧・追加・削除の機能は持たない。
class PlantInfoPage extends StatelessWidget {
  const PlantInfoPage({super.key});

  /// 植物育成アドバイス(ケアポイント)の文言。
  ///
  /// TODO: 現状はモンステラ固定の文言を表示しているだけ。
  /// 将来的には植物種マスタ等から植物種ごとの文言を引く形に差し替える
  /// (企画書11章「今後の展望」参照)。
  static const List<String> _monsteraCareTips = [
    '直射日光を避け、明るい日陰を好みます',
    '土の表面が乾いたら水やりをしましょう',
    '適温は18〜30℃、霜に弱いです',
    '月に1度、液体肥料を与えると元気になります',
  ];

  Future<void> _showEditDialog(
    BuildContext context,
    PlantStore store,
    Plant plant,
  ) async {
    final nameController = TextEditingController(text: plant.name);
    final speciesController = TextEditingController(text: plant.species);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('植物情報を編集'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: '植物名'),
            ),
            const SizedBox(height: AppSpacing.small),
            TextField(
              controller: speciesController,
              decoration: const InputDecoration(labelText: '植物種'),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('保存'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
        ],
      ),
    );

    if (result == true) {
      // PATCH /plants/:id 相当。保存後はストアが更新され、
      // このページを含め参照している画面が自動的に再描画される。
      final success = await store.updatePlant(
        name: nameController.text,
        species: speciesController.text,
      );

      if (!success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(store.errorMessage ?? '更新に失敗しました')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = PlantStoreScope.of(context);
    final plant = store.plant;

    if (store.isLoadingPlant && plant == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (plant == null) {
      return Center(child: Text(store.errorMessage ?? '植物の情報がありません'));
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.medium),
      children: [
        Text('植物情報', style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: AppSpacing.large),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.medium),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.1),
                  child: Icon(
                    Icons.local_florist,
                    size: 40,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: AppSpacing.medium),
                ListTile(
                  title: const Text('植物名'),
                  trailing: Text(
                    plant.name,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
                const Divider(),
                ListTile(
                  title: const Text('植物種'),
                  trailing: Text(
                    plant.species,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
                const SizedBox(height: AppSpacing.medium),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.edit),
                    label: const Text('編集する'),
                    onPressed: () => _showEditDialog(context, store, plant),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.medium),
        // 現状は未接続でもほとんど意味を持たない情報のため、
        // 主役の植物カードより控えめなトーン(輪郭のみ・淡色アイコン)にしている。
        // デバイスペアリング機能の実装(要件定義書 F-07)に合わせて、
        // 接続状況・バッテリー残量などを表示する作りに更新する想定。
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.medium),
            side: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
          ),
          child: ListTile(
            leading: Icon(
              Icons.memory,
              color: AppColors.textPrimary.withValues(alpha: 0.4),
            ),
            title: Text(
              '紐づくデバイス',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.textPrimary.withValues(alpha: 0.6),
              ),
            ),
            subtitle: Text(
              'デバイスの接続状況・バッテリー残量は設定画面で確認できます',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textPrimary.withValues(alpha: 0.45),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.medium),
        CareTipsCard(title: '${plant.name}のケアポイント', tips: _monsteraCareTips),
      ],
    );
  }
}
