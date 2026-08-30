# Push通知(FCM)設計

> Android先行で進める方針(2026年8月時点)。iOSは別途Apple Developer Program登録・
> APNs証明書の設定が必要なため、本書はいったんAndroidのみを対象に設計する。
> 主要な論点(5〜7章)は2026年8月時点で決定済み・**実装済み**(9章参照)。

## 1. 全体方針

- **既存の通知生成ロジックはそのまま**(`status-notification-design.md`参照)。Push通知は
  「アプリ内の通知一覧に追加する」という既存の配信ルートに、「端末へPush送信する」という
  配信ルートを1つ追加するだけ、という位置付けにする。
- サイレントタイム(6-4章)・カテゴリ別ON/OFF(F-09)・1件集約(6-3章)といった既存ロジックは
  一切変更しない。これらはすべて`server/controllers/sensorController.js`の通知生成箇所
  (2章参照)が実行されるタイミングで既に反映済みのため、その直後にPush送信を差し込めば、
  既存ロジックをそのまま踏襲できる。
- v2の複数ユーザー対応(`v2-firebase-security-design.md`)を見据え、FCMトークンは
  「アプリ全体で1件」ではなく**Firebase uidに紐づけて**保存する(3章参照)。

## 2. 通知生成箇所(実装済み)

`server/controllers/sensorController.js`には、通知を生成する箇所が現在2箇所ある。

| 箇所 | 内容 |
|---|---|
| リアルタイム系の悪化検知時(`receiveSensorData`内) | 温度・土壌水分が悪化方向に遷移した瞬間、または湿度・照度の日次評価が要ケアだった場合(6-1・6-5章) |
| サイレントタイム解禁時(`runSilentTimeUnlockCheck`内) | 夜間に悪化があった場合、解禁後最初のセンサー受信時にその時点の状態から1件通知する(6-4章) |

この2箇所は将来また増える可能性があるため、`insertNotificationStmt`をラップする共通関数
`createNotification(plantId, message, category)`を1つ作り、DB保存とPush送信をまとめて
呼び出す形にした。呼び出し側(2箇所)は`insertNotificationStmt.run(...)`を直接呼ばず、必ず
`createNotification(...)`経由にしているため、今後3箇所目が増えてもPush送信を書き忘れる
心配がない。

## 3. データモデル(実装済み)

```sql
CREATE TABLE IF NOT EXISTS device_tokens (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  owner_uid TEXT NOT NULL,
  fcm_token TEXT NOT NULL UNIQUE,
  platform TEXT NOT NULL DEFAULT 'android',
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
  updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);
```

- `owner_uid`:Firebaseのuid。v1〜v2初期は単一ユーザー運用のため実質1種類の値しか入らないが、
  最初からuidで持たせておくことで、将来複数ユーザー対応(パターンB)になった際に
  「このユーザーの端末にだけ送る」という絞り込みがそのまま使える。
- `fcm_token`に`UNIQUE`制約:同じ端末が再登録(アプリ再インストール等でトークン自体は
  変わらないケースや、二重登録)しても行が増えないようにする。
- 1ユーザー1行ではなく**uid : token = 1 : N**を許容する設計(将来1ユーザーが複数端末を
  持つケースに対応するため)。
- **決定・実装済み(2026年8月)**: 同じ端末で別のユーザーに切り替えてログインした場合、古い
  `owner_uid`のままトークンが残ると誤送信の原因になるため、`PUT /devices/tokens`受信時に
  「既存の`fcm_token`が別のuidで登録されていたら、今回のuidで上書きする」仕様にした(4章)。

## 4. サーバーAPI(実装済み)

### 4-1. トークン登録・更新

**`PUT /devices/tokens`**(要ログイン、`requireAuth`経由。`server/controllers/deviceTokensController.js`)

```json
{ "fcm_token": "xxxxx", "platform": "android" }
```

