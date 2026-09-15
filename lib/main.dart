import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'screens/server_config_screen.dart';
import 'screens/server_disconnected_dialog.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LiquidGlassWidgets.initialize();

  runApp(
    const ProviderScope(
      child: IponApp(),
    ),
  );
}

class IponApp extends StatelessWidget {
  const IponApp({super.key});

  @override
  Widget build(BuildContext context) {
    return LiquidGlassWidgets.wrap(
      child: CupertinoApp(
        title: 'Ipon',
        debugShowCheckedModeBanner: false,
        theme: const CupertinoThemeData(brightness: Brightness.dark),
        home: ServerConfigScreen(
          homeScreen: ServerDisconnectionListener(
            child: const HomeShell(),
          ),
        ),
      ),
    );
  }
}

class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      appBar: GlassAppBar(title: const Text('Ipon')),
      body: const Center(
        child: Text(
          'Connected!\n\n'
              '(Member 2 onward: replace HomeShell with the real '
              'navigation shell.)',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}