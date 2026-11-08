import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/domain/models.dart';
import '../../core/state/workspace.dart';
import '../../core/ui/design.dart';
import '../../core/social/direct_bridge.dart';
import '../content/post_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool loading = false;
  String? liveError;
  int? connectedAccounts, queuedPosts, publishedPosts;
  DateTime? checkedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => refresh());
  }

  Future<void> refresh() async {
    if (!mounted) return;
    if (!ref.read(workspaceProvider).cloudAuthenticated) {
      setState(() {
        connectedAccounts = null;
        queuedPosts = null;
        publishedPosts = null;
        liveError = null;
        checkedAt = null;
      });
      return;
    }
    setState(() { loading = true; liveError = null; });
    try {
      final results = await Future.wait([
        ShiftDirectBridge.call('accounts'),
        ShiftDirectBridge.call('jobs'),
      ]);
      final accounts = results[0]['accounts'] as List? ?? const [];
      final jobs = results[1]['jobs'] as List? ?? const [];
      if (!mounted) return;
      setState(() {
        connectedAccounts = accounts.length;
        queuedPosts = jobs.where((j) => j is Map &&
            (j['state'] == 'queued' || j['state'] == 'processing')).length;
        publishedPosts = jobs.where((j) => j is Map &&
            j['state'] == 'published').length;
        checkedAt = DateTime.now();
      });
    } catch (e) {
      if (mounted) setState(() =>
          liveError = e.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = ref.watch(workspaceProvider);
    final planned = w.posts.where((p) => p.plannedAt != null && p.status != PostStatus.canceled).toList()
      ..sort((a,b) => a.plannedAt!.compareTo(b.plannedAt!));
    final connected = w.cloudAuthenticated;
    final drafts = w.posts.where((p) => p.status == PostStatus.draft).length;
    final reviews = w.posts.where((p) => p.status == PostStatus.pendingApproval).length;
    final firstName = w.profile['name']?.trim().split(' ').first;
    return PageBody(children: [
      Padding(padding: const EdgeInsets.only(top: 4, bottom: 18), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('YOUR WORKSPACE', style: Theme.of(context).textTheme.labelSmall?.copyWith(
            letterSpacing: 1.5, fontWeight: FontWeight.w800)),
          const SizedBox(height: 7),
          Text('Good to see you' + (firstName != null && firstName.isNotEmpty ? ', ' + firstName : '') + '.',
            style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 5),
          Text(w.brand['name']?.isNotEmpty == true ? 'Building momentum for ' + w.brand['name']! + '.' : 'What would you like to move forward today?',
            style: Theme.of(context).textTheme.bodyMedium),
        ],
      )),
      Panel(glass: true, padding: const EdgeInsets.all(15), child: Row(children: [
        Container(width: 42, height: 42, decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: .12), borderRadius: BorderRadius.circular(13)),
          child: Icon(connected ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
            color: Theme.of(context).colorScheme.primary)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(connected ? 'SHIFT Cloud connected' : 'Your local workspace',
            style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 3),
          Text(connected ? 'Your signed-in workspace is syncing supported data.' :
            'Your drafts stay on this device until you sign in and sync.',
            style: Theme.of(context).textTheme.bodySmall),
        ])),
        if (!connected) IconButton(tooltip: 'Sign in', onPressed: () => context.push('/auth'),
          icon: const Icon(Icons.arrow_forward_rounded)),
      ])),
      const Section('At a glance'),
      GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.75, children: [
          _metric(context, 'Drafts', '$drafts', () => context.push('/drafts')),
          _metric(context, 'Needs review', '$reviews', () => context.push('/approvals')),
          _metric(context, 'Published', connected ? (publishedPosts?.toString() ?? '—') : '—', () => context.go('/calendar')),
          _metric(context, 'In queue', connected ? (queuedPosts?.toString() ?? '—') : '—', () => context.go('/calendar')),
        ]),
      if (connected) ...[
        const Section('Publishing activity'),
        Row(children: [
          Expanded(child: Text('Live status from your connected workspace', style: Theme.of(context).textTheme.bodySmall)),
          IconButton(onPressed: loading ? null : refresh, tooltip: 'Refresh status',
            icon: loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.refresh_rounded)),
        ]),
        ShiftErrorNotice(liveError, title: 'Unable to refresh publishing status'),
        if (checkedAt != null) Text('Last checked ' + checkedAt!.toLocal().toString(), style: Theme.of(context).textTheme.bodySmall),
        if (connectedAccounts != null) ListTile(contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.link_rounded), title: Text('$connectedAccounts connected account(s)'),
          subtitle: const Text('Manage your publishing destinations'),
          trailing: const Icon(Icons.chevron_right), onTap: () => context.push('/accounts')),
      ],
      const Section('Create something'),
      Row(children: [
        Expanded(child: FilledButton.icon(onPressed: () => context.go('/create'),
          icon: const Icon(Icons.add_rounded), label: const Text('Create post'))),
        const SizedBox(width: 10),
        Expanded(child: OutlinedButton.icon(onPressed: () => context.push('/ai-workspace'),
          icon: const Icon(Icons.auto_awesome_rounded), label: const Text('SHIFT AI'))),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: OutlinedButton.icon(onPressed: () => context.go('/discover'),
          icon: const Icon(Icons.travel_explore_rounded), label: const Text('Research'))),
        const SizedBox(width: 10),
        Expanded(child: OutlinedButton.icon(onPressed: () => context.push('/drafts'),
          icon: const Icon(Icons.folder_open_rounded), label: const Text('Draft library'))),
      ]),
      const Section('Your content plan', action: TextButton(onPressed: () => context.go('/calendar'),
        child: const Text('Open calendar'))),
      if (planned.isEmpty) const Empty('Your next post starts here',
        'Create a draft or add a planning date. A local plan is not a confirmed publishing schedule.',
        icon: Icons.calendar_today_outlined),
      ...planned.take(3).map((p) => Padding(padding: const EdgeInsets.only(bottom: 9), child: PostTile(post: p))),
      const Section('Recent activity', action: TextButton(onPressed: () => context.push('/notifications'),
        child: const Text('View all'))),
      if (w.activity.isEmpty) Text('Your recent workspace changes will appear here.',
        style: Theme.of(context).textTheme.bodyMedium),
      ...w.activity.take(4).map((a) => ListTile(contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.history_rounded), title: Text(a['title']!),
        subtitle: Text(connected ? 'Current session' : 'On this device'),
        onTap: () => context.push(a['route']!))),
    ]);
  }

  Widget _metric(BuildContext c, String label, String value, VoidCallback tap) =>
      InkWell(
        borderRadius: BorderRadius.circular(17),
        onTap: tap,
        child: Panel(padding: const EdgeInsets.all(14), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(value, style: Theme.of(c).textTheme.headlineSmall),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: Theme.of(c).textTheme.bodySmall),
          ],
        )),
      );
}