- `fcm_token`をキーにUPSERT(`INSERT ... ON CONFLICT(fcm_token) DO UPDATE`)。既に別のuidで
  登録されていた場合も、今回リクエストしたuid(=ログイン中のFirebaseトークンから取得)で
  上書きする(3章参照。「今ログインしている人の端末である」という前提に基づく)。
- アプリはログイン成功時・`onTokenRefresh`発火時の両方でこのAPIを呼ぶ(`PushNotificationService`、6章参照)。

### 4-2. トークン削除(ログアウト時、任意・API自体は実装済みだが未接続)

**`DELETE /devices/tokens`**(要ログイン)

```json
{ "fcm_token": "xxxxx" }
```

- サーバー側のAPI自体は実装済み(`deviceTokensController.js`の`deleteDeviceToken`)。
- ログアウト操作(`settings_page.dart`の`_signOut`)と合わせて呼ぶと、ログアウトした端末に
  古い通知が届き続けるのを防げる。**未対応**:アプリ側(`_signOut`)からはまだこのAPIを
  呼んでいない。実装コストは低いが、v1は必須ではないため優先度低めの拡張として残っている。

## 5. FCM送信ロジック(サーバー側・実装済み)

### 5-1. `POST /sensor`のレスポンスとの関係(決定・実装済み)

Push送信は`await`するが、失敗しても`/sensor`のレスポンス(センサーデータの保存が成功したか)には
一切影響させない、という方針で実装した。完全なfire-and-forget(`await`なしで呼びっぱなし)はしない。

```javascript
// sensorController.js の createNotification() 内(実装済み)
async function createNotification(plantId, message, category) {
  insertNotificationStmt.run(plantId, message, category);

  try {
    await sendPushNotification(message);
  } catch (err) {
    console.error('Push通知の送信に失敗しました:', err);
    // ここでは何もthrowしない。/sensorのレスポンスは通常通り返す。
  }
}
```

- **`await`する理由**:このプロジェクトはテストを重視しており(`server/test/`)、完全な
  fire-and-forgetだと「Push送信を試みたかどうか」をテストで確定的に検証しづらくなる
  (非同期処理の完了を待たずにアサーションが走ってしまう競合が起きうるため)。`await`すれば
  テスト側も普通に`await`で完了を待って検証できる。
- **失敗を`/sensor`のレスポンスに影響させない理由**:ESP32から見た`POST /sensor`の役割は
  「センサーデータを保存できたか」であり、「Push通知が届いたか」とは別の関心事のため、
  Push送信の失敗で500エラーを返すようなことはしない(try/catchで隔離する)。
- **レスポンス速度への影響**:FCMへのAPI呼び出し分(数百ms程度)だけ`/sensor`のレスポンスが
  遅くなるが、`SEND_INTERVAL`は当面30秒のまま運用する方針のため実害は小さいと判断する。

### 5-2. 送信ロジック本体(実装済み)

`server/firebase_admin.js`はMessaging用のインスタンスも公開する。

```javascript
// server/firebase_admin.js
import { initializeApp, applicationDefault } from 'firebase-admin/app';

const app = initializeApp({ credential: applicationDefault() });
export default app;
```

`server/utils/pushNotifier.js`(実装済み):

```javascript
import { getMessaging } from 'firebase-admin/messaging';
import db from '../database/db.js';

const selectAllTokensStmt = db.prepare(`SELECT fcm_token FROM device_tokens`);
const deleteTokenStmt = db.prepare(`DELETE FROM device_tokens WHERE fcm_token = ?`);

export async function sendPushNotification(message) {
  const tokens = selectAllTokensStmt.all().map((row) => row.fcm_token);
  if (tokens.length === 0) return;

  const response = await getMessaging().sendEachForMulticast({
    tokens,
    notification: { title: '植物見守り', body: message },
  });

  // 無効化されたトークン(アンインストール・期限切れ等)はDBから削除しておく。
  response.responses.forEach((res, i) => {
    if (
      !res.success &&
      res.error?.code === 'messaging/registration-token-not-registered'
    ) {
      deleteTokenStmt.run(tokens[i]);
    }
  });
}
```

