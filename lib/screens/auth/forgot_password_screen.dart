import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../../core/providers/auth_provider.dart';
import '../../widgets/primary_glass_button.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _codeSent = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    FocusScope.of(context).unfocus();

    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _errorMessage = 'Enter a valid email address.');
      return;
    }

    setState(() => _errorMessage = null);

    final result =
    await ref.read(authProvider.notifier).forgotPassword(email: email);

    if (!mounted) return;

    if (!result.ok) {
      setState(() => _errorMessage = result.message);
      return;
    }

    GlassToast.show(
      context,
      message: result.message,
      type: GlassToastType.info,
    );

    setState(() => _codeSent = true);
  }

  Future<void> _applyReset() async {
    FocusScope.of(context).unfocus();

    final code = _codeController.text.trim();
    final password = _passwordController.text;

    if (code.length != 6) {
      setState(() => _errorMessage = 'Enter the 6-digit code from your email.');
      return;
    }
    if (password.length < 8) {
      setState(() => _errorMessage = 'Password must be at least 8 characters.');
      return;
    }

    setState(() => _errorMessage = null);

    final result = await ref.read(authProvider.notifier).resetPassword(
      email: _emailController.text.trim(),
      code: code,
      newPassword: password,
    );

    if (!mounted) return;

    if (!result.ok) {
      setState(() => _errorMessage = result.message);
      return;
    }

    GlassToast.show(
      context,
      message: 'Password updated. Sign in with your new password.',
      type: GlassToastType.success,
    );

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    return GlassScaffold(
      statusBarStyle: GlassStatusBarStyle.auto,
      appBar: GlassAppBar(title: const Text('Reset Password')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    _codeSent
                        ? CupertinoIcons.lock_rotation
                        : CupertinoIcons.question_circle,
                    size: 56,
                    color: CupertinoColors.activeBlue,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _codeSent ? 'Set a new password' : 'Forgot your password?',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: CupertinoColors.label,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _codeSent
                        ? 'Enter the code we sent you, then choose a new password.'
                        : 'Enter your email and we will send you a reset code.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: CupertinoColors.secondaryLabel,
                    ),
                  ),
                  const SizedBox(height: 28),

                  GlassTextField(
                    controller: _emailController,
                    placeholder: 'Email address',
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    enabled: !auth.isBusy && !_codeSent,
                    prefixIcon: const Icon(CupertinoIcons.mail),
                    onSubmitted: (_) => _codeSent ? null : _requestCode(),
                  ),

                  if (_codeSent) ...[
                    const SizedBox(height: 12),
                    GlassTextField(
                      controller: _codeController,
                      placeholder: '000000',
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      enabled: !auth.isBusy,
                      maxLength: 6,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      prefixIcon: const Icon(CupertinoIcons.number),
                    ),
                    const SizedBox(height: 12),
                    GlassPasswordField(
                      controller: _passwordController,
                      placeholder: 'New password (min. 8 characters)',
                      enabled: !auth.isBusy,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _applyReset(),
                    ),
                  ],

                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          CupertinoIcons.exclamationmark_circle,
                          color: CupertinoColors.systemRed,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: CupertinoColors.systemRed,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 20),
                  PrimaryGlassButton(
                    label: _codeSent ? 'Update Password' : 'Send Reset Code',
                    icon: _codeSent
                        ? CupertinoIcons.checkmark_seal
                        : CupertinoIcons.paperplane,
                    isLoading: auth.isBusy,
                    onPressed: _codeSent ? _applyReset : _requestCode,
                  ),

                  if (_codeSent)
                    SubtleGlassLink(
                      label: 'Use a different email address',
                      onPressed: auth.isBusy
                          ? null
                          : () => setState(() {
                        _codeSent = false;
                        _errorMessage = null;
                        _codeController.clear();
                        _passwordController.clear();
                      }),
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