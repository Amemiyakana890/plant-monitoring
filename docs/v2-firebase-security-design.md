# v2 セキュリティ・Firebase設計

> v2で導入したFirebase Auth(ログイン機能)を土台に、「サーバーAPIが無認証のまま」という
> 課題を解消するための設計。**サーバー側のトークン検証(3〜4章)は実装済み**
> (`server/middleware/require_auth.js`・`server/middleware/require_device_auth.js`)。
> パターンB(複数ユーザー対応)本体はまだ未着手で、その部分は引き続きドラフト(5〜7章のTODO参照)。
>
> **方針転換(2026年8月)**: 当初は「本人確認のゲート」としての単一ユーザー運用(パターンA)を
> 前提にしていたが、v2で複数ユーザー対応(パターンB)を見据える方針に変更した。将来的には
> ユーザーごとにBLEでデバイスをペアリング・紐付け、他ユーザーは自分が紐付けていないデバイスを
> 扱えないようにする想定。この変更に伴い、5章で検討していた「新規登録を閉じる」対応は行わない
> (詳細は5章を参照)。ただしユーザーとデバイス/植物を紐付けるデータモデル(パターンB本体)は
> 本書ではまだ設計しておらず、別途検討が必要(7章に追記)。

## 1. 前提の整理(現状把握)

### 1-1. 実装済みの部分(v2・ログイン)

- Firebase Authentication(メール/パスワード)によるログイン・新規登録画面
- `AuthGate` が起動時にログイン状態を見て `LoginPage` / `AppRoot` を振り分け
- **設計意図(実装コードのコメントより)**: 「本人確認のゲート」としての導入(パターンA)であり、
  ユーザーごとにデータを分離する仕組み(パターンB)ではない。そのため `PlantStore`・サーバーAPI・
  DBスキーマには一切手を入れていない。

### 1-2. 残っている課題

1. **サーバーAPIが無認証**:`GET /plants` `POST /sensor` など全エンドポイントが、Firebaseの
   IDトークンを一切検証していない。アプリのログイン画面を経由せず、サーバーのURL・ポートさえ
   分かれば直接APIを叩ける状態(`server/app.js` にトークン検証のミドルウェアが存在しないことを確認済み)。
   → 3章の方式で対応済み(`server/middleware/require_auth.js`)。
2. ~~新規登録が誰でもできる~~:`LoginPage` に「アカウントを作成する」ボタンがある点は、当初は
   単一ユーザー前提と矛盾する課題として扱っていたが、複数ユーザー対応(パターンB)へ方針転換した
   ため、現時点では対応不要(冒頭の方針転換・5章を参照)。

このうち1点目を、本ドキュメントで対処方針を詰める。

## 2. 全体方針

- **パターンB(ユーザーごとのデータ分離)を将来的な方向性とする**。1ユーザーが複数植物を管理する
  だけでなく、複数ユーザーがそれぞれ自分のアカウントでデバイスをBLEペアリング・紐付けし、他ユーザー
  は紐付けていないデバイス/植物を扱えないようにする想定へ変更した(冒頭の方針転換を参照)。
  要件定義書9章の「単一ユーザー構成」という前提は、v2以降で見直しが必要になる。
- ただし**本書(3〜4章)で扱うトークン検証自体は「ログインしている本人からのリクエストか」の
  確認にとどまる**。ユーザーごとのアクセス制御(誰がどのplant/deviceにアクセスできるか)は、
  `PlantStore`・サーバーAPI・DBスキーマ側でユーザーとデバイス/植物の紐付けを持つ設計が別途必要で、
  本書ではまだ未着手(7章に追記)。現状(v1〜v2初期)は`plants`・`devices`とも1レコードのみの
  運用のため、ログイン済みであれば誰でも同じ1件のデータにアクセスできる状態が続く。
- ESP32(センサーデバイス)はFirebaseのユーザーではないため、`POST /sensor` だけは別方式で保護する
  (4章で詳述)。将来ユーザーごとのデバイス紐付けが入る場合、案B(デバイスごとの個別トークン)側の
  設計にユーザー紐付けを乗せる形になる見込み。

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

## 4. ESP32(`POST /sensor`)の扱い【実装済み・案Aを採用】

ESP32はFirebase Authのユーザーとしてログインする主体ではないため、3章の方式をそのまま適用できない。
以下の案A(固定の共有シークレット)を採用し、実装済み。

### 採用: 案A: 固定の共有シークレット(簡易・実装コスト最小)

- `.env` の `DEVICE_API_KEY` を固定値として持たせ、ESP32側は `POST /sensor` のヘッダーに
  同じ値を `X-Device-Api-Key` として付与して送信する(`esp32/plant_sensor_integrated/secrets.h`の
  `DEVICE_API_KEY`と一致させる)。
