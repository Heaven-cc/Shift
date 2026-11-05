import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/domain/models.dart';
import '../../core/state/workspace.dart';
import '../../core/cloud/shift_cloud.dart';
import '../../core/ui/design.dart';
import '../../core/social/social_platforms.dart';

class StudioScreen extends ConsumerStatefulWidget {
  const StudioScreen({super.key, this.postId, this.sourceId});
  final String? postId, sourceId;
  @override ConsumerState<StudioScreen> createState() => _StudioState();
}
class _StudioState extends ConsumerState<StudioScreen> with WidgetsBindingObserver {
  final form = GlobalKey<FormState>();
  final title = TextEditingController(), instruction = TextEditingController(), caption = TextEditingController(), audience = TextEditingController(), hook = TextEditingController(), tags = TextEditingController(), cta = TextEditingController();
  late final Workspace workspace;
  String platform = 'Instagram', goal = 'Educate', tone = 'Conversational', language = 'English', length = 'Medium', output = 'Text + image';
  String? imagePath;
  late String id;
  List<ContentVersion> versions = [];
  bool saving = false, generating = false, dirty = false, missing = false;
  String saveLabel = 'Not saved yet';
  Timer? debounce;
  int revision = 0;
  @override void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    workspace = ref.read(workspaceProvider);
    id = widget.postId ?? DateTime.now().microsecondsSinceEpoch.toString();
    final matches = workspace.posts.where((p) => p.id == id);
    if (widget.postId != null && matches.isEmpty) missing = true;
    if (matches.isNotEmpty) {
      final p = matches.first, v = p.current;
      title.text = p.title; caption.text = v.caption; hook.text = v.headline; tags.text = v.hashtags; platform = v.platform; imagePath = v.imagePath; versions = [...p.versions]; saveLabel = workspace.cloudAuthenticated ? 'Saved in SHIFT Cloud' : 'Saved on this device';
      instruction.text = v.metadata['instruction'] ?? ''; goal = v.metadata['goal'] ?? goal; tone = v.metadata['tone'] ?? tone; language = v.metadata['language'] ?? language; length = v.metadata['length'] ?? length; output = v.metadata['output'] ?? output; audience.text = v.metadata['audience'] ?? ''; cta.text = v.metadata['cta'] ?? '';
    }
    if (widget.sourceId != null) {
      final sources = workspace.bookmarks.where((b) => b.id == widget.sourceId);
      if (sources.isNotEmpty) { final b = sources.first; title.text = b.topic; instruction.text = 'Source: ${b.url}\nUnverified user notes: ${b.notes}'; }
    }
    if (matches.isEmpty) language = workspace.brand['language']?.isNotEmpty == true ? workspace.brand['language']! : 'English';
    for (final c in [title, caption, hook, tags, instruction, audience, cta]) { c.addListener(changed); }
  }
  void changed() {
    if (!mounted) return;
    setState(() { revision++; dirty = true; saveLabel = 'Unsaved changes'; });
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 900), () { if (caption.text.trim().isNotEmpty) save(quiet: true); });
  }
  ContentVersion currentVersion() => ContentVersion(caption: caption.text.trim(), createdAt: DateTime.now(), imagePath: imagePath, platform: platform, headline: hook.text.trim(), hashtags: tags.text.trim(), metadata: {'instruction': instruction.text.trim(), 'goal': goal, 'tone': tone, 'language': language, 'length': length, 'output': output, 'audience': audience.text.trim(), 'cta': cta.text.trim(), if (widget.sourceId != null) 'sourceId': widget.sourceId!});
  Future<void> save({bool quiet = false}) async {
    if (saving || caption.text.trim().isEmpty) { if (!quiet && mounted) toast(context, 'Write a caption to save your draft.'); return; }
    debounce?.cancel();
    if (mounted) setState(() => saving = true);
    final savedRevision = revision;
    final v = currentVersion();
    final latest = workspace.posts.where((p) => p.id == id);
    if (latest.isNotEmpty && latest.first.versions.length > versions.length) versions = [...latest.first.versions];
    final changedContent = versions.isEmpty || versions.last.caption != v.caption || versions.last.platform != v.platform || versions.last.imagePath != v.imagePath || versions.last.headline != v.headline || versions.last.hashtags != v.hashtags || versions.last.metadata.toString() != v.metadata.toString();
    if (changedContent) versions.add(v);
    final matches = workspace.posts.where((p) => p.id == id);
    final old = matches.isEmpty ? null : matches.first;
    final wasReviewed = old != null && [PostStatus.approved, PostStatus.pendingApproval].contains(old.status);
    final post = LocalPost(id: id, title: title.text.trim().isEmpty ? 'Untitled post' : title.text.trim(), versions: [...versions], status: changedContent && wasReviewed ? PostStatus.draft : old?.status ?? PostStatus.draft, plannedAt: old?.plannedAt, timezone: old?.timezone ?? '');
    final ok = await workspace.savePost(post);
    if (mounted) {
      setState(() { saving = false; dirty = !ok || revision != savedRevision;
        saveLabel = ok ? '${workspace.cloudAuthenticated ? 'Saved to SHIFT Cloud' : 'Saved on device'} • v${versions.length}'
          : workspace.cloudAuthenticated ? 'Cloud save failed • retry required' : 'Device save failed • changes in memory'; });
      // Edits made during a successful save get a fresh pass. A failed cloud
      // save remains explicitly retryable, without an uncontrolled network loop.
      if (ok && dirty) debounce = Timer(const Duration(milliseconds: 900), () => save(quiet: true));
      if (!quiet) toast(context, ok ? 'Draft saved ${workspace.cloudAuthenticated ? 'to SHIFT Cloud' : 'on this device'}.${changedContent && wasReviewed ? ' Content changed; review is required again.' : ''}'
        : workspace.cloudError ?? 'Save failed. Retry saving.');
    }
  }
  Future<void> generateText() async {
    if (generating) return;
    if (!workspace.cloudAuthenticated) {
      toast(context, 'Sign in to SHIFT Cloud to use AI generation.');
      return;
    }
    final prompt = instruction.text.trim();
    if (prompt.length < 5) {
      toast(context, 'Describe your post in at least five characters.');
      return;
    }
    if (mounted) setState(() => generating = true);
    try {
      final response = await ShiftCloud.client.functions.invoke(
        'shift-generate-text', body: {
          'prompt': prompt,
          'requestKey': 'shift-${DateTime.now().microsecondsSinceEpoch}',
          'goal': goal,
          'tone': tone,
          'platform': platform,
          'language': language,
          'audience': audience.text.trim(),
          'length': length,
        });
      if (response.data is! Map) throw StateError('Unexpected AI response.');
      final data = Map<String, dynamic>.from(response.data as Map);
      if (data['error'] != null) {
        if (data['error'] == 'ai_provider_not_configured') {
          throw StateError('SHIFT needs the server-side Groq API key and model before AI generation can run.');
        }
        throw StateError('AI request unavailable: ${data['error']}');
      }
      if (data['status'] != 'completed' || data['result'] is! Map) {
        throw StateError('AI generation has not completed. No draft was replaced.');
      }
      final result = Map<String, dynamic>.from(data['result'] as Map);
      final generatedCaption = result['caption']?.toString().trim() ?? '';
      if (generatedCaption.isEmpty) throw StateError('The AI returned no usable caption.');
      caption.text = generatedCaption;
      hook.text = result['headline']?.toString() ?? '';
      tags.text = result['hashtags']?.toString() ?? '';
      if (mounted) toast(context, 'AI draft generated. Review it before saving or approving.');
    } catch (e) {
      if (mounted) toast(context, 'Could not generate content: $e');
    } finally {
      if (mounted) setState(() => generating = false);
    }
  }

  /// AI never saves, approves or publishes without the user's explicit action.
  Future<void> runAiTool(String mode) async {
    if (generating) return;
    if (!workspace.cloudAuthenticated) {
      toast(context, 'Sign in to SHIFT Cloud to use AI tools.');
      return;
    }
    final transformModes = {'rewrite', 'tone', 'shorten', 'expand', 'hooks', 'hashtags'};
    final source = caption.text.trim();
    if (transformModes.contains(mode) && source.length < 5) {
      toast(context, 'Write or generate a caption before editing it with AI.');
      return;
    }
    const tasks = <String,String>{
      'rewrite':'Rewrite the caption for clarity and originality.',
      'tone':'Match the chosen brand voice and tone.',
      'shorten':'Create a concise version of this caption.',
      'expand':'Develop this caption with more useful detail.',
      'hooks':'Suggest three stronger opening hooks for this caption.',
      'hashtags':'Suggest relevant hashtags for the caption.',
      'ideas':'Develop five original content ideas aligned with my saved brand.',
      'strategy':'Create an actionable content strategy for my saved brand.',
    };
    setState(() => generating = true);
    try {
      final response = await ShiftCloud.client.functions.invoke(
        'shift-generate-text',
        body: <String,dynamic>{
          'prompt': [tasks[mode] ?? 'Improve my content.',
            if (instruction.text.trim().isNotEmpty) instruction.text.trim()]
              .join(' '),
          'requestKey':'shift-ai-${DateTime.now().microsecondsSinceEpoch}',
          'mode':mode,
          'sourceText':source,
          'goal':goal,
          'tone':tone,
          'platform':platform,
          'language':language,
          'audience':audience.text.trim(),
          'length':length,
        },
      );
      if (response.data is! Map) throw StateError('Invalid AI response.');
      final data = Map<String,dynamic>.from(response.data as Map);
      if (data['error'] != null) {
        final code = data['error'].toString();
        throw StateError(code == 'ai_provider_not_configured'
          ? 'Groq API key and model must be configured in SHIFT Supabase.'
          : 'AI operation unavailable: $code');
      }
      if (data['status'] != 'completed' || data['result'] is! Map) {
        throw StateError('The AI request has not completed. Try again later.');
      }
      final result = Map<String,dynamic>.from(data['result'] as Map);
      if (!mounted) return;
      if (mode == 'ideas') {
        final ideas = (result['ideas'] as List? ?? const [])
            .whereType<String>().where((s) => s.trim().isNotEmpty).toList();
        if (ideas.isEmpty) throw StateError('The AI did not return content ideas.');
        final picked = await showDialog<String>(
          context:context,
          builder:(dialog) => SimpleDialog(
            title:const Text('Content ideas'),
            children:[
              const Padding(padding:EdgeInsets.symmetric(horizontal:24),
                child:Text('Select an idea to add it to your instructions. Nothing is published.')),
              ...ideas.map((idea) => SimpleDialogOption(
                onPressed:()=>Navigator.pop(dialog,idea),
                child:Padding(padding:const EdgeInsets.symmetric(vertical:8),
                  child:Text(idea)),
              )),
              TextButton(onPressed:()=>Navigator.pop(dialog),
                child:const Text('Close')),
            ],
          ),
        );
        if (picked != null && mounted) {
          instruction.text = picked;
          toast(context, 'Idea added to instructions. Generate when ready.');
        }
        return;
      }
      if (mode == 'strategy') {
        final raw = result['strategy'];
        final strategy = raw is Map
          ? Map<String,dynamic>.from(raw) : <String,dynamic>{};
        final pillars = (strategy['pillars'] as List? ?? const [])
            .whereType<String>();
        final experiments = (strategy['experiments'] as List? ?? const [])
            .whereType<String>();
        final summary = <String>[
          if (strategy['positioning']?.toString().isNotEmpty == true)
            'Positioning\n${strategy['positioning']}',
          if (pillars.isNotEmpty) 'Content pillars\n${pillars.map((s)=>'• $s').join('\n')}',
          if (strategy['cadence']?.toString().isNotEmpty == true)
            'Cadence\n${strategy['cadence']}',
          if (experiments.isNotEmpty)
            'Experiments\n${experiments.map((s)=>'• $s').join('\n')}',
          if (strategy.isEmpty) result['caption']?.toString() ?? '',
        ].where((s) => s.isNotEmpty).join('\n\n');
        await showDialog<void>(context:context,builder:(dialog)=>AlertDialog(
          title:const Text('Brand content strategy'),
          content:SizedBox(width:440,child:SingleChildScrollView(
            child:SelectableText(summary))),
          actions:[TextButton(onPressed:()=>Navigator.pop(dialog),
            child:const Text('Close'))],
        ));
        return;
      }
      final suggestion = (mode == 'hooks'
          ? result['headline'] : mode == 'hashtags'
          ? result['hashtags'] : result['caption'])?.toString().trim() ?? '';
      if (suggestion.isEmpty) throw StateError('The AI did not return a usable suggestion.');
      final extraHooks = (result['alternatives'] as List? ?? const [])
          .whereType<String>().where((s) => s.trim().isNotEmpty).toList();
      final apply = await showDialog<bool>(context:context,builder:(dialog)=>AlertDialog(
        title:Text(mode == 'hooks' ? 'Suggested hooks'
            : mode == 'hashtags' ? 'Suggested hashtags' : 'Review AI edit'),
        content:SizedBox(width:440,child:SingleChildScrollView(child:Column(
          crossAxisAlignment:CrossAxisAlignment.start,mainAxisSize:MainAxisSize.min,
          children:[
            SelectableText(suggestion),
            if (mode == 'hooks' && extraHooks.isNotEmpty) ...[
              const SizedBox(height:12),
              const Text('Other hooks'),
              ...extraHooks.map((hook)=>Padding(
                padding:const EdgeInsets.only(top:8),
                child:SelectableText('• $hook'))),
            ],
            const SizedBox(height:12),
            const Text('This is a draft suggestion. Review before saving or publishing.',
              style:TextStyle(fontSize:12)),
          ],
        ))),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(dialog,false),
            child:const Text('Keep original')),
          FilledButton(onPressed:()=>Navigator.pop(dialog,true),
            child:const Text('Apply suggestion')),
        ],
      ))??false;
      if (!apply || !mounted) return;
      if (mode == 'hooks') {
        hook.text = suggestion;
      } else if (mode == 'hashtags') {
        tags.text = suggestion;
      } else {
        caption.text = suggestion;
        final suggestedHook = result['headline']?.toString().trim() ?? '';
        if (suggestedHook.isNotEmpty && hook.text.trim().isEmpty)
          hook.text = suggestedHook;
      }
      toast(context, 'Suggestion applied locally. Save and review the new revision.');
    } catch (e) {
      if (mounted) toast(context, 'AI tool could not complete: $e');
    } finally {
      if (mounted) setState(() => generating = false);
    }
  }

  Future<void> pickImage() async {
    try {
      final image = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 2048, maxHeight: 2048, imageQuality: 85);
      if (image == null) return;
      if (await image.length() > 10 * 1024 * 1024) { if (mounted) toast(context, 'Choose an image smaller than 10 MB.'); return; }
      final dir = await getApplicationDocumentsDirectory();
      final assets = Directory('${dir.path}/shift_media');
      await assets.create(recursive: true);
      final path = '${assets.path}/${DateTime.now().microsecondsSinceEpoch}.jpg';
      await image.saveTo(path);
      if (mounted) { setState(() => imagePath = path); changed(); }
    } catch (_) { if (mounted) toast(context, 'Unable to open this image. Check photo permissions and device storage.'); }
  }
  @override void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) { if (dirty && !saving) save(quiet: true); }
  }
  @override void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    debounce?.cancel();
    if (dirty && caption.text.trim().isNotEmpty) {
      final v = currentVersion();
      final old = workspace.posts.where((p) => p.id == id);
      workspace.savePost(LocalPost(id: id, title: title.text.trim().isEmpty ? 'Untitled post' : title.text.trim(), versions: [...versions, v], plannedAt: old.isEmpty ? null : old.first.plannedAt, timezone: old.isEmpty ? '' : old.first.timezone));
    }
    for (final c in [title, instruction, caption, audience, hook, tags, cta]) { c.dispose(); }
    super.dispose();
  }
  Widget option(String label, String value, List<String> items, ValueChanged<String> change) => Padding(padding: const EdgeInsets.only(bottom: 16), child: DropdownButtonFormField<String>(value: value, isExpanded: true, decoration: InputDecoration(labelText: label), items: items.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(), onChanged: (v) { change(v!); changed(); }));
  @override Widget build(BuildContext context) {
    if (missing) return const Empty('Draft not found', 'Return to the draft library and select an existing item.');
    final brandName = ref.watch(workspaceProvider).brand['name'] ?? 'Your brand';
    return PageBody(children: [
      Heading(widget.postId == null ? 'What should SHIFT\ncreate today?' : 'Make it sound like you.', 'Write an original post, refine it, and keep every version.'),
      ServiceNotice(text: workspace.cloudAuthenticated ? 'Cloud workspace • Drafts and images sync to Supabase. AI output is always a reviewable draft.' : 'Offline workspace • Sign in to save online and use AI.'),
      if (widget.postId == null) Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: () async {
        if (caption.text.trim().isNotEmpty) await save(quiet: true);
        if (!mounted) return;
        if (workspace.storageError != null) { toast(context, 'Save the current draft before starting another.'); return; }
        debounce?.cancel();
        for (final c in [title, instruction, caption, hook, tags, cta]) { c.clear(); }
        debounce?.cancel();
        setState(() { id = DateTime.now().microsecondsSinceEpoch.toString(); versions = []; imagePath = null; dirty = false; saveLabel = 'Not saved yet'; });
      }, icon: const Icon(Icons.add), label: const Text('New draft'))),
      Form(key: form, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Panel(glass: true, child: Column(children: [
          TextField(controller: instruction, maxLines: 3, decoration: const InputDecoration(labelText: 'Your instructions', hintText: 'An educational post about your next big idea…')),
          const SizedBox(height: 12), FilledButton.icon(onPressed: generating ? null : generateText,
            icon: const Icon(Icons.auto_awesome),
            label: Text(generating ? 'Generating…' : 'Generate with SHIFT')),
        ])),
        const Section('Creative direction'),
        option('Destination preview', platform, [if (!ShiftSocialPlatforms.names.contains(platform)) platform, ...ShiftSocialPlatforms.names], (v) => setState(() => platform = v)),
        option('Content goal', goal, ['Educate', 'Inform', 'Entertain', 'Promote', 'Build awareness', 'Encourage engagement'], (v) => setState(() => goal = v)),
        option('Tone', tone, ['Conversational', 'Professional', 'Inspirational', 'Playful', 'Direct'], (v) => setState(() => tone = v)),
        option('Length', length, ['Short', 'Medium', 'Long'], (v) => setState(() => length = v)),
        option('Output', output, ['Text only', 'Text + image'], (v) => setState(() => output = v)),
        TextField(onChanged: (v) { language = v; changed(); }, decoration: InputDecoration(labelText: 'Language', hintText: language)),
        const SizedBox(height: 16), TextField(controller: audience, decoration: InputDecoration(labelText: 'Target audience', hintText: workspace.brand['audience'] ?? 'Who is this for?')),
        const SizedBox(height: 16), Field('Call to action (generation instruction)', controller: cta),
        const Section('Your draft'),
        Field('Post title', controller: title),
        Field('Headline / hook', controller: hook),
        Field('Caption', controller: caption, lines: 7),
        Align(alignment: Alignment.centerRight, child: Text('${caption.text.length} characters', style: const TextStyle(fontSize: 12))),
        const SizedBox(height: 12), Field('Hashtags', controller: tags),
        Wrap(spacing:8,runSpacing:8,children:[
          for (final tool in const <(String,String)>[
            ('Rewrite','rewrite'),('Change tone','tone'),
            ('Shorten','shorten'),('Expand','expand'),
            ('Alternative hooks','hooks'),('Suggest hashtags','hashtags'),
          ]) OutlinedButton(
            onPressed:generating?null:()=>runAiTool(tool.$2),
            child:Text(tool.$1),
          ),
        ]),
        const Section('AI content planning'),
        Wrap(spacing:8,runSpacing:8,children:[
          OutlinedButton.icon(
            onPressed:generating?null:()=>runAiTool('ideas'),
            icon:const Icon(Icons.lightbulb_outline),
            label:const Text('Generate 5 ideas')),
          OutlinedButton.icon(
            onPressed:generating?null:()=>runAiTool('strategy'),
            icon:const Icon(Icons.auto_graph),
            label:const Text('Build content strategy')),
        ]),
        const Text('Suggestions use saved brand details and AI preferences. '
          'Nothing is published automatically.',style:TextStyle(fontSize:12)),
        const Section('Media'),
        if (imagePath != null) ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.file(File(imagePath!), height: 230, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Empty('Image unavailable', 'Choose a replacement from your device.'))),
        if (imagePath == null) const Empty('Add a visual', 'Upload an image from your device. AI-generated images need a connected service.', icon: Icons.image_outlined),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          OutlinedButton.icon(onPressed: pickImage, icon: const Icon(Icons.photo_library_outlined), label: Text(imagePath == null ? 'Upload image' : 'Replace image')),
          OutlinedButton(onPressed: () => unavailable(context, 'Image generation'), child: const Text('Generate image')),
          if (imagePath != null) TextButton(onPressed: () { setState(() => imagePath = null); changed(); }, child: const Text('Remove image')),
        ]),
        const Section('Platform preview'),
        Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [const CircleAvatar(child: Icon(Icons.person_outline)), const SizedBox(width: 12), Expanded(child: Text(brandName, style: Theme.of(context).textTheme.titleMedium)), Text(platform)]),
          const SizedBox(height: 12), const Text('PREVIEW • No connected destination', style: TextStyle(fontSize: 10, letterSpacing: 1)),
          if (imagePath != null) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Image.file(File(imagePath!), height: 180, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined))),
          const SizedBox(height: 12), if (hook.text.isNotEmpty) Text(hook.text, style: Theme.of(context).textTheme.titleMedium),
          Text(caption.text.isEmpty ? 'Your caption will appear here.' : caption.text), if (tags.text.isNotEmpty) Text(tags.text),
          const SizedBox(height: 12), Text(ShiftSocialPlatforms.byName(platform).publishingNote, style: const TextStyle(fontSize: 12)),
        ])),
        const SizedBox(height: 20), Text(saveLabel, style: const TextStyle(fontSize: 12)), const SizedBox(height: 8),
        FilledButton.icon(onPressed: saving ? null : save, icon: const Icon(Icons.save_outlined), label: Text(saving ? 'Saving…' : 'Save draft')),
        const SizedBox(height: 8), OutlinedButton(onPressed: saving ? null : () async { await save(); if (workspace.storageError != null) return; if (mounted && caption.text.trim().isNotEmpty) { final found = workspace.posts.where((p) => p.id == id); if (found.isNotEmpty) { final ok = await workspace.changePost(found.first.copyWith(status: PostStatus.pendingApproval), 'Draft added to local review queue'); if (mounted) toast(context, ok ? 'Added to local approval inbox. No publishing authorized.' : 'Review change is in memory only.'); } } }, child: const Text('Prepare for review')),
        const SizedBox(height: 8), OutlinedButton(onPressed: () => unavailable(context, 'Publishing'), child: const Text('Publish now')),
      ])),
    ]);
  }
}
