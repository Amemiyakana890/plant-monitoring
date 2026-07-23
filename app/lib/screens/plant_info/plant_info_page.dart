import 'package:flutter/material.dart';

import '../../models/plant.dart';
import '../../state/plant_store.dart';
import '../../state/plant_store_scope.dart';
import '../../theme/app_dimensions.dart';

/// 登録した植物(1株のみ)の基本情報を確認・編集する画面。
/// v1は1台のデバイス・1株の植物のみを管理する単独構成のため、
/// 一覧・追加・削除の機能は持たない。
class PlantInfoPage extends StatelessWidget {
  const PlantInfoPage({super.key});

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
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (result == true) {
      // PATCH /plants/:id 相当。保存後はストアが更新され、
      // このページを含め参照している画面が自動的に再描画される。
      await store.updatePlant(
        name: nameController.text,
        species: speciesController.text,
      );
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
        const Card(
          child: ListTile(
            leading: Icon(Icons.memory),
            title: Text('紐づくデバイス'),
            subtitle: Text('デバイスの接続状況・バッテリー残量は設定画面で確認できます'),
          ),
        ),
      ],
    );
  }
}