- サーバー側は `server/middleware/require_device_auth.js`(`requireDeviceAuth`)で
  `timingSafeEqual` によるタイミング攻撃耐性のある文字列比較で検証する。
- デメリット:鍵が漏れた場合、全デバイス共通の鍵のため無効化が全デバイスに影響する。ただしv1は
  1デバイスのみ・v2でも数台規模の想定のため、実害は小さいと判断し、この方式で確定した。

```javascript
// server/middleware/require_device_auth.js (実装済み)
import { timingSafeEqual } from 'node:crypto';
import { sendError } from '../utils/errors.js';

export function requireDeviceAuth(req, res, next) {
  const configuredKey = process.env.DEVICE_API_KEY;
  const requestKey = req.headers['x-device-api-key'];

  if (!configuredKey || typeof requestKey !== 'string') {
    return sendError(res, 401, 'UNAUTHENTICATED', 'デバイス認証が必要です');
  }

  const expected = Buffer.from(configuredKey);
  const actual = Buffer.from(requestKey);
  if (expected.length !== actual.length || !timingSafeEqual(expected, actual)) {
    return sendError(res, 401, 'UNAUTHENTICATED', 'デバイス認証に失敗しました');
  }

  return next();
}
```

### 見送り: 案B: デバイスごとの個別トークン(拡張性重視)

- `devices` テーブルに `api_token` カラムを追加し、`POST /devices/pair` 時にサーバー側でランダムな
  トークンを発行してESP32に返す案。デバイスを個別に無効化できる、複数デバイス対応とも相性が良い。
- データモデル変更・ペアリングフローの変更が必要で実装コストが大きいため、v1〜v2初期では見送った。
  複数デバイス対応が具体化するタイミングで改めて検討する(7章参照)。

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
複数ユーザーがそれぞれアカウントを作成し、自分のデバイスをBLEでペアリング・紐付けて使う運用を
見据えているため、登録自体を塞ぐ必要はなくなった。

**TODO: パターンB本体の設計はまだ着手していない。** 具体的には、ユーザー(uid)とdevice/plantの
紐付けをどう持たせるか(例:`devices`/`plants`テーブルへの`owner_uid`追加)、他ユーザーの
device/plantへアクセスさせないアクセス制御(3章のトークン検証だけでは不十分)、BLEペアリング
フローとの連携方法などは未検討。複数ユーザー運用が具体化するタイミングで別途設計する。

## 6. 実装の優先順位(参考)

1. サーバー側トークン検証ミドルウェアの追加(3章)+ アプリ側の `Authorization` ヘッダー付与 ✅ 実装済み
2. `PlantStore` の初期化タイミングをログイン後に変更(3-3章) ✅ 実装済み
3. ESP32側の保護(4章・案A) ✅ 実装済み
4. ~~新規登録ボタンの削除(5章・案A)~~ → 方針転換により対応不要(5章参照)
5. ユーザーとデバイス/植物の紐付け設計(パターンB本体、5章TODO・7章参照) ⬜ 未着手
6. BLEペアリングフロー ⬜ 未着手

Push通知(FCM)は本ドキュメントのサーバー保護を土台に実装済み(詳細は[push-notification-design.md](push-notification-design.md)を参照)。複数植物対応は、パターンB本体の設計が固まった後に着手する想定。

## 7. 残課題・今後の検討事項

- IDトークンの検証をミドルウェア化した際、既存のFlutterテスト(`app/test/`)・サーバーテスト
  (`server/test/`)がどこまで壊れるか要確認。特に `HttpPlantRepository` を直接叩くテストは
  モックのヘッダー付与が必要になる可能性がある。
- ESP32側の送信間隔(`status-notification-design.md` 8章、本番運用10分間隔への変更は未実装)と、
  デバイス個別トークン化(案B)を同時に手を入れると変更範囲が大きくなるため、着手順序は
  別途相談したい。
- 複数植物・複数デバイス対応(5種の観葉植物)が具体化した際、`devices` テーブルへの
  `api_token` カラム追加(案B採用時)と、`species_thresholds` のテーブル化
  (`status-notification-design.md` 4-1章)を同じマイグレーションでまとめて行うと効率が良さそう。
- **複数ユーザー対応(パターンB)本体の設計が未着手**:ユーザー(uid)とdevice/plantをどう
  紐付けるか(例:`owner_uid`カラムの追加)、他ユーザーのdevice/plantへのアクセスを防ぐ
  アクセス制御(現状のトークン検証は「ログイン済みか」のみで「自分のデータか」までは見ていない)、
  BLEペアリング時にどのユーザーの紐付けとして登録するか、といった論点が残っている。要件定義書9章
  (単一ユーザー構成の制約)・`status-notification-design.md`・`system-design.md`のER図も、
  パターンBへの移行が具体化した時点で合わせて見直しが必要。
