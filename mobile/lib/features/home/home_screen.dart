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
    final planned = w.posts.where((p) =>
      p.plannedAt != null && p.status != PostStatus.canceled).toList()
      ..sort((a,b) => a.plannedAt!.compareTo(b.plannedAt!));
    final connected = w.cloudAuthenticated;
    return PageBody(children: [
      Heading('A little direction.\nA lot of possibility.',
        w.brand['name']?.isNotEmpty == true
          ? 'Your workspace, ${w.brand['name']}.'
          : 'Start shaping your social presence.'),
      Panel(glass: true, child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.bolt_outlined),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(connected ? 'SHIFT Cloud connected' : 'Offline workspace',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(connected
                ? 'Drafts, brand settings and preferences sync securely with SHIFT. Direct scheduling currently supports connected Bluesky text accounts; other providers need setup.'
                : 'Drafts stay on this device. Sign in to sync content and connect supported accounts.'),
            ],
          )),
        ],
      )),
      if (connected) ...[
        Row(children: [
          const Expanded(child: Text('Live publishing status')),
          IconButton(onPressed: loading ? null : refresh,
            tooltip: 'Refresh publishing status',
            icon: const Icon(Icons.refresh)),
        ]),
        if (loading) const ShiftSkeleton(rows:3),
        ShiftErrorNotice(liveError,title:'Unable to refresh publishing status'),
        if (checkedAt != null)
          Text('Latest 100 direct publishing jobs • last checked locally',
            style: Theme.of(context).textTheme.bodySmall),
      ],
      const SizedBox(height: 16),
      Wrap(spacing: 8, runSpacing: 8, children: [
        _metric(context, 'Published', connected ? (publishedPosts?.toString() ?? '—') : '—',
          () => context.go('/calendar')),
        _metric(context, 'Queued / processing',
          connected ? (queuedPosts?.toString() ?? '—') : '—',
          () => context.go('/calendar')),
        _metric(context, 'Drafts',
          '${w.posts.where((p) => p.status == PostStatus.draft).length}',
          () => context.push('/drafts')),
        _metric(context, 'Reviews',
          '${w.posts.where((p) => p.status == PostStatus.pendingApproval).length}',
          () => context.push('/approvals')),
      ]),
      if (connected)
        ListTile(contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.link_outlined),
          title: Text(connectedAccounts == null ? 'Social accounts: unavailable'
            : '$connectedAccounts connected direct account(s)'),
          subtitle: const Text('Other destinations require platform authorization'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/accounts')),
      const Section('Make your next move'),
      Wrap(spacing: 8, runSpacing: 8, children: [
        FilledButton.icon(onPressed: () => context.go('/create'),
          icon: const Icon(Icons.add), label: const Text('Create content')),
        OutlinedButton.icon(onPressed: () => context.push('/ai-workspace'),
          icon: const Icon(Icons.auto_awesome), label: const Text('SHIFT AI')),
        OutlinedButton.icon(onPressed: () => context.go('/discover'),
          icon: const Icon(Icons.search), label: const Text('Research')),
        OutlinedButton(onPressed: () => context.push('/drafts'),
          child: const Text('Review drafts')),
        OutlinedButton(onPressed: () => context.push('/automation'),
          child: const Text('Automation')),
      ]),
      Section('Your content plan',
        action: TextButton(onPressed: () => context.go('/calendar'),
          child: const Text('Calendar'))),
      if (planned.isEmpty)
        const Empty('Room for your next idea',
          'Create a draft or add a planning date. Only server-queued posts publish.',
          icon: Icons.calendar_today_outlined),
      ...planned.take(3).map((p) => PostTile(post: p)),
      const Section('SHIFT recommendations'),
      const Empty('Learning starts with real results',
        'Connect accounts and sync performance before SHIFT can recommend improvements.',
        icon: Icons.auto_awesome_outlined),
      Section('Recent activity',
        action: TextButton(onPressed: () => context.push('/notifications'),
          child: const Text('View all'))),
      if (w.activity.isEmpty)
        Text(connected
          ? 'Recent local edits will appear here. Publishing jobs are in Calendar.'
          : 'Your offline activity will appear here.'),
      ...w.activity.take(4).map((a) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.history),
        title: Text(a['title']!),
        subtitle: Text(connected ? 'Current session' : 'Offline workspace'),
        onTap: () => context.push(a['route']!))),
    ]);
  }

  Widget _metric(BuildContext c, String label, String value, VoidCallback tap) =>
      SizedBox(width: (MediaQuery.sizeOf(c).width.clamp(0, 680) - 48) / 2,
        child: InkWell(borderRadius: BorderRadius.circular(20),
          onTap: tap,
          child: Panel(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: Theme.of(c).textTheme.headlineSmall),
              const SizedBox(height: 6),
              Text(label, style: const TextStyle(fontSize: 12)),
            ],
          ))));
}
