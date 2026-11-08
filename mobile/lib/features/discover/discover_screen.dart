import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/domain/models.dart';
import '../../core/state/workspace.dart';
import '../../core/cloud/shift_cloud.dart';
import '../../core/ui/design.dart';

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});
  @override ConsumerState<DiscoverScreen> createState() => _DiscoverState();
}
class _DiscoverState extends ConsumerState<DiscoverScreen> {
  final query = TextEditingController();
  String filter = 'Saved';
  bool researching = false, loadingHistory = false;
  String? researchError;
  List<Map<String,dynamic>> results = [];
  List<Map<String,dynamic>> history = [];

  @override void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => loadHistory());
  }

  Future<void> loadHistory() async {
    final workspace = ref.read(workspaceProvider);
    if (!workspace.cloudAuthenticated || !mounted) return;
    setState(() => loadingHistory = true);
    try {
      final wid = workspace.cloudWorkspaceId!;
      final items = await ShiftCloud.client.from('shift_research_jobs')
        .select('query,status,result,completed_at').eq('workspace_id',wid)
        .order('created_at',ascending:false).limit(20);
      if (mounted) setState(() => history = List<Map<String,dynamic>>.from(items));
    } catch(e) {
      if(mounted) setState(() => researchError = 'Could not load research history: $e');
    } finally {
      if (mounted) setState(() => loadingHistory = false);
    }
  }

  Future<void> research() async {
    final prompt = query.text.trim();
    if (prompt.length < 3) { toast(context, 'Enter a topic to research.'); return; }
    if (!ref.read(workspaceProvider).cloudAuthenticated) {
      toast(context, 'Sign in to SHIFT Cloud to research online.'); return;
    }
    if (researching) return;
    setState(() { researching = true; researchError = null; });
    try {
      final response = await ShiftCloud.client.functions.invoke('shift-research', body: {
        'query': prompt,
        'request_id': 'research-${DateTime.now().microsecondsSinceEpoch}',
      });
      if (response.data is! Map) throw StateError('Research response was incomplete.');
      final data = Map<String,dynamic>.from(response.data as Map);
      if (data['error'] != null) {
        if (data['error'] == 'research_not_configured') {
          throw StateError('Live research is unavailable right now.');
        }
        throw StateError(data['message']?.toString() ?? data['error'].toString());
      }
      final raw = data['results'];
      final items = raw is List ? raw : const [];
      if (mounted) setState(() {
        results = items.map((v)=>Map<String,dynamic>.from(v as Map)).toList();
        filter = 'Results';
      });
      await loadHistory();
    } catch(e) {
      if(mounted) setState(() => researchError=e.toString().replaceFirst('Bad state: ',''));
    } finally {
      if(mounted) setState(()=>researching=false);
    }
  }

  @override void dispose() { query.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    final w = ref.watch(workspaceProvider);
    final matches = w.bookmarks.where((b) => b.topic.toLowerCase().contains(query.text.toLowerCase())).toList();
    return PageBody(children: [
      const Heading('Find your next angle.', 'Explore ideas, research a topic, and keep the sources worth returning to.'),
      Panel(glass: true, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('DISCOVER SOMETHING NEW', style: Theme.of(context).textTheme.labelSmall?.copyWith(letterSpacing: 1.2, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        TextField(controller: query, onChanged: (_) => setState(() {}), onSubmitted: (v) { if (v.trim().isNotEmpty) research(); },
          decoration: InputDecoration(labelText: 'What are you curious about?', hintText: 'Explore a topic, trend or audience…',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: IconButton(tooltip: 'Start research', onPressed: researching ? null : research, icon: const Icon(Icons.arrow_forward_rounded)))),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: Text('Research is saved to your workspace history.', style: Theme.of(context).textTheme.bodySmall)),
          TextButton.icon(onPressed: () => context.push('/ai-workspace'),
            icon: const Icon(Icons.auto_awesome_rounded, size: 17), label: const Text('SHIFT AI')),
        ]),
      ])),
      const SizedBox(height: 10),
      ServiceNotice(text: w.cloudAuthenticated
        ? 'Online research uses verified workspace settings and brand context. Search results are not independently fact-checked.'
        : 'Offline workspace • Sign in to enable live research and cloud history.'),
      if (researching) const ShiftSkeleton(rows:4),
      ShiftErrorNotice(researchError,title:'Unable to load research'),
      Wrap(spacing: 8, children: ['Saved', 'Results', 'Trending', 'For you', 'History'].map((s) => ChoiceChip(label: Text(s), selected: filter == s, onSelected: (_) => setState(() => filter = s))).toList()),
      if (w.interests.isNotEmpty) ...[
        const Section('Your interests'),
        Wrap(spacing: 8, runSpacing: 8, children: w.interests.map((s) => ActionChip(label: Text(s), onPressed: () { query.text = s; setState(() {}); })).toList()),
      ],
      if (filter == 'Saved') ...[
        Section('Saved sources', action: TextButton.icon(onPressed: () => addSource(context, ref), icon: const Icon(Icons.add, size: 18), label: const Text('Add'))),
        if (matches.isEmpty) const Empty('Keep a source close', 'Save a public source URL with your notes. SHIFT has not verified it or extracted any claims.', icon: Icons.bookmark_border),
        ...matches.map((b) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Panel(child: ListTile(contentPadding: EdgeInsets.zero, title: Text(b.topic), subtitle: Text('${Uri.tryParse(b.url)?.host ?? b.url}\nUser supplied • Unverified'), isThreeLine: true, trailing: const Icon(Icons.chevron_right), onTap: () => context.push('/research/${b.id}'))))),
      ] else if (filter == 'History') ...[
        Section('Saved online research',
          action: TextButton.icon(onPressed:loadingHistory?null:loadHistory,
            icon:const Icon(Icons.refresh),label:const Text('Refresh'))),
        if(loadingHistory)const ShiftSkeleton(rows:4),
        if(!loadingHistory&&history.isEmpty) const Empty('No research history yet',
          'Research a topic while signed in to save source discovery history online.',
          icon:Icons.history),
        ...history.map((item)=>Padding(padding:const EdgeInsets.only(bottom:8),
          child:Panel(child:ListTile(
            contentPadding:EdgeInsets.zero,title:Text(item['query']?.toString()??'Research topic'),
            subtitle:Text('Status: ${item['status']} • ${item['completed_at']??'In progress'}'),
            trailing:const Icon(Icons.chevron_right),
            onTap:(){
              final result=item['result'];
              final all=result is Map ? result['results'] : null;
              setState((){
                results=all is List?all.map((v)=>Map<String,dynamic>.from(v as Map)).toList():[];
                filter='Results';query.text=item['query']?.toString()??'';
              });
            },
          )))),
      ] else ...[
        Section(filter == 'Trending' ? 'Research emerging topics' :
          filter == 'For you' ? 'Research your brand interests' : 'Recent results'),
        if (results.isEmpty) Empty('No research results',
          'Submit a topic to search the web. A configured Brave Search key is required. Results are source leads, not verified claims.',
          icon:Icons.travel_explore,
          action:OutlinedButton(onPressed:researching?null:research,
            child:const Text('Search this topic'))),
        ...results.map((item) {
          final url=item['url']?.toString()??'';
          return Padding(padding:const EdgeInsets.only(bottom:10),
            child:Panel(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text(item['title']?.toString()??'Result',
                style:Theme.of(context).textTheme.titleMedium),
              const SizedBox(height:6),
              Text(item['publisher']?.toString()??'Source',
                style:const TextStyle(fontSize:12)),
              const SizedBox(height:8),
              Text(item['summary']?.toString()??'No summary available.'),
              const SizedBox(height:8),
              Wrap(spacing:8,runSpacing:8,children:[
                TextButton.icon(onPressed:()=>launchUrl(Uri.parse(url),
                  mode:LaunchMode.externalApplication), icon:const Icon(Icons.open_in_new),
                  label:const Text('Open source')),
                OutlinedButton(onPressed:() async {
                  final bookmark=ResearchBookmark(
                    id:DateTime.now().microsecondsSinceEpoch.toString(),
                    topic:item['title']?.toString()??'Research source',url:url,
                    notes:item['summary']?.toString()??'',
                    publisher:item['publisher']?.toString()??'',
                    savedAt:DateTime.now());
                  final ok=await ref.read(workspaceProvider).addBookmark(bookmark);
                  if(context.mounted)toast(context,ok?'Source saved in SHIFT.':'Unable to save source.');
                },child:const Text('Save source')),
              ]),
              const Text('Source discovery • Not independently verified',
                style:TextStyle(fontSize:11)),
            ])));
        }),
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
    final item = ResearchBookmark(id: DateTime.now().microsecondsSinceEpoch.toString(), topic: title.text.trim(), url: url.text.trim(), notes: notes.text.trim(), publisher: publisher.text.trim(), savedAt: DateTime.now());
    final ok = await w.addBookmark(item);
    if(ok)w.record('Source bookmarked', '/discover');
    if (context.mounted) toast(context, ok ? (w.cloudAuthenticated ? 'Source saved to SHIFT Cloud.' : 'Source saved on this device.') : 'Source could not be saved; retry.');
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
      TextButton(onPressed: () async { if (await confirm(context, 'Remove this source?', 'The local bookmark and notes will be removed.', action: 'Remove')) { final ok = await w.deleteBookmark(id); if (ok && context.mounted) context.pop(); if (!ok && context.mounted) toast(context,'Could not remove source.'); } }, child: const Text('Remove source')),
    ]));
  }
}