- 送受信タイミングの方針は5-1章の通り(`await`するが失敗を`/sensor`のレスポンスに影響させない)。
- 通知本文はアプリ内通知(`notifications.message`)と同じ文言をそのまま使う(個人情報を含まない
  植物の状態メッセージのため、ロック画面表示等のプライバシー面のリスクは低いと考えている)。

## 6. アプリ側(Flutter・Android・実装済み)

### 6-1. 依存関係

`pubspec.yaml`に`firebase_messaging`・`flutter_local_notifications`を追加済み。

### 6-2. 権限・トークン取得

- Android 13(API 33)以降はランタイム通知権限(`POST_NOTIFICATIONS`)が必要。
  `FirebaseMessaging.instance.requestPermission()`を使う。
- `AndroidManifest.xml`(`app/android/app/src/main/AndroidManifest.xml`)に
  `<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>`を追加済み。
- ログイン成功後(`AuthStore`が`isSignedIn`になったタイミング。`main.dart`の`_onAuthChanged()`)に、
  `PushNotificationService.initialize()`を呼び、トークンを取得して4-1章のAPIへ登録する。
- `FirebaseMessaging.instance.onTokenRefresh`を購読し、トークンが更新されるたびに
  再登録する(端末側で任意のタイミングでトークンが変わりうるため)。
- Web実行(`flutter run -d chrome`)時は初期化自体をスキップする(`kIsWeb`ガード。要件定義書8章の
  対応OSはiOS/Androidのみで、Web実行は開発確認用のため。Service Worker未整備によるエラーも回避する)。

### 6-3. 受信ハンドリング(実装済み)

| 状態 | 挙動 |
|---|---|
| フォアグラウンド(アプリ起動中) | **決定・実装済み:バナー等は出さない**。`FirebaseMessaging.onMessage`受信時に`PlantStore`の通知取得を即時実行し、通知一覧・ホーム画面へ最大30秒待たずに反映するだけにする |
| バックグラウンド | OSが自動でシステム通知として表示(`notification`ペイロードのみ送っているため追加実装は不要) |
| 終了状態からの起動 | `FirebaseMessaging.onMessageOpenedApp` / `getInitialMessage()`で、通知タップ時に通知一覧タブへ遷移させる(`PushNotificationService`の`notificationTabIndex`) |

- **決定理由**:Androidの仕様上、アプリがフォアグラウンド中はOSが自動でバナーを出すことはなく、
  出す/出さないは完全にアプリ側の実装次第。`PlantStore`は既に30秒間隔でplant/notificationsを
  ポーリング(`startPolling()`)しているため、Push受信時に何もしなくても最大30秒以内には
  アプリ内に反映される。それに加えてバナーまで出すと、「アプリを開いている=すでに能動的に
  見ている状態」に対して割り込みが過剰であり、企画書のコンセプト
  (「必要な時だけ、そっと知らせる」)とも合わない。バックグラウンド・終了状態では引き続き
  システムが自動でバナーを出すため、「アプリを見ていない時だけそっと知らせる」という
  一貫した体験になる。
- 注意:バックグラウンド/終了状態からの受信そのもの(`FirebaseMessaging.onBackgroundMessage`)は
  実装していない。現在のサーバー実装は`notification`ペイロードのみを送っており、この場合OSが
  自動でシステム通知を表示するため追加実装は不要(上表参照)。将来dataペイロードを使った独自処理が
  必要になった場合は、トップレベル関数のハンドラを`FirebaseMessaging.onBackgroundMessage()`で
  登録すること(別Isolateで実行される可能性があるため、そのハンドラ内で改めて
  `Firebase.initializeApp()`を呼ぶ必要がある)。

### 6-4. 通知チャンネル(実装済み)

