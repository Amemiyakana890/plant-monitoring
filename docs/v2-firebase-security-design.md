# v2 セキュリティ・Firebase設計

> Firebase Authを使ったサーバーAPI認証と、Firebase UIDによるユーザーデータ分離の設計・実装を記録する。
> 植物・デバイス・通知設定・通知・センサー履歴をUIDで分離し、ESP32はデバイスごとの個別キーで認証する。
>
> 既存DBの植物・デバイスは、移行時に`.env`の`LEGACY_DATA_OWNER_UID`で指定したFirebase UIDへ一度だけ割り当てる。
> 所有者の設定がない既存データがある場合、UIDを指定しないサーバー起動は失敗する。新しいユーザーには既存データを共有せず、
> 植物もデバイスもない状態で開始する。デバイスの認証キーは登録時に生成され、DBにはハッシュのみ保存する。

## 1. 前提の整理(現状把握)

### 1-1. 実装済みの部分(v2・ログイン)

- Firebase Authentication(メール/パスワード)によるログイン・新規登録画面
- `AuthGate` が起動時にログイン状態を見て `LoginPage` / `AppRoot` を振り分け
- Firebase UIDの変更時、Flutter側はユーザーデータを消去してから新しいUIDのデータを読み込み、
  古いセッションから遅れて返ったレスポンスは破棄する。
- 植物・デバイス・通知設定には所有者UIDを持たせ、関連する履歴・通知の問い合わせも植物の所有者で絞り込む。

### 1-2. 残っている課題

1. **Firebase UIDによる所有者制御**:当初のIDトークン検証だけではユーザー間のデータ分離ができなかった。
   → 3章と5章の方式で対応済み。
2. ~~新規登録が誰でもできる~~:`LoginPage` に「アカウントを作成する」ボタンがある点は、当初は
   単一ユーザー前提と矛盾する課題として扱っていたが、複数ユーザー対応(パターンB)へ方針転換した
   ため、現時点では対応不要(冒頭の方針転換・5章を参照)。

認証と所有者制御の実装、および旧データの移行方針を以下に記録する。

## 2. 全体方針

- **ユーザーごとのデータ分離を実装する**。各ユーザーは自分の植物・デバイス・履歴・通知・設定だけを参照・変更できる。
  新規アカウントにはデータを共有しない。
- ESP32(センサーデバイス)はFirebaseのユーザーではないため、`POST /sensor`はデバイス個別キーで認証し、
  デバイス所有者の植物・設定だけを更新する(4章で詳述)。

## 3. サーバー側トークン検証の設計

### 3-1. 対象エンドポイント

| エンドポイント | 検証 | 理由 |
|---|---|---|
| `GET/POST/PATCH/DELETE /plants` | 必須 | アプリからの操作 |
| `GET/POST/DELETE /devices` | 必須 | アプリからの操作 |
| `GET /history/:plantId` | 必須 | アプリからの操作 |
| `GET/PATCH /notifications` | 必須 | アプリからの操作 |
| `GET/PUT /settings/notification` | 必須 | アプリからの操作 |
| `GET /species` | 必須 | アプリからの操作 |
| `POST /sensor` | **別方式**(4章) | ESP32はFirebaseユーザーではない |

### 3-2. 検証方式(`firebase-admin`)【実装済み】

- サーバー側に `firebase-admin` を追加し、`.env` の `GOOGLE_APPLICATION_CREDENTIALS`(Firebase Admin SDK
  サービスアカウント鍵のパス)で初期化する(`server/firebase_admin.js`)。
- Expressのミドルウェア `requireAuth`(`server/middleware/require_auth.js`)として実装し、
  `POST /sensor` を除く全エンドポイントに一括適用している。

```javascript
// server/middleware/require_auth.js (実装済み)
import { getAuth } from 'firebase-admin/auth';
import { sendError } from '../utils/errors.js';

export async function requireAuth(req, res, next) {
  const authorization = req.headers.authorization ?? '';
  const [scheme, token] = authorization.split(' ');

  if (scheme !== 'Bearer' || !token) {
    return sendError(res, 401, 'UNAUTHENTICATED', 'ログインが必要です');
  }

  try {
    req.user = await getAuth().verifyIdToken(token);
    return next();
  } catch (error) {
    console.warn('Firebase IDトークンの検証に失敗しました:', error.message);
    return sendError(res, 401, 'UNAUTHENTICATED', '認証トークンが無効です');
  }
}
```

- `app.js` 側の適用(実際のコード。`/sensor`だけを`requireDeviceAuth`側に切り出し、それ以外の`/api`配下
  全体に`requireAuth`を一括適用する形にしている。当初案のようにルーターごとに個別適用してはいない):

```javascript
app.use('/api/sensor', requireDeviceAuth);
app.use('/api', (req, res, next) => {
  if (req.path === '/sensor' || req.path.startsWith('/sensor/')) {
    return next();
  }
  return requireAuth(req, res, next);
});
```

