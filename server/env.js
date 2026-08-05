// プロジェクトルートの .env(.env.example参照)を読み込むための起点ファイル。
//
// 【なぜこのファイルが必要か】
// ESモジュールは「自分がimportしている依存モジュールの評価」を、
// 自分自身のトップレベルの処理より先に必ず終わらせる。
// そのため、app.js の中で他のimportの間に `dotenv.config()` を
// 直接書いても、その処理は import した ./routes/plants.js (→db.js) が
// 評価された「後」に実行されてしまい、DB_PATHなどの環境変数が
// db.js側で読み取れないタイミング問題が発生する。
//
// これを避けるため、env.js を単独のファイルに切り出し、
// app.js の一番最初のimportとして読み込む(自分自身が依存として
// 一番先に評価されるようにする)。
//
// 【CWD(カレントディレクトリ)に依存しない理由】
// `cd server && node app.js` で実行しても、プロジェクトルートで
// `node server/app.js` のように実行しても、常に同じ
// プロジェクトルート直下の .env を見つけられるよう、
// このファイル自身の場所からの相対パスで解決している。
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import dotenv from 'dotenv';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

dotenv.config({ path: path.resolve(__dirname, '../.env') });