Android 8以降は通知チャンネルの設定が必要(重要度など)。**決定・実装済み:`flutter_local_notifications`を
追加し、`PushNotificationService`内でチャンネル(ID: `plant_monitoring_alerts`)を明示的に作成する**。

## 7. 既存の通知設定画面(F-09)との関係

`notification_settings`テーブルにあるカテゴリ別ON/OFF(土壌水分・温度・湿度・照度)と
サイレントタイムは、**すでに`insertNotificationStmt`の実行有無(=`createNotification`が
呼ばれるかどうか)を左右している**(`sensorController.js`の`settings.soil_alert_enabled`等の
参照箇所)。つまり2章の設計により、Push通知もこれらの設定を自動的に継承する(通知が生成されない
状況ではPushも送られない)。

**決定(2026年8月)**:「Push通知だけを個別にON/OFFしたい」というニーズ(例:アプリ内一覧には
残したいがPushは煩わしい)への対応は、**v1のスコープには含めず、v2で着手する**。実装するとしたら
`notification_settings`に`push_enabled`カラムを追加する拡張になる見込み。**未着手**。

## 8. 実装状況まとめ

1. `device_tokens`テーブル追加・マイグレーション(3章) ✅ 実装済み
2. `PUT /devices/tokens` API(4-1章)+ アプリ側のトークン登録(6-2章) ✅ 実装済み
3. `sensorController.js`の通知生成箇所を`createNotification()`ヘルパー経由に統一(2章) ✅ 実装済み
4. `pushNotifier.js`によるFCM送信(5章) ✅ 実装済み
5. アプリ側の受信ハンドリング(6-3章)・通知チャンネル(6-4章) ✅ 実装済み
6. ログアウト時のトークン削除(4-2章) ⬜ APIは実装済みだがアプリ側からは未接続

## 9. 決定事項・今後の検討事項

`status-notification-design.md` 9章と同じ形式で、決定・実装済みのものと、まだ未解決のものを
分けて整理する。

### 9-1. 決定済み・実装済み(2026年8月)

- **`owner_uid`の上書き方針**:同一端末でユーザーが切り替わった場合、最新のログインuidで
  `device_tokens.owner_uid`を上書きする(3章)。
- **Push送信のレスポンス影響**:`await`はするが、失敗しても`/sensor`のレスポンスには
  影響させない(5-1章)。テストのしやすさと、関心の分離(センサー保存の成否とPush送信の成否は別)
  を優先した。
- **フォアグラウンド受信時の見せ方**:バナー等は出さず、通知一覧の即時再取得のみ行う(6-3章)。
  「必要な時だけ、そっと知らせる」というコンセプトを優先した。
- **通知チャンネル**:`flutter_local_notifications`を追加し、明示的にチャンネルを作成する(6-4章)。
- **Push専用ON/OFFトグル**:v1のスコープには含めず、v2で着手する(7章)。
- **アーキテクチャ(Node.js拡張 vs Firebase Cloud Functions)**:既存のNode.jsサーバーを
  そのまま拡張する方針で決定・実装した。通知要否の判定ロジック(閾値・継続時間・サイレントタイム等)が
  既にSQLite+Node.js側にあり、Cloud Functionsを追加してもこのロジックを再現・連携させる
  必要が出るだけでメリットが薄い。`firebase-admin`パッケージ自体、Cloud Functions専用ではなく
  通常のNode.jsプロセスからも同じように使えるため、デプロイ先を増やさずに済むNode.js拡張の方が
  運用コスト・複雑さの両面で有利と判断した(企画書11章の「Node.js→Firebaseへの変更」という
  当初案は、この判断により「Node.jsサーバーからfirebase-adminを利用する」形に落ち着いている)。

### 9-2. 未解決(v2以降で検討)

- ログアウト時のトークン削除(4-2章)をアプリ側から呼ぶかどうか(APIは実装済み。実装コストは低いが必須ではない)
- Push専用ON/OFFトグルの具体的な実装(7章、v2スコープ)
- iOS対応(APNs証明書・Apple Developer Program登録が前提)
