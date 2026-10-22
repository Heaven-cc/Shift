import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/domain/models.dart';
import '../../core/state/workspace.dart';
import '../../core/ui/design.dart';

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
  bool saving = false, dirty = false, missing = false;
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
      title.text = p.title; caption.text = v.caption; hook.text = v.headline; tags.text = v.hashtags; platform = v.platform; imagePath = v.imagePath; versions = [...p.versions]; saveLabel = 'Saved on this device';
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
      setState(() { saving = false; dirty = revision != savedRevision; saveLabel = ok ? 'Saved on this device • v${versions.length}' : 'Storage failed • changes in memory'; });
      if (dirty) debounce = Timer(const Duration(milliseconds: 900), () => save(quiet: true));
      if (!quiet) toast(context, ok ? 'Draft saved locally.${changedContent && wasReviewed ? ' Content changed; review is required again.' : ''}' : 'Device storage failed. Retry saving.');
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
      const ServiceNotice(),
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
          const SizedBox(height: 12), FilledButton.icon(onPressed: () => instruction.text.trim().isEmpty ? toast(context, 'Describe what you want to create.') : unavailable(context, 'AI text and image generation'), icon: const Icon(Icons.auto_awesome), label: const Text('Generate with SHIFT')),
        ])),
        const Section('Creative direction'),
        option('Destination preview', platform, ['Instagram', 'Facebook'], (v) => setState(() => platform = v)),
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
        Wrap(spacing: 8, runSpacing: 8, children: ['Regenerate text', 'Change tone', 'Shorten', 'Expand', 'Alternative hooks'].map((s) => OutlinedButton(onPressed: () => unavailable(context, s), child: Text(s))).toList()),
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
          const SizedBox(height: 12), Text(platform == 'Instagram' ? 'Instagram requires eligible media and a professional account. The server will validate the format.' : 'Facebook publishing requires a connected Page. Final formatting depends on provider capabilities.', style: const TextStyle(fontSize: 12)),
        ])),
        const SizedBox(height: 20), Text(saveLabel, style: const TextStyle(fontSize: 12)), const SizedBox(height: 8),
        FilledButton.icon(onPressed: saving ? null : save, icon: const Icon(Icons.save_outlined), label: Text(saving ? 'Saving…' : 'Save draft')),
        const SizedBox(height: 8), OutlinedButton(onPressed: saving ? null : () async { await save(); if (workspace.storageError != null) return; if (mounted && caption.text.trim().isNotEmpty) { final found = workspace.posts.where((p) => p.id == id); if (found.isNotEmpty) { final ok = await workspace.changePost(found.first.copyWith(status: PostStatus.pendingApproval), 'Draft added to local review queue'); if (mounted) toast(context, ok ? 'Added to local approval inbox. No publishing authorized.' : 'Review change is in memory only.'); } } }, child: const Text('Prepare for review')),
        const SizedBox(height: 8), OutlinedButton(onPressed: () => unavailable(context, 'Publishing'), child: const Text('Publish now')),
      ])),
    ]);
  }
}
