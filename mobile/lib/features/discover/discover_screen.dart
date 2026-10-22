import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/domain/models.dart';
import '../../core/state/workspace.dart';
import '../../core/ui/design.dart';

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});
  @override ConsumerState<DiscoverScreen> createState() => _DiscoverState();
}
class _DiscoverState extends ConsumerState<DiscoverScreen> {
  final query = TextEditingController();
  String filter = 'Saved';
  @override void dispose() { query.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    final w = ref.watch(workspaceProvider);
    final matches = w.bookmarks.where((b) => b.topic.toLowerCase().contains(query.text.toLowerCase())).toList();
    return PageBody(children: [
      const Heading('Follow your curiosity.', 'Find an angle worth sharing. Keep the sources that matter.'),
      TextField(controller: query, onChanged: (_) => setState(() {}), onSubmitted: (v) { if (v.trim().isNotEmpty) unavailable(context, 'Research'); }, decoration: InputDecoration(labelText: 'Research a topic', hintText: 'What would you like to explore?', prefixIcon: const Icon(Icons.search), suffixIcon: IconButton(tooltip: 'Start research', onPressed: () => query.text.trim().isEmpty ? toast(context, 'Enter a topic first.') : unavailable(context, 'Research'), icon: const Icon(Icons.arrow_forward)))),
      const SizedBox(height: 16), const ServiceNotice(text: 'Live research is unavailable. Saved sources are user supplied and unverified.'),
      Wrap(spacing: 8, children: ['Saved', 'Trending', 'For you', 'History'].map((s) => ChoiceChip(label: Text(s), selected: filter == s, onSelected: (_) => setState(() => filter = s))).toList()),
      if (w.interests.isNotEmpty) ...[
        const Section('Your interests'),
        Wrap(spacing: 8, runSpacing: 8, children: w.interests.map((s) => ActionChip(label: Text(s), onPressed: () { query.text = s; setState(() {}); })).toList()),
      ],
      if (filter == 'Saved') ...[
        Section('Saved sources', action: TextButton.icon(onPressed: () => addSource(context, ref), icon: const Icon(Icons.add, size: 18), label: const Text('Add'))),
        if (matches.isEmpty) const Empty('Keep a source close', 'Save a public source URL with your notes. SHIFT has not verified it or extracted any claims.', icon: Icons.bookmark_border),
        ...matches.map((b) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Panel(child: ListTile(contentPadding: EdgeInsets.zero, title: Text(b.topic), subtitle: Text('${Uri.tryParse(b.url)?.host ?? b.url}\nUser supplied • Unverified'), isThreeLine: true, trailing: const Icon(Icons.chevron_right), onTap: () => context.push('/research/${b.id}'))))),
      ] else ...[
        Section(filter == 'Trending' ? 'Emerging topics' : filter == 'For you' ? 'Recommended angles' : 'Research history'),
        Empty('No live research yet', 'Research results, provenance, retrieval dates and verification status will appear after the cloud research service is connected.', icon: Icons.travel_explore, action: OutlinedButton(onPressed: () => unavailable(context, 'Research'), child: const Text('Check research availability'))),
      ],
    ]);
  }
}
Future<void> addSource(BuildContext context, WidgetRef ref) async {
  final title = TextEditingController(), url = TextEditingController(), notes = TextEditingController(), publisher = TextEditingController();
  final form = GlobalKey<FormState>();
  final result = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: const Text('Save a source'), content: SizedBox(width: 400, child: SingleChildScrollView(child: Form(key: form, child: Column(mainAxisSize: MainAxisSize.min, children: [
    Field('Topic / title', controller: title, required: true),
    TextFormField(controller: url, keyboardType: TextInputType.url, decoration: const InputDecoration(labelText: 'Public source URL'), validator: (v) { final u = Uri.tryParse(v?.trim() ?? ''); return u == null || u.scheme != 'https' || u.host.isEmpty ? 'Enter a complete HTTPS source URL' : null; }),
    const SizedBox(height: 16), Field('Publisher (optional)', controller: publisher),
    Field('Your notes', controller: notes, lines: 3),
    const Text('Saving a URL does not verify the source or its claims.', style: TextStyle(fontSize: 12)),
  ])))), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')), FilledButton(onPressed: () { if (form.currentState!.validate()) Navigator.pop(c, true); }, child: const Text('Save source'))]));
  if (result == true) {
    final w = ref.read(workspaceProvider);
    w.bookmarks.insert(0, ResearchBookmark(id: DateTime.now().microsecondsSinceEpoch.toString(), topic: title.text.trim(), url: url.text.trim(), notes: notes.text.trim(), publisher: publisher.text.trim(), savedAt: DateTime.now()));
    w.record('Source bookmarked', '/discover');
    final ok = await w.persist();
    if (context.mounted) toast(context, ok ? 'Source saved on this device.' : 'Source is in memory only. Storage failed.');
  }
  // Dialog route teardown finishes before controllers are disposed.
  await Future<void>.delayed(const Duration(milliseconds: 300));
  title.dispose(); url.dispose(); notes.dispose(); publisher.dispose();
}
class ResearchDetailScreen extends ConsumerWidget {
  const ResearchDetailScreen({super.key, required this.id});
  final String id;
  @override Widget build(BuildContext context, WidgetRef ref) {
    final w = ref.watch(workspaceProvider);
    final sources = w.bookmarks.where((b) => b.id == id);
    if (sources.isEmpty) return Scaffold(appBar: AppBar(), body: const Empty('Source not found', 'It may have been removed.'));
    final b = sources.first;
    return Scaffold(appBar: AppBar(title: const Text('Source brief')), body: PageBody(children: [
      Heading(b.topic, 'User supplied source • Unverified'),
      Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SelectableText(b.url), const SizedBox(height: 12),
        Text('Publisher: ${b.publisher.isEmpty ? 'Not supplied' : b.publisher}'),
        const Text('Publication date: not supplied\nRetrieved by SHIFT: not retrieved'),
        Text('Saved: ${DateFormat.yMMMd().add_jm().format(b.savedAt)}'),
        const SizedBox(height: 12), OutlinedButton.icon(onPressed: () async { if (!await launchUrl(Uri.parse(b.url), mode: LaunchMode.externalApplication) && context.mounted) toast(context, 'Source could not be opened.'); }, icon: const Icon(Icons.open_in_new), label: const Text('Open source')),
      ])),
      const Section('Your notes'), SelectableText(b.notes.isEmpty ? 'No notes yet.' : b.notes),
      const Section('Research analysis'),
      const Empty('No verified brief available', 'Main findings, audience relevance, talking points, hooks, risks and content opportunities require source validation and AI research. No claims have been generated.'),
      const SizedBox(height: 20),
      FilledButton(onPressed: () => context.push('/compose?source=$id'), child: const Text('Create a post from your notes')),
      const SizedBox(height: 8), OutlinedButton(onPressed: () => unavailable(context, 'AI research brief'), child: const Text('Generate research brief')),
      TextButton(onPressed: () async { if (await confirm(context, 'Remove this source?', 'The local bookmark and notes will be removed.', action: 'Remove')) { w.bookmarks.removeWhere((s) => s.id == id); await w.persist(); if (context.mounted) context.pop(); } }, child: const Text('Remove source')),
    ]));
  }
}
