import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'core/providers/auth_provider.dart';
import 'core/theme/app_theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/dashboard/dashboard_screen.dart' show DashboardScreen, kAppBarClearance;
import 'screens/expenses/expenses_list_screen.dart';
import 'screens/groups/groups_list_screen.dart';
import 'screens/plans/plans_list_screen.dart';
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
          homeScreen: const ServerDisconnectionListener(
            child: AuthGate(),
          ),
        ),
      ),
    );
  }
}
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);

    switch (auth.status) {
      case AuthStatus.unknown:
        return const GlassScaffold(
          body: Center(child: GlassProgressIndicator.circular(size: 28)),
        );
      case AuthStatus.unauthenticated:
        return const LoginScreen();
      case AuthStatus.authenticated:
        return const HomeShell();
    }
  }
}
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _selectedIndex = 0;
  static const List<Widget> _pages = [
    DashboardScreen(),
    PlansListScreen(),
    ExpensesListScreen(),
    GroupsListScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      statusBarStyle: GlassStatusBarStyle.auto,
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomBar: GlassTabBar.bottom(
        selectedIndex: _selectedIndex,
        onTabSelected: (index) => setState(() => _selectedIndex = index),
        tabs: const [
          GlassTab(
            icon: Icon(CupertinoIcons.chart_bar),
            activeIcon: Icon(CupertinoIcons.chart_bar_fill),
            label: 'Summary',
          ),
          GlassTab(
            icon: Icon(CupertinoIcons.chart_pie),
            activeIcon: Icon(CupertinoIcons.chart_pie_fill),
            label: 'Plans',
          ),
          GlassTab(
            icon: Icon(CupertinoIcons.square_list),
            activeIcon: Icon(CupertinoIcons.square_list_fill),
            label: 'Expenses',
          ),
          GlassTab(
            icon: Icon(CupertinoIcons.person_2),
            activeIcon: Icon(CupertinoIcons.person_2_fill),
            label: 'Groups',
          ),
          GlassTab(
            icon: Icon(CupertinoIcons.person_crop_circle),
            activeIcon: Icon(CupertinoIcons.person_crop_circle_fill),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return GlassScaffold(
      statusBarStyle: GlassStatusBarStyle.auto,
      appBar: GlassAppBar(title: const Text('Profile')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
          children: [
            const SizedBox(height: kAppBarClearance),
            Container(
              width: 88,
              height: 88,
              alignment: Alignment.center,
              margin: const EdgeInsets.symmetric(horizontal: 0),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: AppColors.heroGradient,
                ),
              ),
              child: const Icon(
                CupertinoIcons.person_crop_circle_fill,
                size: 56,
                color: CupertinoColors.black,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              user?.fullName ?? 'Signed in',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              user?.email ?? '',
              textAlign: TextAlign.center,
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: 28),
            GlassGroupedSection(
              children: [
                GlassListTile(
                  leading: const Icon(
                    CupertinoIcons.square_arrow_right,
                    color: AppColors.statusNegative,
                  ),
                  title: const Text('Sign Out'),
                  onTap: () => _confirmSignOut(context, ref),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmSignOut(BuildContext context, WidgetRef ref) {
    GlassDialog.show<void>(
      context: context,
      title: 'Sign Out',
      message: 'You will need to sign in again to reach your plans.',
      barrierDismissible: true,
      actions: [
        GlassDialogAction(
          label: 'Sign Out',
          isDestructive: true,
          onPressed: () {
            Navigator.of(context).pop();
            ref.read(authProvider.notifier).logout();
          },
        ),
        GlassDialogAction(
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}