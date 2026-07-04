① システム構成

センサー
  │
  ▼
ESP32
  │ HTTP(JSON)
  ▼
Node.js
  │
  ├── SQLite
  │
  ▼
Flutter

② ディレクトリ構成

project
│
├── app
│   ├── screens
│   ├── widgets
│   ├── models
│   ├── services
│   └── main.dart
│
├── server
│   ├── routes
│   ├── database
│   ├── controllers
│   └── app.js
│
├── esp32
│   └── main.ino
│
└── docs

③ 画面設計

ホーム画面
・植物一覧
・現在温度
・現在湿度
・現在土壌水分
↓
植物詳細
・センサー値
・履歴ボタン
↓
履歴
・グラフ表示

各画面について

④ API設計

Method	URL	内容
GET	/plants	植物一覧
GET	/plants/:id	植物詳細
GET	/history/:id	履歴取得
POST	/sensor	ESP32から送信

GET /plants
↓
[
  {
    "id":1,
    "name":"サボテン",
    "temperature":24.5,
    "humidity":60,
    "soil":42
  }
]

⑤ データベース設計

SQLiteのテーブルを書きます。

plants
列	型
id	INTEGER
name	TEXT
image	TEXT

sensor_logs
列	型
id	INTEGER
plant_id	INTEGER
temperature	REAL
humidity	REAL
soil	REAL
created_at	TEXT

⑥ ESP32設計

センサー	GPIO
DHT22	GPIO4
土壌水分	GPIO34

⑦ 通信仕様

ESP32
↓
POST /sensor
送信
{
  "temperature":24.5,
  "humidity":61,
  "soil":40
}
Node.js
↓
SQLite保存
↓
Flutter
↓
GET /plants

⑧ データフロー

植物
 │
 ▼
センサー
 │
 ▼
ESP32
 │
 ▼
Node.js
 │
 ▼
SQLite
 │
 ▼
Flutter
 │
 ▼
利用者
