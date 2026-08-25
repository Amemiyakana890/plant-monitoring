import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class FirebaseConfig {
  static Future<String?> initialize() async {
    final options = _optionsForCurrentPlatform();
    if (options == null) {
      return 'Firebase設定がありません。app/.envにFirebaseの設定値を追加してください。';
    }

    try {
      await Firebase.initializeApp(options: options);
      return null;
    } on FirebaseException catch (error) {
      return 'Firebaseの初期化に失敗しました(${error.code})。設定値を確認してください。';
    }
  }

  static FirebaseOptions? _optionsForCurrentPlatform() {
    final prefix = _platformPrefix;
    final apiKey = _value('${prefix}API_KEY');
    final appId = _value('${prefix}APP_ID');
    final messagingSenderId = _value('FIREBASE_MESSAGING_SENDER_ID');
    final projectId = _value('FIREBASE_PROJECT_ID');

    if ([
      apiKey,
      appId,
      messagingSenderId,
      projectId,
    ].any((value) => value == null)) {
      return null;
    }

    return FirebaseOptions(
      apiKey: apiKey!,
      appId: appId!,
      messagingSenderId: messagingSenderId!,
      projectId: projectId!,
      authDomain: _value('FIREBASE_AUTH_DOMAIN'),
      storageBucket: _value('FIREBASE_STORAGE_BUCKET'),
      measurementId: _value('FIREBASE_MEASUREMENT_ID'),
    );
  }

  static String get _platformPrefix {
    if (kIsWeb) return 'FIREBASE_WEB_';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'FIREBASE_ANDROID_';
      case TargetPlatform.iOS:
        return 'FIREBASE_IOS_';
      default:
        return 'FIREBASE_';
    }
  }

  static String? _value(String key) {
    final value = dotenv.env[key]?.trim();
    return value == null || value.isEmpty ? null : value;
  }
}
