import 'package:flutter/material.dart';

import '../../state/auth_store.dart';
import '../../state/auth_store_scope.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';

/// メール/パスワードでのログイン・新規登録画面(v2・Firebase Auth)。
///
/// [AuthGate](../auth_gate.dart)が「未ログイン」を検知した際にここへ
/// 振り分ける。ログイン成功後はNavigator操作を行わない
/// (Firebase Authのauth状態が更新→[AuthStore]がnotifyListeners→
/// [AuthGate]が自動的に本来の画面([AppRoot])へ切り替える、という
/// PlantRegistrationPageと同じ設計)。
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isRegisterMode = false;
  bool _triedSubmit = false;
  bool _obscurePassword = true;

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
      if (!_isRegisterMode && store.shouldOfferRegistration) {
        final shouldCreateAccount = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('ログインできませんでした'),
            content: const Text(
              'メールアドレスまたはパスワードが正しくないか、'
              'アカウントが未作成の可能性があります。'
              '未登録の場合は新規作成画面へ進めます。',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('ログイン画面に戻る'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('新規作成へ'),
              ),
            ],
          ),
        );
        if (shouldCreateAccount == true && mounted) {
          setState(() {
            _isRegisterMode = true;
            _triedSubmit = false;
            _passwordController.clear();
          });
        }
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(store.errorMessage ?? 'ログインできませんでした')),
      );
    }
    // AuthGate switches to the app after Firebase Auth updates its state.
  }

  @override
  Widget build(BuildContext context) {
    final store = AuthStoreScope.of(context);
    final showEmailError = _triedSubmit && !_isEmailValid;
    final showPasswordError = _triedSubmit && !_isPasswordValid;

    return Scaffold(
      body: ColoredBox(
        color: AppColors.background,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.medium,
              AppSpacing.large,
              AppSpacing.medium,
              AppSpacing.large,
            ),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _LoginHero(isRegisterMode: _isRegisterMode),
                      const SizedBox(height: AppSpacing.medium),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.medium),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                _isRegisterMode ? 'はじめまして' : 'おかえりなさい',
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: AppSpacing.extraSmall),
                              Text(
                                _isRegisterMode
                                    ? 'アカウントを作成して、植物の見守りを始めましょう。'
                                    : 'ログインして、植物の今日の様子を確認しましょう。',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: const Color(0xFF71806F)),
                              ),
                              const SizedBox(height: AppSpacing.large),
                              TextField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.email],
                                autocorrect: false,
                                decoration: InputDecoration(
                                  labelText: 'メールアドレス',
                                  hintText: 'example@example.com',
                                  prefixIcon: const Icon(
                                    Icons.mail_outline_rounded,
                                  ),
                                  errorText: showEmailError
                                      ? 'メールアドレスを正しく入力してください'
                                      : null,
                                  filled: true,
                                  fillColor: const Color(0xFFF7F9F4),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE3EADF),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(
                                      color: AppColors.primary,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                                onChanged: (_) {
                                  if (_triedSubmit) setState(() {});
                                },
                              ),
                              const SizedBox(height: AppSpacing.medium),
                              TextField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.done,
                                autofillHints: [
                                  _isRegisterMode
                                      ? AutofillHints.newPassword
                                      : AutofillHints.password,
                                ],
                                decoration: InputDecoration(
                                  labelText: 'パスワード',
                                  hintText: '6文字以上',
                                  prefixIcon: const Icon(
                                    Icons.lock_outline_rounded,
                                  ),
                                  suffixIcon: IconButton(
                                    tooltip: _obscurePassword
                                        ? 'パスワードを表示'
                                        : 'パスワードを隠す',
                                    onPressed: () => setState(
                                      () =>
                                          _obscurePassword = !_obscurePassword,
                                    ),
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                  ),
                                  errorText: showPasswordError
                                      ? 'パスワードは6文字以上で入力してください'
                                      : null,
                                  filled: true,
                                  fillColor: const Color(0xFFF7F9F4),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE3EADF),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(
                                      color: AppColors.primary,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                                onChanged: (_) {
                                  if (_triedSubmit) setState(() {});
                                },
                                onSubmitted: (_) => _submit(store),
                              ),
                              const SizedBox(height: AppSpacing.large),
                              SizedBox(
                                height: 54,
                                child: FilledButton.icon(
                                  onPressed: store.isSubmitting
                                      ? null
                                      : () => _submit(store),
                                  icon: store.isSubmitting
                                      ? const SizedBox(
                                          width: 19,
                                          height: 19,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Icon(
                                          _isRegisterMode
                                              ? Icons.spa_outlined
                                              : Icons.login_rounded,
                                        ),
                                  label: Text(
                                    _isRegisterMode ? 'アカウントを作成する' : 'ログインする',
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.small),
                              Center(
                                child: TextButton(
                                  onPressed: store.isSubmitting
                                      ? null
                                      : () => setState(() {
                                          _isRegisterMode = !_isRegisterMode;
                                          _triedSubmit = false;
                                        }),
                                  child: Text(
                                    _isRegisterMode
                                        ? '← ログインに戻る'
                                        : 'はじめての方はこちら（新規登録）',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.medium),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.shield_outlined,
                            size: 16,
                            color: Color(0xFF71806F),
                          ),
                          SizedBox(width: AppSpacing.extraSmall),
                          Flexible(
                            child: Text(
                              '安全な認証で植物との暮らしを守ります',
                              style: TextStyle(
                                color: Color(0xFF71806F),
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoginHero extends StatelessWidget {
  const _LoginHero({required this.isRegisterMode});

  final bool isRegisterMode;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 240;

    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: SizedBox(
        height: narrow ? 208 : 224,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'images/plant_photos/monstera.jpg',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF6E8B5F), AppColors.primary],
                  ),
                ),
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x44152217), Color(0xD9162519)],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(
                narrow ? AppSpacing.medium : AppSpacing.large,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.eco_rounded,
                          color: Colors.white,
                        ),
                      ),
                      if (!narrow) ...[
                        const SizedBox(width: AppSpacing.small),
                        const Flexible(
                          child: Text(
                            'PLANT CARE',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isRegisterMode ? '育てる毎日を、ここから。' : '植物と、心地よく暮らす。',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontSize: narrow ? 18 : 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.extraSmall),
                      Text(
                        narrow ? '小さな変化に気づく、見守り習慣。' : '小さな変化に気づく、植物の見守り習慣。',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
