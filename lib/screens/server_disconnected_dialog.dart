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
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => GlassDialog(
        title: const Text('Server Disconnected'),
        content: const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            'The connection to the server was lost. Please check that '
                'the server is still running and that your device is '
                'connected to the network.',
            textAlign: TextAlign.center,
          ),
        ),
        actions: [
          GlassButton(
            child: const Text('Close'),
            onTap: () {
              Navigator.of(dialogContext).pop();
              ref.read(serverConfigProvider.notifier).resetToEntry();
              Navigator.of(context).pushAndRemoveUntil(
                CupertinoPageRoute(
                  builder: (_) => ServerConfigScreen(homeScreen: child),
                ),
                    (route) => false,
              );
            },
          ),
        ],
      ),
    );
  }
}