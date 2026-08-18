# 植物写真の配置について

このフォルダに植物種ごとの写真を置くと、植物情報ページのヘッダーに表示されます。

## 配置ルール

- ファイル名は `<species_key>.jpg`(または`.png`)
- 例: モンステラの場合 → `monstera.jpg`
- `species_key`は`server/utils/speciesCatalog.js`のカタログのkeyと一致させること

## 写真が無い場合

このフォルダに該当ファイルが無い場合、`plant_info_page.dart`は自動的に
グラデーション背景+アイコンのフォールバック表示にする(エラーにはならない)。
実機で育てている植物の写真を撮って配置すると、そのまま反映される。

## 注意:フォルダ名を「assets/〜」にしないこと

Flutter Web(および他プラットフォームのビルド)は、アプリ内のアセットを
配信する際に自動で`assets/`という接頭辞を付ける。そのため、pubspec.yamlに
登録するフォルダ名自体を`assets/plants/`のように「assets」から始まる名前に
すると、実際の配信パスが`assets/assets/plants/...`のように二重になり
404エラーになる(実際にこの不具合が発生したため、`images/plant_photos/`
という名前に変更した経緯がある)。今後もこのフォルダ名は変更しないこと。

## 注意

写真を追加した後は `pubspec.yaml` の `assets:` に `images/plant_photos/` が
登録されていることを確認し(登録済み)、`flutter pub get` を実行すること。
