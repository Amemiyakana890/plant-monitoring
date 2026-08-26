# v2 セキュリティ・Firebase設計(ドラフト)

> v2で導入したFirebase Auth(ログイン機能)を土台に、「サーバーAPIが無認証のまま」という
> 現状の課題を解消するための設計をまとめる。
> ログイン画面自体は実装済み(`app/lib/screens/auth/`, `app/lib/state/auth_store.dart`)。
> 本書はその続き、**サーバー側の保護**が主題。
> 数値・方式ともに**暫定案**。実装しながら調整すること(この文書内のTODOを参照)。

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
2. **新規登録が誰でもできる**:`LoginPage` に「アカウントを作成する」ボタンがあり、単一ユーザー
   前提のアプリにもかかわらず、誰でも自由にアカウントを作成してログインできてしまう。

この2点を、本ドキュメントで対処方針を詰める。

## 2. 全体方針

- **パターンA(本人確認のゲート)は維持する**。ユーザーごとのデータ分離(パターンB)には踏み込まない。
  複数植物対応(5種)は「1ユーザーが複数の植物を管理する」であって「複数ユーザーがそれぞれ
  データを持つ」ではないため、要件定義書9章の単一ユーザー構成という前提は崩さない。
- **サーバーAPIの保護は「ログインしている本人からのリクエストか」を確認するだけ**にとどめる。
  Firestoreのセキュリティルールのような「ユーザーごとのアクセス制御」は不要(ユーザーは1人しかいないため)。
- ESP32(センサーデバイス)はFirebaseのユーザーではないため、`POST /sensor` だけは別方式で保護する
  (4章で詳述)。

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

### 3-2. 検証方式(`firebase-admin`)

- サーバー側に `firebase-admin` を追加し、Firebase Consoleから取得したサービスアカウント鍵で初期化する。
- Expressのミドルウェアとして実装し、上表の「必須」エンドポイント全体に一括適用する(`app.js` の
  ルーティングより前段)。

```javascript
// server/middleware/verifyFirebaseToken.js (イメージ)
import { getAuth } from 'firebase-admin/auth';
import { sendError } from '../utils/errors.js';

export async function verifyFirebaseToken(req, res, next) {
  const authHeader = req.headers.authorization; // "Bearer <idToken>"
  const idToken = authHeader?.startsWith('Bearer ') ? authHeader.slice(7) : null;

  if (!idToken) {
    return sendError(res, 401, 'UNAUTHORIZED', '認証情報がありません');
  }

  try {
    await getAuth().verifyIdToken(idToken);
    next();
  } catch (err) {
    sendError(res, 401, 'UNAUTHORIZED', '認証に失敗しました');
  }
}
```

- `app.js` 側の適用イメージ:

```javascript
app.use('/api/plants', verifyFirebaseToken, plantsRouter);
app.use('/api/devices', verifyFirebaseToken, devicesRouter);
app.use('/api/history', verifyFirebaseToken, historyRouter);
app.use('/api/notifications', verifyFirebaseToken, notificationsRouter);
app.use('/api/settings', verifyFirebaseToken, settingsRouter);
app.use('/api/species', verifyFirebaseToken, speciesRouter);
app.use('/api/sensor', sensorRouter); // ← 別方式(4章)。ここではverifyFirebaseTokenを挟まない
```

- エラーレスポンスは既存の形式(`system-design.md` 5-8章、`server/utils/errors.js` の `sendError`)
  にそのまま合わせ、401 `UNAUTHORIZED` を新設する。

### 3-3. アプリ側の対応(Flutter)

- `HttpPlantRepository` が各リクエスト時に `Authorization: Bearer <idToken>` ヘッダーを付与するよう修正が必要。
- IDトークンは `FirebaseAuth.instance.currentUser?.getIdToken()` で取得できる(有効期限は1時間、
  SDKが自動でリフレッシュするため、リクエストの都度取得し直せば期限切れは基本的に気にしなくてよい)。
- `main.dart` の現状のコメント(「PlantStoreの初期化はログイン状態に関わらず開始している」)は、
  この変更後は成立しなくなる。**トークン検証を追加するタイミングで、`PlantStore.loadInitial()` /
  `startPolling()` の開始をログイン後に遅らせる必要がある**(未ログイン中に叩くと401が返り続けるだけになるため)。

## 4. ESP32(`POST /sensor`)の扱い

ESP32はFirebase Authのユーザーとしてログインする主体ではないため、3章の方式をそのまま適用できない。
以下のいずれかで別途保護する。

### 案A: 固定の共有シークレット(簡易・実装コスト最小)

- `.env` に `DEVICE_API_KEY` のような固定値を1つ持たせ、ESP32側は `POST /sensor` のヘッダーに
  同じ値を付与して送信する(例: `X-Device-Key: <値>`)。
- サーバー側は単純な文字列比較で検証する。
- デメリット:鍵が漏れた場合、全デバイス共通の鍵のため無効化が全デバイスに影響する。ただしv1は
  1デバイスのみ・v2でも数台規模の想定のため、実害は小さい。

### 案B: デバイスごとの個別トークン(拡張性重視)

- `devices` テーブルに `api_token` カラムを追加し、`POST /devices/pair` 時にサーバー側でランダムな
  トークンを発行してESP32に返す(または初回セットアップ時にアプリ経由で払い出す)。
- ESP32は以降このトークンをヘッダーに付与して送信する。
- デバイスを個別に無効化できる、複数デバイス対応(v2で検討中)とも相性が良い。
- デメリット:データモデル変更・ペアリングフローの変更が必要で、実装コストは案Aより大きい。

**TODO: 案A・案Bどちらを採用するか未確定。** v2で複数デバイス対応(5種の植物、将来的に台数が増える
想定)を進めるなら案Bの方が長期的に扱いやすいが、まず案Aで最小実装し、複数デバイス対応が具体化した
タイミングで案Bへ切り替える、という段階的な進め方も選択肢としてありうる。

## 5. 新規登録を閉じる方式

単一ユーザー前提のアプリで、誰でもアカウントを作成できる状態は「本人確認のゲート」の目的と
矛盾するため、以下のいずれかで塞ぐ。

| 案 | 内容 | コスト |
|---|---|---|
| A. UIから登録ボタンを削除 | `LoginPage` の「アカウントを作成する」導線を外し、最初の1アカウントは
Firebase Console側で手動作成する | 最小 |
| B. 招待コード方式 | 事前に決めたコードを知っている場合のみ登録できるようにする | 中 |
| C. Firebase側で新規登録をブロック | Firebase ConsoleのAuthentication設定、または
Cloud Functionsの `beforeCreate` フックで登録自体を拒否する | 中〜大 |

**TODO: 単一ユーザーで運用し続ける前提なら案Aで十分**。将来的にユーザーを増やす可能性が具体的に
出てきた場合のみ案B・Cを検討する。

## 6. 実装の優先順位(参考)

1. サーバー側トークン検証ミドルウェアの追加(3章)+ アプリ側の `Authorization` ヘッダー付与
2. `PlantStore` の初期化タイミングをログイン後に変更(3-3章)
3. 新規登録ボタンの削除(5章・案A)
4. ESP32側の保護(4章・案A→将来的に案Bへ)

Push通知(FCM)・BLE・複数植物対応は、上記のサーバー保護が済んだ後に着手する想定
(Push通知はサーバー→アプリへの片方向配信のため、本ドキュメントの認証設計とは独立して進められる)。

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
