import 'package:flutter/material.dart';

import '../../theme/app_dimensions.dart';
import '../../widgets/app_bottom_nav_bar.dart';
import '../../widgets/settings_app_bar.dart';

/// 現在のアプリ実装に基づくプライバシーポリシー草案。
class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const SettingsAppBar(title: 'プライバシーポリシー'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.medium),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.medium),
                    child: Text(
                      'このページは現在のアプリ実装に基づく草案です。'
                      '公開・運用の前に、運営者情報、問い合わせ先および実際のデータの取扱いを確認してください。',
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.medium),
                _PolicySection(title: '1. 運営者', content: '植物見守りプロジェクト'),
                _PolicySection(
                  title: '2. 取得・利用する情報',
                  content:
                      '本アプリでは、アカウント登録・ログインのため、メールアドレスを取得します。'
                      'パスワードはFirebase Authenticationを通じて認証に使用され、本アプリのAPIサーバーには保存しません。'
                      '認証にはFirebaseが発行するユーザー識別子も使用します。\n\n'
                      'また、アプリの機能を提供するため、植物の名前・種類、デバイス名・MACアドレス等のデバイス情報、'
                      '温度・湿度・土壌水分・照度のセンサーデータ、水やり記録、通知設定・通知の既読状態、'
                      'Push通知を届けるためのFCMデバイストークンおよびプラットフォーム情報を取り扱います。'
                      'これらはメールアドレスとは別に、アプリの機能提供に必要な情報として取り扱います。',
                ),
                _PolicySection(
                  title: '3. 利用目的',
                  content:
                      '取得した情報は、アカウント認証、植物・デバイス情報とセンサーデータの表示、'
                      '状態判定と通知の生成・配信、通知設定の保存、および本アプリの維持・改善のために利用します。',
                ),
                _PolicySection(
                  title: '4. 外部サービスへの送信',
                  content:
                      'メールアドレスおよび認証情報はFirebase Authenticationによる認証に使用されます。'
                      'Push通知を利用する場合、FCMトークン等をFirebase Cloud Messagingと本アプリのAPIサーバーに送信します。'
                      '植物・デバイス情報、センサーデータ、通知情報は、本アプリの機能を提供するAPIサーバーに送信・保存されます。'
                      '各サービス提供者による情報の取扱いは、それぞれのプライバシーポリシー等をご確認ください。',
                ),
                _PolicySection(
                  title: '5. 保存と削除',
                  content:
                      '情報の保存期間は一律に定めていません。植物の削除などの機能による削除、'
                      'または管理者による削除が行われるまで、サーバー上に保存される場合があります。'
                      '現時点ではアカウント削除に伴うデータの一括削除手続きは用意されていません。'
                      'また、植物・デバイス情報等をユーザー識別子ごとに分離する機能は未実装で、'
                      '現在は単一ユーザーでの利用を前提としています。'
                      'ログアウト時にPush通知用のFCMトークンが自動削除されない場合があります。'
                      'データの確認・訂正・削除等を希望する場合は、下記の問い合わせ先へご連絡ください。',
                ),
                _PolicySection(
                  title: '6. 安全管理',
                  content:
                      '情報への不正アクセス、漏えい、改ざん等を防止するため、適切な安全管理に努めます。'
                      'ただし、インターネット通信や情報の保管における完全な安全性を保証するものではありません。',
                ),
                _PolicySection(
                  title: '7. ポリシーの変更',
                  content:
                      '法令や本アプリの機能・情報の取扱いに応じて、本ポリシーを変更することがあります。'
                      '変更後の内容は本アプリ内に掲載した時点から適用します。',
                ),
                _PolicySection(
                  title: '8. お問い合わせ',
                  content: '問い合わせ先メールアドレス：未設定（公開前に設定してください）',
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.small),
                  child: Text('制定日：2026年10月23日'),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNavBar(),
    );
  }
}

class _PolicySection extends StatelessWidget {
  const _PolicySection({required this.title, required this.content});

  final String title;
  final String content;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.medium),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.medium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.small),
              Text(content),
            ],
          ),
        ),
      ),
    );
  }
}
