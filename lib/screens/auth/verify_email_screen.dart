import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../../core/providers/auth_provider.dart';
import '../../widgets/primary_glass_button.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  final String email;

  const VerifyEmailScreen({super.key, required this.email});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  final _codeController = TextEditingController();
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _errorMessage = 'Enter the 6-digit code from your email.');
      return;
    }

    setState(() => _errorMessage = null);

    final result = await ref
        .read(authProvider.notifier)
        .verifyEmail(email: widget.email, code: code);

    if (!mounted) return;

    if (!result.ok) {
      setState(() => _errorMessage = result.message);
      return;
    }

    GlassToast.show(
      context,
      message: 'Email verified. You can sign in now.',
      type: GlassToastType.success,
    );
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _resend() async {
    final result = await ref
        .read(authProvider.notifier)
        .resendVerification(email: widget.email);

    if (!mounted) return;

    GlassToast.show(
      context,
      message: result.message,
      type: result.ok ? GlassToastType.success : GlassToastType.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    return GlassScaffold(
      statusBarStyle: GlassStatusBarStyle.auto,
      appBar: GlassAppBar(title: const Text('Verify Email')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    CupertinoIcons.envelope_badge,
                    size: 56,
                    color: CupertinoColors.activeBlue,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Check your email',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: CupertinoColors.label,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'We sent a 6-digit code to ${widget.email}. '
                        'Enter it below to activate your account.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: CupertinoColors.secondaryLabel,
                    ),
                  ),
                  const SizedBox(height: 28),

                  GlassTextField(
                    controller: _codeController,
                    placeholder: '000000',
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    enabled: !auth.isBusy,
                    maxLength: 6,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    prefixIcon: const Icon(CupertinoIcons.number),
                    onSubmitted: (_) => _submit(),
                  ),

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
                    label: 'Verify',
                    icon: CupertinoIcons.checkmark_seal,
                    isLoading: auth.isBusy,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: 4),
                  SubtleGlassLink(
                    label: "Didn't get it? Send a new code",
                    onPressed: auth.isBusy ? null : _resend,
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