- エラーレスポンスは既存の形式(`system-design.md` 5-8章、`server/utils/errors.js` の `sendError`)
  に合わせつつ、当初案の`UNAUTHORIZED`ではなく **`UNAUTHENTICATED`** というコードで実装した
  (「権限がない」ではなく「ログインしていない/トークンが無効」を表す方が実態に合うため)。

### 3-3. アプリ側の対応(Flutter)【実装済み】

- `HttpPlantRepository` が各リクエスト時に `Authorization: Bearer <idToken>` ヘッダーを付与する(実装済み)。
- IDトークンは `FirebaseAuth.instance.currentUser?.getIdToken()` で取得している(有効期限は1時間、
  SDKが自動でリフレッシュするため、リクエストの都度取得し直せば期限切れは基本的に気にしなくてよい)。
- `main.dart` は `AuthStore` のログイン状態を監視し、ログイン成功後(`isSignedIn`かつ未取得の場合)に
  初めて `PlantStore.loadInitial()` / `startPolling()` を呼ぶよう変更済み(未ログイン中に叩いて401が
  返り続けることはない)。

## 4. ESP32(`POST /sensor`)の扱い【デバイス個別キーで実装済み】

ESP32はFirebase Authのユーザーとしてログインする主体ではないため、センサー送信時はデバイスIDと
個別キーで認証する。`devices`にはキーそのものではなくSHA-256ハッシュを保存し、
`requireDeviceAuth`が該当デバイスのキーを検証する。検証後の`deviceOwnerUid`を使い、
所有者のデバイス・植物・通知設定に限定してセンサーデータと通知を処理する。

- 新規デバイスのキーは`POST /devices/pair`で暗号学的乱数から発行し、ペアリング応答で一度だけ返す。
- アプリのデバイス接続画面で表示されたキーとデバイスIDをESP32の`secrets.h`およびスケッチへ設定する。
- 旧デバイスについては、移行時に`.env`の`DEVICE_API_KEY`を使ってデバイス個別キーのハッシュを初期登録する。
  `LEGACY_DATA_OWNER_UID`および`LEGACY_DEVICE_ID`も旧データ移行時のみに使用する。
- キーを失った場合、同じキーを再表示する仕組みはない。デバイスの再登録・キー再発行の運用は別途必要。

## 5. 新規登録を閉じる方式(撤回・現在は対応不要)

> **2026年8月・方針転換により本章の対応は行わないことにした。** 以下は単一ユーザー前提(パターンA)
> だった当時の検討記録として残す。

単一ユーザー前提のアプリでは、誰でもアカウントを作成できる状態は「本人確認のゲート」の目的と
矛盾するため、当初は以下のいずれかで塞ぐ方針だった。

| 案 | 内容 | コスト |
|---|---|---|
| A. UIから登録ボタンを削除 | `LoginPage` の「アカウントを作成する」導線を外し、最初の1アカウントは
Firebase Console側で手動作成する | 最小 |
| B. 招待コード方式 | 事前に決めたコードを知っている場合のみ登録できるようにする | 中 |
| C. Firebase側で新規登録をブロック | Firebase ConsoleのAuthentication設定、または
Cloud Functionsの `beforeCreate` フックで登録自体を拒否する | 中〜大 |

v2で複数ユーザー対応(パターンB)へ方針転換したため、新規登録ボタンは**意図的に開放したまま**とする。
複数ユーザーがそれぞれアカウントを作成し、自分で登録したデバイスだけを扱えるようにするため、
登録自体を塞ぐ必要はなくなった。現状のデバイス紐付けはBLEではなく、名前とMACアドレスの手入力。

ユーザー(uid)と`plants`/`devices`の紐付け、および他ユーザーのデータに対する拒否は実装済み。
BLEによる検出・ペアリングは未着手で、現在はデバイス名とMACアドレスを手入力する。

## 6. 実装の優先順位(参考)

1. サーバー側トークン検証ミドルウェアの追加(3章)+ アプリ側の `Authorization` ヘッダー付与 ✅ 実装済み
2. `PlantStore` の初期化タイミングをログイン後に変更(3-3章) ✅ 実装済み
3. ESP32側の保護(4章・案A) ✅ 実装済み
4. ~~新規登録ボタンの削除(5章・案A)~~ → 方針転換により対応不要(5章参照)
5. ユーザーとデバイス/植物の紐付け・所有者チェック ✅ 実装済み
6. BLEペアリングフロー ⬜ 未着手(現在は手入力)

Push通知(FCM)は植物所有者のトークンに限定して送信する(詳細は[push-notification-design.md](push-notification-design.md)を参照)。

## 7. 残課題・今後の検討事項

- **既存DBの移行**:旧データを引き継ぐアカウントを`LEGACY_DATA_OWNER_UID`へ設定し、DBバックアップ後に
  サーバーを起動して一度だけ所有者移行する。UIDが未設定の場合、既存の未所有データがあるDBは起動時に失敗する。
- アカウント削除時の関連データ一括削除・デバイスキー再発行のUIは未実装。
- BLEペアリングは未着手。現在はデバイス名・MACアドレスを手入力する。
- ESP32の送信間隔や`species_thresholds`のテーブル化は、関連設計書で管理する。
