import 'package:flutter/material.dart';

import '../../state/auth_store.dart';
import '../../state/auth_store_scope.dart';
import '../../theme/app_dimensions.dart';

/// メール/パスワードでのログイン・新規登録画面(v2・Firebase Auth)。
///
/// [AuthGate](../auth_gate.dart)が「未ログイン」を検知した際にここへ
/// 振り分ける。ログイン成功後はNavigator操作を行わない
/// (Firebase Authのauth状態が更新→[AuthStore]がnotifyListeners→
/// [AuthGate]が自動的に本来の画面([AppRoot])へ切り替える、という
/// PlantRegistrationPageと同じ設計)。
///
/// 「本人確認のゲート」としての導入(パターンA)のため、複数アカウントを
/// 前提とした作りにはしていない。1画面でログイン/新規登録を切り替えられる
/// 形にすることで、初回セットアップ時に別途登録用の画面を用意する手間を
/// 省いている。
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // false: ログインモード / true: 新規登録モード
  bool _isRegisterMode = false;
  bool _triedSubmit = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool get _isEmailValid => _emailController.text.trim().contains('@');
  bool get _isPasswordValid => _passwordController.text.trim().length >= 6;

  Future<void> _submit(AuthStore store) async {
    setState(() => _triedSubmit = true);

    if (!_isEmailValid || !_isPasswordValid) {
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    final success = _isRegisterMode
        ? await store.register(email: email, password: password)
        : await store.signIn(email: email, password: password);

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(store.errorMessage ?? 'ログインできませんでした')),
      );
    }
    // 成功時は何もしない。AuthStore.currentUserが更新されると
    // AuthGateが自動的に切り替える。
  }

  @override
  Widget build(BuildContext context) {
    final store = AuthStoreScope.of(context);
    final showEmailError = _triedSubmit && !_isEmailValid;
    final showPasswordError = _triedSubmit && !_isPasswordValid;

    return Scaffold(
      appBar: AppBar(title: const Text('ログイン')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.medium),
          children: [
            Text(
              '植物見守り',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.small),
            Text(
              _isRegisterMode
                  ? 'メールアドレスとパスワードで新しいアカウントを作成します。'
                  : 'メールアドレスとパスワードでログインしてください。',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.large),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: 'メールアドレス',
                hintText: 'example@example.com',
                errorText: showEmailError ? 'メールアドレスを正しく入力してください' : null,
              ),
              onChanged: (_) {
                if (_triedSubmit) setState(() {});
              },
            ),
            const SizedBox(height: AppSpacing.medium),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'パスワード',
                hintText: '6文字以上',
                errorText: showPasswordError ? 'パスワードは6文字以上で入力してください' : null,
              ),
              onChanged: (_) {
                if (_triedSubmit) setState(() {});
              },
              onSubmitted: (_) => _submit(store),
            ),
            const SizedBox(height: AppSpacing.large),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: store.isSubmitting ? null : () => _submit(store),
                child: store.isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(_isRegisterMode ? 'アカウントを作成する' : 'ログインする'),
              ),
            ),
            const SizedBox(height: AppSpacing.small),
            TextButton(
              onPressed: store.isSubmitting
                  ? null
                  : () => setState(() {
                      _isRegisterMode = !_isRegisterMode;
                      _triedSubmit = false;
                    }),
              child: Text(
                _isRegisterMode ? 'すでにアカウントをお持ちの方はこちら' : 'はじめての方はこちら(アカウントを作成)',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
