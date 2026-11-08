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
import 'features/ai/ai_workspace_screen.dart';
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
    GoRoute(path: '/ai-workspace', builder: (_, __) => const AiWorkspaceScreen()),
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
    const icons = [Icons.home_rounded, Icons.explore_outlined, Icons.add_rounded, Icons.calendar_month_outlined, Icons.insights_outlined];
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 62,
        titleSpacing: 18,
        title: Row(children: [
          Container(width: 34, height: 34, decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(11)),
            child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 23)),
          const SizedBox(width: 10),
          const Text('SHIFT', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -.8, fontSize: 19)),
          const SizedBox(width: 10),
          Flexible(child: Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20)),
            child: Text(w.brand['name']?.isNotEmpty == true ? w.brand['name']! : 'Workspace',
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall))),
        ]),
        actions: [
          IconButton(tooltip: 'Notifications and activity', onPressed: () => context.push('/notifications'),
            icon: const Icon(Icons.notifications_none_rounded)),
          IconButton(tooltip: 'Profile and settings', onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.account_circle_outlined)),
          const SizedBox(width: 6),
        ]),
      body: SafeArea(child: Column(children: [
        ShiftErrorNotice(w.storageError, title: 'Changes could not be saved', onRetry: () { w.retrySave(); }),
        Expanded(child: shell),
      ])),
      bottomNavigationBar: SafeArea(top: false, minimum: const EdgeInsets.fromLTRB(14, 5, 14, 10),
        child: ClipRRect(borderRadius: BorderRadius.circular(23),
          child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface.withValues(alpha: dark ? .9 : .94),
                borderRadius: BorderRadius.circular(23),
                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: .8)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: dark ? .25 : .07), blurRadius: 24, offset: const Offset(0, 8))]),
              child: NavigationBar(
                backgroundColor: Colors.transparent, elevation: 0, shadowColor: Colors.transparent,
                indicatorColor: Theme.of(context).colorScheme.primary.withValues(alpha: .14),
                height: 66, labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                animationDuration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 220),
                selectedIndex: shell.currentIndex,
                onDestinationSelected: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
                destinations: List.generate(5, (i) => NavigationDestination(
                  icon: Icon(icons[i], size: 21), selectedIcon: Icon(icons[i], size: 22),
                  label: names[i])),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
