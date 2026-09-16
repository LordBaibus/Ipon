import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../../core/providers/auth_provider.dart';
import '../../widgets/primary_glass_button.dart';
import 'verify_email_screen.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String? _validate() {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      return 'Please fill in all the fields.';
    }
    if (!email.contains('@') || !email.contains('.')) {
      return 'Please enter a valid email address.';
    }
    if (password.length < 8) {
      return 'Password must be at least 8 characters long.';
    }
    if (password != confirm) {
      return 'The passwords do not match.';
    }
    return null;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    final validationError = _validate();
    if (validationError != null) {
      setState(() => _errorMessage = validationError);
      return;
    }

    setState(() => _errorMessage = null);

    final email = _emailController.text.trim();
    final result = await ref.read(authProvider.notifier).register(
      fullName: _nameController.text.trim(),
      email: email,
      password: _passwordController.text,
    );

    if (!mounted) return;

    if (!result.ok) {
      setState(() => _errorMessage = result.message);
      return;
    }

    GlassToast.show(
      context,
      message: 'Account created. Check your email for the code.',
      type: GlassToastType.success,
    );

    Navigator.of(context).pushReplacement(
      CupertinoPageRoute(builder: (_) => VerifyEmailScreen(email: email)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    return GlassScaffold(
      statusBarStyle: GlassStatusBarStyle.auto,
      appBar: GlassAppBar(title: const Text('Create Account')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                const Text(
                  'Start saving with Ipon',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: CupertinoColors.label,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Track your own expenses, or share a plan with your group.',
                  style: TextStyle(
                    fontSize: 14,
                    color: CupertinoColors.secondaryLabel,
                  ),
                ),
                const SizedBox(height: 24),

                GlassTextField(
                  controller: _nameController,
                  placeholder: 'Full name',
                  textInputAction: TextInputAction.next,
                  enabled: !auth.isBusy,
                  prefixIcon: const Icon(CupertinoIcons.person),
                ),
                const SizedBox(height: 12),
                GlassTextField(
                  controller: _emailController,
                  placeholder: 'Email address',
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  enabled: !auth.isBusy,
                  prefixIcon: const Icon(CupertinoIcons.mail),
                ),
                const SizedBox(height: 12),
                GlassPasswordField(
                  controller: _passwordController,
                  placeholder: 'Password (min. 8 characters)',
                  enabled: !auth.isBusy,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                GlassPasswordField(
                  controller: _confirmController,
                  placeholder: 'Confirm password',
                  enabled: !auth.isBusy,
                  textInputAction: TextInputAction.done,
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
                  label: 'Create Account',
                  icon: CupertinoIcons.person_add,
                  isLoading: auth.isBusy,
                  onPressed: _submit,
                ),
                const SizedBox(height: 8),
                SubtleGlassLink(
                  label: 'Already have an account? Sign in',
                  onPressed: auth.isBusy
                      ? null
                      : () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}