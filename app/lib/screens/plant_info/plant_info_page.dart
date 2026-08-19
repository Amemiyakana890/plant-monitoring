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
///
/// 植物種の選択(F-08・植物切り替え機能)に伴い、以前は「植物名」「植物種」を
/// どちらも自由入力するダイアログだったが、植物種は「植物を選択する」ボタンから
/// カタログ(GET /species)を選ぶ形に変更した。植物名(ニックネーム)は
/// これまで通り自由入力のまま、植物種の選択とは独立して編集できる。
class PlantInfoPage extends StatelessWidget {
  const PlantInfoPage({super.key});

  /// 植物育成アドバイス(ケアポイント)の文言。
  ///
  /// TODO: 現状はモンステラ固定の文言を表示しているだけ。
  /// 将来的には植物種カタログ(server/utils/speciesCatalog.js)側に
  /// ケアポイントの文言も持たせ、植物種ごとに出し分ける形に差し替える
  /// (企画書11章「今後の展望」参照)。
  static const List<String> _monsteraCareTips = [
    '直射日光を避け、明るい日陰を好みます',
    '土の表面が乾いたら水やりをしましょう',
    '適温は18〜30℃、霜に弱いです',
    '月に1度、液体肥料を与えると元気になります',
  ];

  /// 植物名(ニックネーム)だけを編集するダイアログ。
  Future<void> _showEditNameDialog(
    BuildContext context,
    PlantStore store,
    Plant plant,
  ) async {
    final nameController = TextEditingController(text: plant.name);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('植物名を編集'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: '植物名(ニックネーム)'),
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
      final success = await store.updatePlant(name: nameController.text);

      if (!success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(store.errorMessage ?? '更新に失敗しました')),
        );
      }
    }
  }

  /// 「植物を選択する」ボタンから開く、植物種カタログの選択シート。
  /// 選択すると、植物種テキスト(表示用)もサーバー側で自動的に更新される
  /// (server/controllers/plantsController.js updatePlant参照)。
  Future<void> _showSpeciesPicker(
    BuildContext context,
    PlantStore store,
    Plant plant,
  ) async {
    if (store.speciesCatalog.isEmpty) {
      await store.loadSpeciesCatalog();
    }
    if (!context.mounted) return;
    if (store.speciesCatalog.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            store.speciesCatalogErrorMessage ?? '植物の選択肢を取得できませんでした',
          ),
        ),
      );
      return;
    }

    final selectedKey = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.medium),
                child: Text(
                  '植物を選択する',
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
              ),
              for (final species in store.speciesCatalog)
                ListTile(
                  leading: const Icon(Icons.local_florist),
                  title: Text(species.name),
                  subtitle: Text(species.scientificName),
                  trailing: plant.speciesKey == species.key
                      ? Icon(
                          Icons.check,
                          color: Theme.of(sheetContext).colorScheme.primary,
                        )
                      : null,
                  onTap: () => Navigator.of(sheetContext).pop(species.key),
                ),
              const SizedBox(height: AppSpacing.small),
            ],
          ),
        );
      },
    );

    if (selectedKey != null && context.mounted) {
      final success = await store.selectSpecies(selectedKey);
      if (!success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(store.errorMessage ?? '植物種を変更できませんでした')),
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
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _PlantPhotoHeader(speciesKey: plant.speciesKey),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.medium),
                child: Column(
                  children: [
                    _InfoRow(label: '植物名', value: plant.name),
                    const Divider(),
                    _InfoRow(
                      label: '植物種',
                      value: plant.speciesInfo.scientificName,
                    ),
                    const SizedBox(height: AppSpacing.medium),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.edit),
                        label: const Text('植物名を編集する'),
                        onPressed: () =>
                            _showEditNameDialog(context, store, plant),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.small),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon:
                            (store.isLoadingSpeciesCatalog ||
                                store.isSelectingSpecies)
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.swap_horiz),
                        label: const Text('植物を選択する'),
                        onPressed:
                            (store.isLoadingSpeciesCatalog ||
                                store.isSelectingSpecies)
                            ? null
                            : () => _showSpeciesPicker(context, store, plant),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.medium),
        _CareProfileCard(plant: plant),
        const SizedBox(height: AppSpacing.medium),
        CareTipsCard(title: '${plant.name}のケアポイント', tips: _monsteraCareTips),
      ],
    );
  }
}

