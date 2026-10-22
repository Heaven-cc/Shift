import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/state/workspace.dart';
import 'core/ui/design.dart';
import 'features/auth/auth_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/home/home_screen.dart';
import 'features/discover/discover_screen.dart';
import 'features/studio/studio_screen.dart';
import 'features/calendar/calendar_screen.dart';
import 'features/analytics/insights_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/content/post_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final workspace = ref.read(workspaceProvider);
  final router = GoRouter(initialLocation: '/', refreshListenable: workspace, redirect: (context, state) {
    final public = ['/', '/auth'].contains(state.uri.path);
    if (!workspace.entered) return public ? null : '/';
    if (!workspace.onboardingComplete) return state.uri.path == '/onboarding' ? null : '/onboarding';
    return public || state.uri.path == '/onboarding' ? '/home' : null;
  }, routes: [
    GoRoute(path: '/', builder: (_, __) => const WelcomeScreen()),
    GoRoute(path: '/auth', builder: (_, s) => AuthScreen(mode: s.uri.queryParameters['mode'] ?? 'signin')),
    GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
    StatefulShellRoute.indexedStack(builder: (_, __, shell) => ShiftShell(shell: shell), branches: [
      StatefulShellBranch(routes: [GoRoute(path: '/home', builder: (_, __) => const HomeScreen())]),
      StatefulShellBranch(routes: [GoRoute(path: '/discover', builder: (_, __) => const DiscoverScreen())]),
      StatefulShellBranch(routes: [GoRoute(path: '/create', builder: (_, __) => const StudioScreen())]),
      StatefulShellBranch(routes: [GoRoute(path: '/calendar', builder: (_, __) => const CalendarScreen())]),
      StatefulShellBranch(routes: [GoRoute(path: '/insights', builder: (_, __) => const InsightsScreen())]),
    ]),
    GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
    GoRoute(path: '/settings/:section', builder: (_, s) => SettingsScreen(section: s.pathParameters['section'])),
    GoRoute(path: '/accounts', builder: (_, __) => const AccountsScreen()),
    GoRoute(path: '/automation', builder: (_, __) => const AutomationScreen()),
    GoRoute(path: '/notifications', builder: (_, __) => const NotificationsScreen()),
    GoRoute(path: '/approvals', builder: (_, __) => const PostsScreen(approvals: true)),
    GoRoute(path: '/drafts', builder: (_, __) => const PostsScreen()),
    GoRoute(path: '/post/:id', builder: (_, s) => PostScreen(id: s.pathParameters['id']!)),
    GoRoute(path: '/compose', builder: (_, s) => Scaffold(appBar: AppBar(title: const Text('Create from source')), body: StudioScreen(sourceId: s.uri.queryParameters['source']))),
    GoRoute(path: '/edit/:id', builder: (_, s) => Scaffold(appBar: AppBar(title: const Text('Edit draft')), body: StudioScreen(postId: s.pathParameters['id']))),
    GoRoute(path: '/research/:id', builder: (_, s) => ResearchDetailScreen(id: s.pathParameters['id']!)),
  ], errorBuilder: (c, s) => Scaffold(appBar: AppBar(title: const Text('Page unavailable')), body: Empty('That page could not be opened', 'The item may have been removed.', action: FilledButton(onPressed: () => c.go('/home'), child: const Text('Go home')))));
  ref.onDispose(router.dispose);
  return router;
});

class ShiftApp extends ConsumerWidget {
  const ShiftApp({super.key});
  @override Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(title: 'SHIFT', debugShowCheckedModeBanner: false, theme: shiftTheme(Brightness.light), darkTheme: shiftTheme(Brightness.dark), themeMode: ref.watch(workspaceProvider).theme, routerConfig: ref.watch(routerProvider));
}
class ShiftShell extends ConsumerWidget {
  const ShiftShell({super.key, required this.shell});
  final StatefulNavigationShell shell;
  @override Widget build(BuildContext context, WidgetRef ref) {
    final w = ref.watch(workspaceProvider);
    const names = ['Home', 'Discover', 'Create', 'Calendar', 'Insights'];
    const icons = [Icons.grid_view_outlined, Icons.explore_outlined, Icons.add, Icons.calendar_month_outlined, Icons.insights_outlined];
    return Scaffold(appBar: AppBar(title: Row(children: [const Icon(Icons.bolt, size: 28), const SizedBox(width: 4), const Text('SHIFT', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -1)), const SizedBox(width: 12), Expanded(child: Text(w.brand['name'] ?? 'Your workspace', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)))]), actions: [IconButton(tooltip: 'Notifications and activity', onPressed: () => context.push('/notifications'), icon: const Icon(Icons.notifications_none)), IconButton(tooltip: 'Profile and settings', onPressed: () => context.push('/settings'), icon: const Icon(Icons.account_circle_outlined))]),
      body: SafeArea(child: Column(children: [if (w.storageError != null) MaterialBanner(content: Text(w.storageError!), actions: [TextButton(onPressed: w.retrySave, child: const Text('Retry save'))]), Expanded(child: shell)])),
      bottomNavigationBar: SafeArea(top: false, minimum: const EdgeInsets.fromLTRB(12, 8, 12, 12), child: ClipRRect(borderRadius: BorderRadius.circular(24), child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12), child: NavigationBar(backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: .85), height: 72, animationDuration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 180), selectedIndex: shell.currentIndex, onDestinationSelected: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex), destinations: List.generate(5, (i) => NavigationDestination(icon: Icon(icons[i]), label: names[i])))))));
  }
}
