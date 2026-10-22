import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/domain/models.dart';
import '../../core/state/workspace.dart';
import '../../core/ui/design.dart';
import '../content/post_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});
  @override Widget build(BuildContext context, WidgetRef ref) {
    final w = ref.watch(workspaceProvider);
    final planned = w.posts.where((p) => p.plannedAt != null && p.status != PostStatus.canceled).toList()..sort((a, b) => a.plannedAt!.compareTo(b.plannedAt!));
    return PageBody(children: [
      Heading('A little direction.\nA lot of possibility.', w.brand['name']?.isNotEmpty == true ? 'Your workspace, ${w.brand['name']}.' : 'Start shaping your social presence.'),
      Panel(glass: true, child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.bolt_outlined), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Waiting for connection', style: Theme.of(context).textTheme.titleMedium), const SizedBox(height: 6), const Text('Research, AI creation and cloud publishing are inactive. Your local drafts are ready to work on.')]))])),
      const SizedBox(height: 16),
      Wrap(spacing: 8, runSpacing: 8, children: [
        _metric(context, 'Published', '—', () => context.go('/insights')),
        _metric(context, 'Server schedules', '—', () => context.go('/calendar')),
        _metric(context, 'Local drafts', '${w.posts.where((p) => p.status == PostStatus.draft).length}', () => context.push('/drafts')),
        _metric(context, 'Local reviews', '${w.posts.where((p) => p.status == PostStatus.pendingApproval).length}', () => context.push('/approvals')),
      ]),
      const Section('Make your next move'),
      Wrap(spacing: 8, runSpacing: 8, children: [
        FilledButton.icon(onPressed: () => context.go('/create'), icon: const Icon(Icons.add), label: const Text('Create content')),
        OutlinedButton.icon(onPressed: () => context.go('/discover'), icon: const Icon(Icons.search), label: const Text('Research')),
        OutlinedButton(onPressed: () => context.push('/drafts'), child: const Text('Review drafts')),
        OutlinedButton(onPressed: () => context.push('/automation'), child: const Text('Automation')),
      ]),
      Section('Your content plan', action: TextButton(onPressed: () => context.go('/calendar'), child: const Text('Calendar'))),
      if (planned.isEmpty) const Empty('Room for your next idea', 'Add a planning date to a draft. It remains local until the server confirms a schedule.', icon: Icons.calendar_today_outlined),
      ...planned.take(3).map((p) => PostTile(post: p)),
      const Section('SHIFT recommendations'),
      const Empty('Learning starts with real results', 'Connect accounts and sync performance before SHIFT can make personalized recommendations.', icon: Icons.auto_awesome_outlined),
      Section('Recent activity', action: TextButton(onPressed: () => context.push('/notifications'), child: const Text('View all'))),
      if (w.activity.isEmpty) const Text('Your local workspace activity will appear here.'),
      ...w.activity.take(4).map((a) => ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.history), title: Text(a['title']!), subtitle: const Text('Local workspace'), onTap: () => context.push(a['route']!))),
    ]);
  }
  Widget _metric(BuildContext c, String label, String value, VoidCallback tap) => SizedBox(width: (MediaQuery.sizeOf(c).width.clamp(0, 680) - 48) / 2, child: InkWell(borderRadius: BorderRadius.circular(20), onTap: tap, child: Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: Theme.of(c).textTheme.headlineSmall), const SizedBox(height: 6), Text(label, style: const TextStyle(fontSize: 12))]))));
}
