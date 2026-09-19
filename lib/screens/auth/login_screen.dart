import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/ipon_logo.dart';
import '../../widgets/primary_glass_button.dart';
import 'register_screen.dart';
import 'verify_email_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _errorMessage = null);

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Enter your email and password.');
      return;
    }

    final result = await ref
        .read(authProvider.notifier)
        .login(email: email, password: password);

    if (!mounted) return;

    if (result.ok) {
      return;
    }

    if (result.needsVerification) {
      Navigator.of(context).push(
        CupertinoPageRoute(builder: (_) => VerifyEmailScreen(email: email)),
      );
      return;
    }

    setState(() => _errorMessage = result.message);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    return GlassScaffold(
      statusBarStyle: GlassStatusBarStyle.auto,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: IponLogo(size: 88)),
                  const SizedBox(height: 16),
                  const Text(
                    'Ipon',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Plan, track, and reach your savings goals.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption,
                  ),
                  const SizedBox(height: 32),

                  GlassTextField(
                    controller: _emailController,
                    placeholder: 'Email address',
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    enabled: !auth.isBusy,
                    prefixIcon: const Icon(
                      CupertinoIcons.mail,
                      color: AppColors.moneyGreen,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GlassPasswordField(
                    controller: _passwordController,
                    placeholder: 'Password',
                    enabled: !auth.isBusy,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                  ),

                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    _ErrorLine(message: _errorMessage!),
                  ],

                  const SizedBox(height: 20),
                  PrimaryGlassButton(
                    label: 'Sign In',
                    icon: CupertinoIcons.arrow_right_to_line,
                    isLoading: auth.isBusy,
                    onPressed: _submit,
                  ),

                  const SizedBox(height: 4),
                  SubtleGlassLink(
                    label: 'Forgot your password?',
                    onPressed: auth.isBusy
                        ? null
                        : () => Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const ForgotPasswordScreen(),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "Don't have an account?",
                        style: AppTextStyles.caption,
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: auth.isBusy
                            ? null
                            : () => Navigator.of(context).push(
                          CupertinoPageRoute(
                            builder: (_) => const RegisterScreen(),
                          ),
                        ),
                        child: const Text(
                          'Create one',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.moneyGreen,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorLine extends StatelessWidget {
  final String message;

  const _ErrorLine({required this.message});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          CupertinoIcons.exclamationmark_circle,
          color: AppColors.statusNegative,
          size: 18,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(
              color: AppColors.statusNegative,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}