/// 「この植物の管理条件」カード(F-08・植物切り替え機能)。
///
/// docs/status-notification-design.md 3-1〜3-4章の閾値を、サーバー側が
/// 今の季節(JST基準、自動判定のみ・手動切り替えは無し)に当てはめて返す
/// `care_profile`をそのまま表示する。「水やり目安(日数)」は一度検討したが
/// 分かりやすさの観点でしっくりこなかったため、今回は含めていない。
class _CareProfileCard extends StatelessWidget {
  final Plant plant;

  const _CareProfileCard({required this.plant});

  static String _fmt(double value) {
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final profile = plant.careProfile;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.medium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'この植物の管理条件',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 2),
            Text(
              '${plant.speciesInfo.name} / ${profile.seasonLabel}モード',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: AppSpacing.medium),
            _CareConditionTile(
              icon: Icons.eco,
              label: '適正土壌水分',
              subtitle: '${_fmt(profile.soilNeedsCareMax)}%以下でアラート',
              value: '${_fmt(profile.soilHealthyMin)}%以上',
            ),
            const Divider(),
            _CareConditionTile(
              icon: Icons.thermostat,
              label: '適正温度',
              subtitle: '範囲外でアラート',
              value:
                  '${_fmt(profile.temperatureHealthyMin)}〜${_fmt(profile.temperatureHealthyMax)}℃',
            ),
            const Divider(),
            _CareConditionTile(
              icon: Icons.water_drop,
              label: '適正湿度',
              subtitle: '範囲外でアラート(1日の平均で判定)',
              value:
                  '${_fmt(profile.humidityHealthyMin)}〜${_fmt(profile.humidityHealthyMax)}%',
            ),
            const Divider(),
            _CareConditionTile(
              icon: Icons.wb_sunny,
              label: '適正照度',
              subtitle: '未満でアラート(日中の平均で判定)',
              value: '${_fmt(profile.illuminanceHealthyMin)}lux以上',
            ),
          ],
        ),
      ),
    );
  }
}

class _CareConditionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final String value;

  const _CareConditionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: AppSpacing.small),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodyMedium),
                Text(
                  subtitle,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.extraSmall),
          // 万一(フォント読み込みタイミング等で)想定より横幅が必要になっても、
          // RenderFlexのオーバーフローエラーにはならず省略表示に倒れるようにする。
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 植物情報カード上部の「植物名」「植物種」のような、ラベル+値の1行表示。
///
/// 以前は`ListTile(title:, trailing:)`を使っていたが、trailingに長い文字列
/// (例:「サトイモ科モンステラ属」)を渡すと、ListTile独自のレイアウト計算で
/// 「Trailing widget consumes the entire tile width」という例外や
/// RenderFlexオーバーフローが発生する不具合があった。ListTileに頼らず、
/// 自前のRow(ラベル側をExpanded、値側をFlexible+省略表示)に置き換えることで、
/// 値がどれだけ長くてもエラーにならず安全に収まるようにしている。
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyLarge),
          ),
          const SizedBox(width: AppSpacing.small),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }
}

/// 植物情報カード上部の写真ヘッダー。
///
/// `images/plant_photos/<species_key>.jpg`(または`.png`)が存在すればそれを
/// 表示し、無ければグラデーション背景+アイコンのフォールバック表示にする
/// (実機のネットワーク制限で実際の植物写真をこのプロジェクトに同梱できな
/// かったため、写真は利用者が任意で追加できる形にしている。
/// images/plant_photos/README.md参照)。
///
/// NOTE: フォルダ名を`assets/plants/`にしていた時期があったが、Flutter Web
/// は配信時に自動で`assets/`という接頭辞を付けるため、フォルダ名自体が
/// 「assets」から始まっていると`assets/assets/plants/...`のように二重になり
/// 404になる不具合があった。それを避けるため`images/plant_photos/`という
/// 「assets」を含まない名前に変更している。
class _PlantPhotoHeader extends StatelessWidget {
  final String? speciesKey;

  const _PlantPhotoHeader({required this.speciesKey});

  @override
  Widget build(BuildContext context) {
    final assetPath = 'images/plant_photos/${speciesKey ?? 'default'}.jpg';

    return SizedBox(
      height: 160,
      width: double.infinity,
      child: Image.asset(
        assetPath,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _PhotoFallback(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _PhotoFallback extends StatelessWidget {
  final Color color;

  const _PhotoFallback({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: 0.12), color.withValues(alpha: 0.28)],
        ),
      ),
      child: Center(
        child: Icon(Icons.local_florist, size: 56, color: color.withValues(alpha: 0.55)),
      ),
    );
  }
}
