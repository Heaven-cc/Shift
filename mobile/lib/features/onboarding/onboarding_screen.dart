import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/state/workspace.dart';
import '../../core/ui/design.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override ConsumerState<OnboardingScreen> createState() => _OnboardingState();
}
class _OnboardingState extends ConsumerState<OnboardingScreen> {
  int step = 0;
  final form = GlobalKey<FormState>();
  final fields = <String, TextEditingController>{};
  final custom = TextEditingController();
  String purpose = 'Personal creator', mode = 'Approval required';
  Set<String> interests = {};
  bool confirmed = false, saving = false;
  static const labels = {'name': 'Brand or creator name', 'description': 'Short description', 'niche': 'Content niche', 'audience': 'Target audience', 'market': 'Country / primary market', 'language': 'Language', 'tone': 'Writing tone', 'topics': 'Important topics', 'blocked': 'Topics to avoid', 'colors': 'Optional brand colors', 'weeklyTarget': 'Weekly content target'};
  @override void initState() {
    super.initState();
    final w = ref.read(workspaceProvider);
    for (final k in labels.keys) { fields[k] = TextEditingController(text: w.brand[k] ?? (k == 'language' ? 'English' : k == 'weeklyTarget' ? '5' : '')); }
    interests = {...w.interests};
    purpose = w.preferences['purpose'] ?? purpose;
    mode = w.preferences['mode'] ?? mode;
  }
  @override void dispose() { for (final c in fields.values) { c.dispose(); } custom.dispose(); super.dispose(); }
  Future<void> next() async {
    if (!form.currentState!.validate()) return;
    final w = ref.read(workspaceProvider);
    w.brand = {...w.brand, for (final e in fields.entries) e.key: e.value.text.trim()};
    w.interests = {...interests};
    w.preferences.addAll({'purpose': purpose, 'mode': mode});
    if (step == 5) { w.onboardingComplete = true; w.record('Local workspace configured', '/settings'); }
    setState(() => saving = true);
    final ok = await w.persist();
    if (!mounted) return;
    setState(() { saving = false; if (ok && step < 5) step++; });
    if (!ok) toast(context, 'Unable to save setup. Retry after checking device storage.');
  }
  @override Widget build(BuildContext context) {
    const titles = ['Make it yours.', 'What moves you?', 'Define your voice.', 'Connect your presence.', 'Stay in control.', 'Ready for your next chapter.'];
    return Scaffold(appBar: AppBar(title: const Text('Set up SHIFT'), leading: step > 0 ? IconButton(tooltip: 'Previous step', onPressed: () => setState(() => step--), icon: const Icon(Icons.arrow_back)) : null), body: PageBody(children: [
      LinearProgressIndicator(value: (step + 1) / 6), const SizedBox(height: 20),
      Heading(titles[step], 'Step ${step + 1} of 6 • Local workspace setup'),
      Form(key: form, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (step == 0) ...['Personal creator', 'Influencer', 'Business / brand', 'Freelance / client work'].map((p) => RadioListTile<String>(value: p, groupValue: purpose, title: Text(p), onChanged: (v) => setState(() => purpose = v!))),
        if (step == 1) ...[
          Wrap(spacing: 8, runSpacing: 8, children: {...['Technology', 'Entertainment', 'Business', 'Fashion', 'Sports', 'Education', 'Lifestyle', 'Gaming'], ...interests}.map((s) => FilterChip(label: Text(s), selected: interests.contains(s), onSelected: (v) => setState(() { if (v) { interests.add(s); } else { interests.remove(s); } }))).toList()),
          const SizedBox(height: 20), TextField(controller: custom, maxLength: 60, decoration: InputDecoration(labelText: 'Custom interest', suffixIcon: IconButton(tooltip: 'Add interest', onPressed: () { if (custom.text.trim().isNotEmpty) setState(() { interests.add(custom.text.trim()); custom.clear(); }); }, icon: const Icon(Icons.add)))),
        ],
        if (step == 2) ...labels.entries.where((e) => e.key != 'weeklyTarget').map((e) => Field(e.value, controller: fields[e.key]!, required: ['name', 'niche', 'audience', 'language'].contains(e.key), lines: ['description', 'blocked'].contains(e.key) ? 2 : 1)),
        if (step == 3) ...[
          const ServiceNotice(text: 'Social OAuth is not connected. You can complete setup and connect later.'),
          ...['Instagram Professional', 'Facebook Pages'].map((p) => ListTile(leading: const Icon(Icons.link_off), title: Text(p), subtitle: const Text('Not connected'), trailing: OutlinedButton(onPressed: () => unavailable(context, p), child: const Text('Connect')))),
        ],
        if (step == 4) ...[
          ...['Manual', 'Approval required', 'Trusted Autopilot'].map((p) => RadioListTile<String>(value: p, groupValue: mode, title: Text(p), subtitle: Text(p == 'Trusted Autopilot' ? 'Preference only. Requires separate cloud authorization.' : p == 'Manual' ? 'You decide when each post is published.' : 'Review exact content and destinations first.'), onChanged: (v) => setState(() => mode = v!))),
          const SizedBox(height: 16),
          TextFormField(controller: fields['weeklyTarget'], keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Weekly content target'), validator: (v) { final n = int.tryParse(v ?? ''); return n == null || n < 1 || n > 70 ? 'Choose 1–70 opportunities per week' : null; }),
          const SizedBox(height: 16), const Panel(child: Text('AI-recommended schedules will become available with account data. Setup does not enable any automation.')),
        ],
        if (step == 5) ...[
          Panel(glass: true, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(fields['name']!.text, style: Theme.of(context).textTheme.headlineSmall), const SizedBox(height: 12),
            Text('$purpose • $mode'), const SizedBox(height: 8), Text(interests.join(' • ')),
            const SizedBox(height: 8), Text('Weekly target: ${fields['weeklyTarget']!.text}'),
            const SizedBox(height: 12), const Text('Connected accounts: none\nAutomation: inactive\nStorage: this device only'),
          ])),
          CheckboxListTile(contentPadding: EdgeInsets.zero, title: const Text('Confirm these preferences for my local workspace. This does not authorize publishing.'), value: confirmed, onChanged: (v) => setState(() => confirmed = v ?? false)),
        ],
        const SizedBox(height: 24),
        FilledButton(onPressed: saving || (step == 5 && !confirmed) ? null : next, child: Text(saving ? 'Saving…' : step == 5 ? 'Open workspace' : step == 3 ? 'Continue without accounts' : 'Continue')),
      ])),
    ]));
  }
}
