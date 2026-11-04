import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/domain/models.dart';
import '../../core/state/workspace.dart';
import '../../core/cloud/shift_cloud.dart';
import '../../core/ui/design.dart';

class PostTile extends StatelessWidget {
  const PostTile({super.key, required this.post});
  final LocalPost post;
  @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Panel(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), child: ListTile(contentPadding: EdgeInsets.zero,
    leading: SizedBox(width: 44, height: 44, child: ClipRRect(borderRadius: BorderRadius.circular(10), child: post.current.imagePath == null ? const Icon(Icons.article_outlined) : Image.file(File(post.current.imagePath!), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported_outlined)))),
    title: Text(post.title, maxLines: 1, overflow: TextOverflow.ellipsis), subtitle: Text('${post.current.platform} • ${statusLabel(post.status)}\n${post.plannedAt == null ? 'Draft' : 'Planning date: ${DateFormat.MMMd().add_jm().format(post.plannedAt!)}'}'),
    isThreeLine: true, trailing: const Icon(Icons.chevron_right), onTap: () => context.push('/post/${post.id}'))));
}
class PostsScreen extends ConsumerStatefulWidget {
  const PostsScreen({super.key, this.approvals = false});
  final bool approvals;
  @override ConsumerState<PostsScreen> createState() => _PostsState();
}
class _PostsState extends ConsumerState<PostsScreen> {
  String query = '', status = 'All', platform = 'All', sort = 'Newest';
  int limit = 30;
  @override Widget build(BuildContext context) {
    final posts=ref.watch(workspaceProvider).posts.where((p)=>
      (!widget.approvals || p.status==PostStatus.pendingApproval)
      && (p.title.toLowerCase().contains(query.toLowerCase()) ||
          p.current.caption.toLowerCase().contains(query.toLowerCase()))
      && (status=='All' || statusLabel(p.status)==status)
      && (platform=='All' || p.current.platform==platform)
    ).toList()..sort((a,b) {
      if(sort=='Title A–Z')return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      if(sort=='Oldest')return a.current.createdAt.compareTo(b.current.createdAt);
      return b.current.createdAt.compareTo(a.current.createdAt);
    });
    return Scaffold(appBar: AppBar(title: Text(widget.approvals ? 'Approval inbox' : 'Draft library')), body: PageBody(children: [
      ServiceNotice(text: widget.approvals
        ? (ref.watch(workspaceProvider).cloudAuthenticated
            ? 'Cloud review inbox • Only exact approved versions may be scheduled.'
            : 'Local review queue • These decisions do not authorize server publishing.')
        : (ref.watch(workspaceProvider).cloudAuthenticated
            ? 'Synced cloud drafts • Changes require server confirmation.'
            : 'Saved on this device • No cloud sync')),
      TextField(onChanged: (v) => setState(() => query = v), decoration: const InputDecoration(labelText: 'Search content', prefixIcon: Icon(Icons.search))),
      const SizedBox(height: 12),
      if (!widget.approvals) DropdownButton<String>(value: status, items: ['All', ...PostStatus.values.map(statusLabel)].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(), onChanged: (v) => setState(() => status = v!)),
      if (!widget.approvals) Wrap(spacing:12,runSpacing:4,children:[
        DropdownButton<String>(value:platform,
          items:['All','Instagram','Facebook'].map((s)=>DropdownMenuItem(value:s,child:Text(s=='All'?'All platforms':s))).toList(),
          onChanged:(v){if(v!=null)setState(() {platform=v;limit=30;});}),
        DropdownButton<String>(value:sort,
          items:['Newest','Oldest','Title A–Z'].map((s)=>DropdownMenuItem(value:s,child:Text(s))).toList(),
          onChanged:(v){if(v!=null)setState(() {sort=v;limit=30;});}),
      ]),
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
      bool ok;
      if (w.cloudAuthenticated) {
        try {
          final wid=w.cloudWorkspaceId!;
          final rows=await ShiftCloud.client.from('shift_content_posts').select('id')
              .eq('workspace_id',wid).eq('client_id',p.id).limit(1);
          if (rows.isEmpty) throw StateError('Cloud post not found');
          final postId=rows.first['id'] as String;
          if (s == PostStatus.pendingApproval) {
            await ShiftCloud.client.rpc('shift_submit_for_review',params:{'p_post_id':postId});
          } else if (s == PostStatus.approved || s == PostStatus.draft) {
            final reviews=await ShiftCloud.client.from('shift_approval_requests')
              .select('id').eq('post_id',postId).eq('state','pending').limit(1);
            if (reviews.isEmpty) throw StateError('No pending cloud review');
            await ShiftCloud.client.rpc('shift_decide_review',params:{
              'p_review_id': reviews.first['id'], 'p_approve':s==PostStatus.approved,
              'p_comment':'Reviewed in SHIFT',
            });
          } else { throw StateError('Unsupported cloud status change'); }
          await w.openCloud();
          ok=true;
        } catch(e) {
          ok=false;
          w.cloudError='Cloud review failed: $e';
        }
      } else {
        ok = await w.changePost(p.copyWith(status: s), message);
      }
      if (context.mounted) toast(context, ok ? message : 'Review could not be saved. Please retry.');
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
        OutlinedButton(onPressed: () async {
          final duplicate=LocalPost(
            id:DateTime.now().microsecondsSinceEpoch.toString(),
            title:'Copy of ${p.title}',
            status:PostStatus.draft,
            versions:[ContentVersion(
              caption:v.caption,createdAt:DateTime.now(),imagePath:v.imagePath,
              platform:v.platform,headline:v.headline,hashtags:v.hashtags,
              metadata:v.metadata,
            )],
          );
          final ok=await w.savePost(duplicate);
          if(context.mounted){
            if(ok){toast(context,'Created a new draft.');context.push('/post/${duplicate.id}');}
            else toast(context,'Could not duplicate draft. Retry before leaving.');
          }
        },child:const Text('Duplicate as draft')),
        OutlinedButton(onPressed: () => planPost(context, ref, p), child: Text(p.plannedAt == null ? 'Add planning date' : 'Reschedule local plan')),
        OutlinedButton(onPressed: () => unavailable(context, 'Server scheduling'), child: const Text('Schedule to account')),
        OutlinedButton(onPressed: () => unavailable(context, 'Publishing'), child: const Text('Publish now')),
        OutlinedButton(onPressed: () async { await Clipboard.setData(ClipboardData(text: [v.headline, v.caption, v.hashtags].where((s) => s.isNotEmpty).join('\n\n'))); if (context.mounted) toast(context, 'Caption copied. Publish manually in your social app.'); }, child: const Text('Copy for manual export')),
      ]),
      Section(w.cloudAuthenticated ? 'Cloud review' : 'Local review'),
      const Text('Review applies to this exact content version and preview platform. Real approvals also require connected destination accounts.'),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: [
        if (p.status != PostStatus.pendingApproval && p.status != PostStatus.approved) OutlinedButton(onPressed: () => change(PostStatus.pendingApproval, 'Submitted for review'), child: const Text('Submit for local review')),
        if (p.status == PostStatus.pendingApproval) ...[
          FilledButton(onPressed: () async { if (await confirm(context, 'Approve local version ${p.versions.length}?', 'Approve this content for your local plan. This does not authorize publishing to an account.', action: 'Approve locally')) await change(PostStatus.approved, 'Version approved'); }, child: const Text('Approve locally')),
          OutlinedButton(onPressed: () => change(PostStatus.draft, 'Returned to drafts'), child: const Text('Reject / return to draft')),
        ],
        OutlinedButton(onPressed: () => unavailable(context, 'AI regeneration'), child: const Text('Regenerate')),
      ]),
      const Section('Version history'),
      ...p.versions.reversed.toList().asMap().entries.map((e) => ExpansionTile(tilePadding: EdgeInsets.zero, title: Text('Version ${p.versions.length - e.key}'), subtitle: Text(DateFormat.yMMMd().add_jm().format(e.value.createdAt)), children: [
        Padding(padding: const EdgeInsets.only(bottom: 12), child: SelectableText(e.value.caption)),
        if (e.key != 0 && p.status != PostStatus.publishing && p.status != PostStatus.published && p.status != PostStatus.scheduled) TextButton(onPressed: () async { if (await confirm(context, 'Restore this version?', 'Restore the older text as a new revision. It will need approval again.', action: 'Restore')) {
          final old = e.value;
          final restored = p.copyWith(status: PostStatus.draft,versions:[
            ...p.versions,
            ContentVersion(caption:old.caption,createdAt:DateTime.now(),
              imagePath:old.imagePath,platform:old.platform,headline:old.headline,
              hashtags:old.hashtags,metadata:old.metadata),
          ]);
          final saved=await w.changePost(restored,'Earlier version restored for review');
          if(context.mounted)toast(context,saved ? 'Restored as a new draft revision.' : 'Could not save restored revision.');
        } }, child: const Text('Restore as new draft version')),
      ])),
      const Section('Content feedback'),
      Wrap(spacing: 8, children: ['More like this', 'Not relevant', 'Change tone'].map((s) => ActionChip(label: Text(s), onPressed: () async { w.preferences['feedback:$id'] = s; final ok = await w.persist(); if (context.mounted) toast(context, ok ? 'Feedback saved locally. AI learning is not connected.' : 'Could not persist feedback.'); })).toList()),
      const SizedBox(height: 24),
      if (p.plannedAt != null) OutlinedButton(onPressed: () async { if (await confirm(context, 'Cancel local plan?', 'The draft will remain available.', action: 'Cancel plan')) await w.changePost(p.copyWith(clearPlan: true, status: PostStatus.draft), 'Local planning date removed'); }, child: const Text('Cancel local plan')),
      TextButton(onPressed: () async { if (await confirm(context, 'Delete this draft?', 'All draft versions will be deleted from the current workspace. This cannot be undone. Device image files are retained.', action: 'Delete')) { final ok=await w.removePost(id); if (ok && context.mounted) context.pop(); if (!ok && context.mounted) toast(context,'Could not delete draft.'); } }, child: const Text('Delete draft')),
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
  if(context.mounted)toast(context,ok ? 'Planning date saved. No social post has been scheduled.' : 'Unable to save planning date; please retry.');
}
