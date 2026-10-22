import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/domain/models.dart';
import '../../core/state/workspace.dart';
import '../../core/ui/design.dart';

class PostTile extends StatelessWidget {
  const PostTile({super.key, required this.post});
  final LocalPost post;
  @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Panel(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), child: ListTile(contentPadding: EdgeInsets.zero,
    leading: SizedBox(width: 44, height: 44, child: ClipRRect(borderRadius: BorderRadius.circular(10), child: post.current.imagePath == null ? const Icon(Icons.article_outlined) : Image.file(File(post.current.imagePath!), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported_outlined)))),
    title: Text(post.title, maxLines: 1, overflow: TextOverflow.ellipsis), subtitle: Text('${post.current.platform} • ${statusLabel(post.status)}\n${post.plannedAt == null ? 'Local draft' : 'Local plan: ${DateFormat.MMMd().add_jm().format(post.plannedAt!)}'}'),
    isThreeLine: true, trailing: const Icon(Icons.chevron_right), onTap: () => context.push('/post/${post.id}'))));
}
class PostsScreen extends ConsumerStatefulWidget {
  const PostsScreen({super.key, this.approvals = false});
  final bool approvals;
  @override ConsumerState<PostsScreen> createState() => _PostsState();
}
class _PostsState extends ConsumerState<PostsScreen> {
  String query = '', status = 'All';
  int limit = 30;
  @override Widget build(BuildContext context) {
    final posts = ref.watch(workspaceProvider).posts.where((p) => (!widget.approvals || p.status == PostStatus.pendingApproval) && p.title.toLowerCase().contains(query.toLowerCase()) && (status == 'All' || statusLabel(p.status) == status)).toList();
    return Scaffold(appBar: AppBar(title: Text(widget.approvals ? 'Approval inbox' : 'Draft library')), body: PageBody(children: [
      ServiceNotice(text: widget.approvals ? 'Local review queue • These decisions do not authorize server publishing.' : 'Saved on this device • No cloud sync'),
      TextField(onChanged: (v) => setState(() => query = v), decoration: const InputDecoration(labelText: 'Search content', prefixIcon: Icon(Icons.search))),
      const SizedBox(height: 12),
      if (!widget.approvals) DropdownButton<String>(value: status, items: ['All', ...PostStatus.values.map(statusLabel)].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(), onChanged: (v) => setState(() => status = v!)),
      if (posts.isEmpty) Empty(widget.approvals ? 'All caught up' : 'Start with an idea', widget.approvals ? 'No local drafts are waiting for your review.' : 'Create a post, then save or plan it.', action: FilledButton(onPressed: () => context.go('/create'), child: const Text('Create a post'))),
      ...posts.take(limit).map((p) => PostTile(post: p)),
      if (posts.length > limit) OutlinedButton(onPressed: () => setState(() => limit += 30), child: const Text('Load more drafts')),
    ]));
  }
}
class PostScreen extends ConsumerWidget {
  const PostScreen({super.key, required this.id});
  final String id;
  @override Widget build(BuildContext context, WidgetRef ref) {
    final w = ref.watch(workspaceProvider);
    final matches = w.posts.where((p) => p.id == id);
    if (matches.isEmpty) return Scaffold(appBar: AppBar(), body: const Empty('Draft not found', 'This local draft may have been deleted.'));
    final p = matches.first, v = p.current;
    Future<void> change(PostStatus s, String message) async {
      final ok = await w.changePost(p.copyWith(status: s), message);
      if (context.mounted) toast(context, ok ? message : 'Device storage failed. Changes are in memory.');
    }
    return Scaffold(appBar: AppBar(title: const Text('Post details'), actions: [IconButton(tooltip: 'Edit draft', onPressed: () => context.push('/edit/$id'), icon: const Icon(Icons.edit_outlined))]), body: PageBody(children: [
      Heading(p.title, '${v.platform} • ${statusLabel(p.status)} • Version ${p.versions.length}'),
      const ServiceNotice(text: 'Local content only • No social account selected or publication confirmed'),
      Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('PLATFORM PREVIEW', style: TextStyle(fontSize: 10, letterSpacing: 2)),
        const SizedBox(height: 12), Text(w.brand['name'] ?? 'Your brand', style: Theme.of(context).textTheme.titleMedium),
        if (v.imagePath != null) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Image.file(File(v.imagePath!), width: double.infinity, height: 250, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Empty('Image unavailable', 'Replace it in the editor.'))),
        if (v.headline.isNotEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(v.headline, style: Theme.of(context).textTheme.titleMedium)),
        SelectableText(v.caption), if (v.hashtags.isNotEmpty) SelectableText(v.hashtags),
      ])),
      const Section('Plan & destination'),
      Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Destination preview: ${v.platform}\nConnected account: none\nPublishing mode: ${w.preferences['mode'] ?? 'Approval required'}'),
        const SizedBox(height: 8),
        Text(p.plannedAt == null ? 'No local planning date' : 'Local planning date: ${DateFormat.yMMMd().add_jm().format(p.plannedAt!)}\nDevice timezone: ${p.timezone}\nUTC: ${p.plannedAt!.toUtc().toIso8601String()}'),
        const SizedBox(height: 8), const Text('A planning date is a reminder in this app. It is not a server publishing schedule.', style: TextStyle(fontSize: 12)),
      ])),
      const SizedBox(height: 16),
      Wrap(spacing: 8, runSpacing: 8, children: [
        FilledButton(onPressed: () => context.push('/edit/$id'), child: const Text('Edit draft')),
        OutlinedButton(onPressed: () => planPost(context, ref, p), child: Text(p.plannedAt == null ? 'Add planning date' : 'Reschedule local plan')),
        OutlinedButton(onPressed: () => unavailable(context, 'Server scheduling'), child: const Text('Schedule to account')),
        OutlinedButton(onPressed: () => unavailable(context, 'Publishing'), child: const Text('Publish now')),
        OutlinedButton(onPressed: () async { await Clipboard.setData(ClipboardData(text: [v.headline, v.caption, v.hashtags].where((s) => s.isNotEmpty).join('\n\n'))); if (context.mounted) toast(context, 'Caption copied. Publish manually in your social app.'); }, child: const Text('Copy for manual export')),
      ]),
      const Section('Local review'),
      const Text('Review applies to this exact content version and preview platform. Real approvals also require connected destination accounts.'),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: [
        if (p.status != PostStatus.pendingApproval && p.status != PostStatus.approved) OutlinedButton(onPressed: () => change(PostStatus.pendingApproval, 'Added to local review queue'), child: const Text('Submit for local review')),
        if (p.status == PostStatus.pendingApproval) ...[
          FilledButton(onPressed: () async { if (await confirm(context, 'Approve local version ${p.versions.length}?', 'Approve this content for your local plan. This does not authorize publishing to an account.', action: 'Approve locally')) await change(PostStatus.approved, 'Local version approved'); }, child: const Text('Approve locally')),
          OutlinedButton(onPressed: () => change(PostStatus.draft, 'Returned to drafts'), child: const Text('Reject / return to draft')),
        ],
        OutlinedButton(onPressed: () => unavailable(context, 'AI regeneration'), child: const Text('Regenerate')),
      ]),
      const Section('Version history'),
      ...p.versions.reversed.toList().asMap().entries.map((e) => ExpansionTile(tilePadding: EdgeInsets.zero, title: Text('Version ${p.versions.length - e.key}'), subtitle: Text(DateFormat.yMMMd().add_jm().format(e.value.createdAt)), children: [
        Padding(padding: const EdgeInsets.only(bottom: 12), child: SelectableText(e.value.caption)),
        if (e.key != 0) TextButton(onPressed: () async { if (await confirm(context, 'Restore this version?', 'A new draft version will be created. Previous reviews will be cleared.', action: 'Restore')) { final old = e.value; await w.changePost(p.copyWith(status: PostStatus.draft, versions: [...p.versions, ContentVersion(caption: old.caption, createdAt: DateTime.now(), imagePath: old.imagePath, platform: old.platform, headline: old.headline, hashtags: old.hashtags, metadata: old.metadata)]), 'Earlier version restored for review'); } }, child: const Text('Restore as new draft version')),
      ])),
      const Section('Content feedback'),
      Wrap(spacing: 8, children: ['More like this', 'Not relevant', 'Change tone'].map((s) => ActionChip(label: Text(s), onPressed: () async { w.preferences['feedback:$id'] = s; final ok = await w.persist(); if (context.mounted) toast(context, ok ? 'Feedback saved locally. AI learning is not connected.' : 'Could not persist feedback.'); })).toList()),
      const SizedBox(height: 24),
      if (p.plannedAt != null) OutlinedButton(onPressed: () async { if (await confirm(context, 'Cancel local plan?', 'The draft will remain available.', action: 'Cancel plan')) await w.changePost(p.copyWith(clearPlan: true, status: PostStatus.draft), 'Local planning date removed'); }, child: const Text('Cancel local plan')),
      TextButton(onPressed: () async { if (await confirm(context, 'Delete this draft?', 'All local text versions will be removed. Uploaded files are retained until local data is cleared.', action: 'Delete')) { await w.removePost(id); if (context.mounted) context.pop(); } }, child: const Text('Delete draft')),
    ]));
  }
}
Future<void> planPost(BuildContext context, WidgetRef ref, LocalPost p) async {
  final now = DateTime.now();
  final initial = p.plannedAt != null && p.plannedAt!.isAfter(now) ? p.plannedAt! : now.add(const Duration(days: 1));
  final date = await showDatePicker(context: context, initialDate: initial, firstDate: DateUtils.dateOnly(now), lastDate: now.add(const Duration(days: 365 * 3)));
  if (date == null || !context.mounted) return;
  final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial));
  if (time == null || !context.mounted) return;
  final at = DateTime(date.year, date.month, date.day, time.hour, time.minute);
  if (!at.isAfter(now)) { toast(context, 'Choose a future planning time.'); return; }
  final ok = await ref.read(workspaceProvider).changePost(p.copyWith(plannedAt: at, timezone: '${at.timeZoneName} (UTC${at.timeZoneOffset.isNegative ? '' : '+'}${at.timeZoneOffset.inMinutes / 60})'), 'Local content plan updated');
  if (context.mounted) toast(context, ok ? 'Planning date saved locally. No server schedule created.' : 'Planning date is in memory only. Storage failed.');
}
