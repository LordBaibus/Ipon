import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../core/providers/server_config_provider.dart';

class ServerConfigScreen extends ConsumerStatefulWidget {
  final Widget homeScreen;

  const ServerConfigScreen({super.key, required this.homeScreen});

  @override
  ConsumerState<ServerConfigScreen> createState() => _ServerConfigScreenState();
}

class _ServerConfigScreenState extends ConsumerState<ServerConfigScreen> {
  late final TextEditingController _urlController;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(
      text: ref.read(serverConfigProvider).baseUrl,
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(serverConfigProvider);
    if (config.status == ConnectionStatus.connected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          CupertinoPageRoute(builder: (_) => widget.homeScreen),
        );
      });
    }

    final isConnecting = config.status == ConnectionStatus.connecting;

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
                  const Icon(
                    CupertinoIcons.wifi,
                    size: 56,
                    color: CupertinoColors.activeBlue,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Connect to Ipon Server',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: CupertinoColors.label,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Enter the server address to continue. '
                        'You can find this in your API documentation.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: CupertinoColors.secondaryLabel,
                    ),
                  ),
                  const SizedBox(height: 32),

                  GlassTextField(
                    controller: _urlController,
                    placeholder: 'e.g. https://ipon-app.com/api',
                    keyboardType: TextInputType.url,
                    enabled: !isConnecting,
                    prefixIcon: const Icon(CupertinoIcons.link),
                    onSubmitted: (_) => _attemptConnect(),
                  ),

                  if (config.errorMessage != null) ...[
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
                            config.errorMessage!,
                            style: const TextStyle(
                              color: CupertinoColors.systemRed,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: GlassButton.custom(
                      onTap: isConnecting ? () {} : _attemptConnect,
                      enabled: !isConnecting,
                      width: double.infinity,
                      height: 52,
                      child: isConnecting
                          ? const CupertinoActivityIndicator(
                        color: CupertinoColors.white,
                      )
                          : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(
                            CupertinoIcons.arrow_right_circle_fill,
                            color: CupertinoColors.white,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Connect to Server',
                            style: TextStyle(
                              color: CupertinoColors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                  const Text(
                    'Local testing quick reference:\n'
                        'iOS Simulator: http://localhost/ipon_api\n'
                        'Android Emulator: http://10.0.2.2/ipon_api\n'
                        'Physical device: http://<your-PC-LAN-IP>/ipon_api',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: CupertinoColors.tertiaryLabel,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _attemptConnect() {
    FocusScope.of(context).unfocus();
    ref.read(serverConfigProvider.notifier).connect(_urlController.text);
  }
}