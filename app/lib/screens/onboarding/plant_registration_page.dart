import 'package:flutter/material.dart';

import '../../state/plant_store.dart';
import '../../state/plant_store_scope.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';

/// 植物の新規登録画面(F-08)。
///
/// [AppRoot](../app_root.dart)が「植物が0件(未登録)」を検知した際に
/// ここへ振り分ける。
///
/// 植物種(speciesKey)はラジオボタンでの選択を必須にしている
/// (通知条件・閾値が植物種ごとに異なるため、未選択のまま登録できて
/// しまうとモンステラの閾値に暗黙でフォールバックしてしまい、
/// ユーザーの意図と異なる通知が飛びかねないという判断。
/// PlantRepository.createPlant()のドキュメントコメントも参照)。
///
/// 登録に成功すると`PlantStore.plant`が更新され、[AppRoot]が自動的に
/// [MainPage](../main_page.dart)へ切り替えるため、この画面自体は
/// Navigator操作を行わない。
class PlantRegistrationPage extends StatefulWidget {
  const PlantRegistrationPage({super.key});

  @override
  State<PlantRegistrationPage> createState() => _PlantRegistrationPageState();
}

class _PlantRegistrationPageState extends State<PlantRegistrationPage> {
  final _nameController = TextEditingController();
  String? _selectedSpeciesKey;

  // 送信を一度試みるまでは「植物種未選択」の警告文を出さない
  // (開いた瞬間からエラー表示が出ているのは体験として不親切なため)。
  bool _triedSubmit = false;

  @override
  void initState() {
    super.initState();
    // plant_info_page.dart の _showSpeciesPicker と同じく、画面表示時に
    // カタログが未取得ならここで読み込む。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final store = PlantStoreScope.of(context);
      if (store.speciesCatalog.isEmpty) {
        store.loadSpeciesCatalog();
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get _isNameValid => _nameController.text.trim().isNotEmpty;

  Future<void> _submit(PlantStore store) async {
    setState(() => _triedSubmit = true);

    if (!_isNameValid || _selectedSpeciesKey == null) {
      return;
    }

    final success = await store.registerPlant(
      name: _nameController.text.trim(),
      speciesKey: _selectedSpeciesKey!,
    );

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(store.registrationErrorMessage ?? '植物を登録できませんでした'),
        ),
      );
    }
    // 成功時は何もしない。plant が更新されると AppRoot が自動的に
    // MainPage へ切り替える。
  }

  @override
  Widget build(BuildContext context) {
    final store = PlantStoreScope.of(context);
    final showNameError = _triedSubmit && !_isNameValid;
    final showSpeciesError = _triedSubmit && _selectedSpeciesKey == null;

    return Scaffold(
      appBar: AppBar(title: const Text('植物を登録')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.medium),
          children: [
            Text(
              'はじめまして。育てる植物について教えてください。',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.small),
            Text(
              '登録した内容は、あとから「植物情報」画面で変更できます。',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: AppSpacing.large),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: '植物名(ニックネーム)',
                hintText: '例: モンステラ',
                errorText: showNameError ? '植物名を入力してください' : null,
              ),
              onChanged: (_) {
                // 入力し始めたらエラー表示を即座に消したいので再描画する。
                if (_triedSubmit) setState(() {});
              },
            ),
            const SizedBox(height: AppSpacing.large),
            Text('植物種', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.small),
            _SpeciesSelector(
              store: store,
              selectedKey: _selectedSpeciesKey,
              onChanged: (key) => setState(() => _selectedSpeciesKey = key),
            ),
            if (showSpeciesError)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.small),
                child: Text(
                  '植物種を選択してください',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.large),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: store.isRegisteringPlant
                    ? null
                    : () => _submit(store),
                child: store.isRegisteringPlant
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('この内容で登録する'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 植物種の選択肢一覧(ラジオボタン)。
/// 読み込み中/取得失敗/一覧表示の3状態を持つ
/// (plant_info_page.dart の _showSpeciesPicker と同じデータソースを使うが、
/// あちらはボトムシート、こちらは常時表示のラジオボタンという違いがある)。
class _SpeciesSelector extends StatelessWidget {
  final PlantStore store;
  final String? selectedKey;
  final ValueChanged<String?> onChanged;

  const _SpeciesSelector({
    required this.store,
    required this.selectedKey,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (store.isLoadingSpeciesCatalog && store.speciesCatalog.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.medium),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (store.speciesCatalog.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.small),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              store.speciesCatalogErrorMessage ?? '植物の選択肢を取得できませんでした',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: AppSpacing.small),
            OutlinedButton(
              onPressed: () => store.loadSpeciesCatalog(),
              child: const Text('再読み込み'),
            ),
          ],
        ),
      );
    }

    return RadioGroup<String>(
      groupValue: selectedKey,
      onChanged: onChanged,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (final species in store.speciesCatalog)
              RadioListTile<String>(
                value: species.key,
                activeColor: AppColors.primary,
                title: Text(species.name),
                subtitle: Text(species.scientificName),
              ),
          ],
        ),
      ),
    );
  }
}
