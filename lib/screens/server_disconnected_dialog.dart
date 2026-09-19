import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../core/providers/server_config_provider.dart';
import 'server_config_screen.dart';

class ServerDisconnectionListener extends ConsumerWidget {
  final Widget child;

  const ServerDisconnectionListener({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<ServerConfig>(serverConfigProvider, (previous, next) {
      final wasConnected = previous?.status == ConnectionStatus.connected;
      final isNowDisconnected = next.status == ConnectionStatus.disconnected;

      if (wasConnected && isNowDisconnected) {
        _showDisconnectedDialog(context, ref);
      }
    });

    return child;
  }

  void _showDisconnectedDialog(BuildContext context, WidgetRef ref) {
    showCupertinoDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: GlassCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  CupertinoIcons.wifi_slash,
                  size: 40,
                  color: CupertinoColors.systemRed,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Server Disconnected',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: CupertinoColors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'The connection to the server was lost. Please check '
                      'that the server is still running and that your '
                      'device is connected to the network.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: CupertinoColors.white,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: GlassButton.custom(
                    width: double.infinity,
                    height: 48,
                    shape: const LiquidRoundedRectangle(borderRadius: 14),
                    onTap: () {
                      Navigator.of(dialogContext).pop();
                      ref.read(serverConfigProvider.notifier).resetToEntry();
                      Navigator.of(context).pushAndRemoveUntil(
                        CupertinoPageRoute(
                          builder: (_) =>
                              ServerConfigScreen(homeScreen: child),
                        ),
                            (route) => false,
                      );
                    },
                    child: const Text(
                      'Close',
                      style: TextStyle(
                        color: CupertinoColors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}