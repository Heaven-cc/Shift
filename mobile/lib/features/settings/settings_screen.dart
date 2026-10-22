import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../../core/state/workspace.dart';
import '../../core/ui/design.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key, this.section});
  final String? section;
  @override Widget build(BuildContext context, WidgetRef ref) {
    final w = ref.watch(workspaceProvider);
    if (['profile', 'brand', 'ai'].contains(section)) return PreferenceForm(section: section!);
    final title = switch(section) { 'appearance' => 'Appearance', 'notifications' => 'Notification preferences', 'privacy' => 'Privacy & security', 'help' => 'Help & support', _ => 'Your workspace' };
    return Scaffold(appBar: AppBar(title: Text(title)), body: PageBody(children: [
      if (section == null) ...[
        Heading(w.brand['name'] ?? 'Make SHIFT yours.', 'A workspace that sounds like you.'),
        const ServiceNotice(),
        ...[
          ('Profile', 'Name, language and timezone', Icons.person_outline, '/settings/profile'),
          ('Brand identity', 'Audience, voice and guidelines', Icons.fingerprint, '/settings/brand'),
          ('Social accounts', 'Connections and permissions', Icons.link, '/accounts'),
          ('AI preferences', 'Style, research and images', Icons.auto_awesome_outlined, '/settings/ai'),
          ('Automation', 'Rules, limits and posting windows', Icons.bolt_outlined, '/automation'),
          ('Approvals', 'Review your local content', Icons.fact_check_outlined, '/approvals'),
          ('Appearance', 'Light, dark or system', Icons.contrast, '/settings/appearance'),
          ('Notifications', 'Choose what reaches you', Icons.notifications_outlined, '/settings/notifications'),
          ('Privacy & security', 'Data controls and sessions', Icons.lock_outline, '/settings/privacy'),
          ('Help & support', 'FAQ and application information', Icons.help_outline, '/settings/help'),
        ].map((r) => ListTile(contentPadding: EdgeInsets.zero, leading: Icon(r.$3), title: Text(r.$1), subtitle: Text(r.$2), trailing: const Icon(Icons.chevron_right), onTap: () => context.push(r.$4))),
      ],
      if (section == 'appearance') ...[
        const Heading('Your kind of clarity.', 'Choose a theme. System follows your device.'),
        ...ThemeMode.values.map((m) => RadioListTile<ThemeMode>(title: Text(m.name[0].toUpperCase() + m.name.substring(1)), value: m, groupValue: w.theme, onChanged: (v) async { w.theme = v!; await w.persist(); })),
        const SizedBox(height: 20), const Panel(child: Text('SHIFT follows your device’s reduced-motion setting. Text sizes follow system accessibility preferences.')),
      ],
      if (section == 'notifications') ...[
        const ServiceNotice(text: 'Preferences are saved on this device. Push delivery is not configured.'),
        ...w.notificationPreferences.keys.map((k) => SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(k), value: w.notificationPreferences[k]!, onChanged: (v) { w.notificationPreferences[k] = v; w.persist(); })),
        const Section('Delivery'),
        const ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.phonelink_erase), title: Text('Push notifications'), subtitle: Text('Unavailable until mobile push services are connected')),
        const ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.notifications_none), title: Text('In-app notifications'), subtitle: Text('No server notifications received')),
      ],
      if (section == 'privacy') ...[
        const Heading('You stay in control.', 'Your local workspace and account data.'),
        const Panel(child: Text('This frontend has no authenticated session, cloud account, AI keys or social tokens. Local drafts, uploaded images and preferences stay in application storage on this device. They are not a cloud backup.')),
        const Section('Sessions & permissions'),
        ListTile(contentPadding: EdgeInsets.zero, title: const Text('Manage signed-in sessions'), subtitle: const Text('No account session exists'), onTap: () => unavailable(context, 'Session management')),
        ListTile(contentPadding: EdgeInsets.zero, title: const Text('Connected app permissions'), trailing: const Icon(Icons.chevron_right), onTap: () => context.push('/accounts')),
        const Section('Data controls'),
        OutlinedButton(onPressed: () => unavailable(context, 'Cloud data export'), child: const Text('Export account data')),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: () async {
          if (!await confirm(context, 'Clear all local data?', 'This deletes local drafts, version history, uploaded images, source bookmarks and preferences from this device. This cannot be undone.', action: 'Clear local data')) return;
          try {
            final dir = await getApplicationDocumentsDirectory();
            for (final folder in ['shift_media', 'shift_brand']) { final assets = Directory('${dir.path}/$folder'); if (await assets.exists()) await assets.delete(recursive: true); }
            await w.clear();
          } catch (_) { if (context.mounted) toast(context, 'Unable to clear all data. Check device storage and retry.'); }
        }, child: const Text('Clear local workspace')),
        const SizedBox(height: 12),
        TextButton(onPressed: () => unavailable(context, 'Cloud account deletion'), child: const Text('Delete SHIFT account')),
        TextButton(onPressed: () async { w.entered = false; await w.persist(); }, child: const Text('Leave local workspace')),
      ],
      if (section == 'help') ...[
        const Heading('A little help,\nwhen you need it.', 'SHIFT • Frontend edition 0.2.0'),
        const ExpansionTile(tilePadding: EdgeInsets.zero, title: Text('Does SHIFT publish while closed?'), children: [Padding(padding: EdgeInsets.only(bottom: 16), child: Text('The planned cloud service will. This frontend cannot research, generate or publish in the background. Local planning dates do not trigger posts.'))]),
        const ExpansionTile(tilePadding: EdgeInsets.zero, title: Text('Where are my drafts?'), children: [Padding(padding: EdgeInsets.only(bottom: 16), child: Text('Draft text, version history and preferences are in this app’s local storage. Uploaded photos are copied into app storage. Clearing data or uninstalling can remove them. Cloud sync has not been added.'))]),
        const ExpansionTile(tilePadding: EdgeInsets.zero, title: Text('Which accounts can I connect?'), children: [Padding(padding: EdgeInsets.only(bottom: 16), child: Text('No connections are operational yet. Initial publishing integrations are planned for Instagram professional accounts and Facebook Pages. Personal accounts are not promised.'))]),
        const SizedBox(height: 20), const Panel(child: Text('Support contact has not been configured. No support message is sent from this edition.')),
        const SizedBox(height: 12), OutlinedButton(onPressed: () => showAboutDialog(context: context, applicationName: 'SHIFT', applicationVersion: '0.2.0', applicationIcon: const Icon(Icons.bolt, size: 40), children: [const Text('Your AI social media manager. Native Flutter frontend for Android and iOS.')]), child: const Text('About SHIFT & licenses')),
      ],
    ]));
  }
}
class PreferenceForm extends ConsumerStatefulWidget {
  const PreferenceForm({super.key, required this.section});
  final String section;
  @override ConsumerState<PreferenceForm> createState() => _PreferenceFormState();
}
class _PreferenceFormState extends ConsumerState<PreferenceForm> {
  final form = GlobalKey<FormState>();
  final fields = <String, TextEditingController>{};
  String? logo;
  bool busy = false;
  Map<String, String> get labels => switch(widget.section) {
    'profile' => {'name': 'Display name', 'email': 'Contact email (local only)', 'language': 'Preferred language', 'timezone': 'Timezone (IANA name, e.g. Africa/Lagos)'},
    'brand' => {'name': 'Brand or creator name', 'description': 'Description', 'niche': 'Content niche', 'audience': 'Target audience', 'market': 'Country / primary market', 'language': 'Language', 'tone': 'Writing tone', 'topics': 'Preferred topics', 'blocked': 'Blocked topics', 'colors': 'Optional brand colors', 'guidelines': 'Brand guidelines'},
    _ => {'style': 'Writing style', 'length': 'Preferred content length', 'language': 'Content language', 'images': 'Image preferences', 'categories': 'Research categories', 'avoid': 'Topics to avoid'},
  };
  @override void initState() {
    super.initState();
    final w = ref.read(workspaceProvider);
    final source = widget.section == 'profile' ? w.profile : widget.section == 'brand' ? w.brand : w.preferences;
    for (final k in labels.keys) { fields[k] = TextEditingController(text: source[k] ?? ''); }
    logo = source['logo'];
  }
  @override void dispose() { for (final c in fields.values) { c.dispose(); } super.dispose(); }
  Future<void> chooseLogo() async {
    try {
      final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 512, imageQuality: 85);
      if (file == null) return;
      final dir = await getApplicationDocumentsDirectory();
      final folder = Directory('${dir.path}/shift_brand'); await folder.create(recursive: true);
      final path = '${folder.path}/${DateTime.now().microsecondsSinceEpoch}.jpg';
      await file.saveTo(path);
      if (mounted) setState(() => logo = path);
    } catch (_) { if (mounted) toast(context, 'Photo could not be selected. Check permissions.'); }
  }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(widget.section == 'profile' ? 'Profile' : widget.section == 'brand' ? 'Brand identity' : 'AI preferences')), body: PageBody(children: [
    const ServiceNotice(text: 'Saved on this device • These settings do not configure a cloud account'),
    Form(key: form, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (widget.section != 'ai') ...[
        if (logo != null) Align(child: ClipRRect(borderRadius: BorderRadius.circular(30), child: Image.file(File(logo!), width: 72, height: 72, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.person_outline, size: 48)))),
        OutlinedButton.icon(onPressed: chooseLogo, icon: const Icon(Icons.add_photo_alternate_outlined), label: Text(widget.section == 'brand' ? 'Choose optional logo' : 'Choose avatar')),
        const SizedBox(height: 16),
      ],
      ...labels.entries.map((e) => Padding(padding: const EdgeInsets.only(bottom: 16), child: TextFormField(controller: fields[e.key], maxLines: ['description', 'guidelines', 'blocked', 'topics', 'avoid', 'images'].contains(e.key) ? 3 : 1, decoration: InputDecoration(labelText: e.value), validator: (v) {
        if (e.key == 'name' && (v?.trim().isEmpty ?? true)) return 'Enter a name';
        if (e.key == 'email' && v?.isNotEmpty == true && !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v!)) return 'Enter a valid email';
        if (e.key == 'timezone' && v?.isNotEmpty == true && !RegExp(r'^[A-Za-z_]+/[A-Za-z_]+(?:/[A-Za-z_]+)?$').hasMatch(v!)) return 'Use an IANA name such as Africa/Lagos';
        return null;
      }))),
      if (widget.section == 'profile') const Text('Timezone is a preference for the future cloud scheduler. Local planning uses the device timezone. Email changes do not update an authentication account.', style: TextStyle(fontSize: 12)),
      const SizedBox(height: 20),
      FilledButton(onPressed: busy ? null : () async {
        if (!form.currentState!.validate()) return;
        setState(() => busy = true);
        final w = ref.read(workspaceProvider);
        final values = {for (final e in fields.entries) e.key: e.value.text.trim(), if (logo != null) 'logo': logo!};
        if (widget.section == 'profile') { w.profile.addAll(values); } else if (widget.section == 'brand') { w.brand.addAll(values); } else { w.preferences.addAll(values); }
        w.record('Local ${widget.section} settings updated', '/settings/${widget.section}');
        final ok = await w.persist();
        if (mounted) { setState(() => busy = false); toast(context, ok ? 'Preferences saved on this device.' : 'Changes could not be saved to device storage.'); }
      }, child: Text(busy ? 'Saving…' : 'Save preferences')),
    ])),
  ]));
}
class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key});
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Social accounts')), body: PageBody(children: [
    const Heading('Your presence.\nOne workspace.', 'Official connections, with clear permissions.'),
    const ServiceNotice(text: 'OAuth is not connected. No account or token exists in this frontend.'),
    ...[
      ('Instagram', 'Professional Business / Creator accounts', 'Image publishing planned through the official API.'),
      ('Facebook', 'Facebook Pages', 'Page posts planned through the official API.'),
    ].map((p) => Padding(padding: const EdgeInsets.only(bottom: 16), child: Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(p.$1, style: Theme.of(context).textTheme.headlineSmall), const SizedBox(height: 8), Text(p.$2),
      const SizedBox(height: 8), Text(p.$3), const SizedBox(height: 12),
      const Text('Not connected\nGranted permissions: none\nAuthorization expiry: unavailable\nLast connection check: never', style: TextStyle(fontSize: 12)),
      const SizedBox(height: 12), OutlinedButton(onPressed: () => unavailable(context, '${p.$1} account connection'), child: const Text('Connect account')),
    ])))),
    const Section('Planned integrations'),
    ...['TikTok', 'LinkedIn', 'X', 'Threads', 'Pinterest'].map((p) => ListTile(contentPadding: EdgeInsets.zero, title: Text(p), subtitle: const Text('Planned • Automatic publishing unavailable'), trailing: const Icon(Icons.lock_clock_outlined))),
    const Section('Manual export'),
    const Text('Copy caption text from any draft and publish through the provider’s app. Uploaded images remain in the photo library you selected them from. SHIFT does not mark manual exports as published.'),
    const SizedBox(height: 16), OutlinedButton(onPressed: () => context.push('/drafts'), child: const Text('Open draft library')),
  ]));
}
class AutomationScreen extends ConsumerStatefulWidget {
  const AutomationScreen({super.key});
  @override ConsumerState<AutomationScreen> createState() => _AutomationState();
}
class _AutomationState extends ConsumerState<AutomationScreen> {
  final form = GlobalKey<FormState>();
  late String mode, schedule;
  final fields = <String, TextEditingController>{};
  Set<String> days = {};
  bool images = false, sourceBacked = true, busy = false;
  DateTime? expires;
  TimeOfDay start = const TimeOfDay(hour: 9, minute: 0), end = const TimeOfDay(hour: 18, minute: 0);
  static const labels = {'dailyLimit': 'Maximum posts per account / day', 'weeklyTarget': 'Maximum posts / week', 'allowedTopics': 'Allowed categories', 'blockedTopics': 'Blocked topics', 'tone': 'Preferred tone'};
  @override void initState() {
    super.initState();
    final p = ref.read(workspaceProvider).preferences;
    mode = p['mode'] ?? 'Approval required'; schedule = p['schedulePreference'] ?? 'Custom';
    for (final k in labels.keys) { fields[k] = TextEditingController(text: p[k] ?? (k == 'dailyLimit' ? '1' : k == 'weeklyTarget' ? '5' : '')); }
    days = (p['days'] ?? 'Mon,Wed,Fri').split(',').toSet();
    images = p['allowImages'] == 'true'; sourceBacked = p['sourceBacked'] != 'false';
    expires = DateTime.tryParse(p['authorizationExpiry'] ?? '');
    TimeOfDay parse(String? s, TimeOfDay fallback) { final v = s?.split(':'); return v?.length == 2 ? TimeOfDay(hour: int.parse(v![0]), minute: int.parse(v[1])) : fallback; }
    start = parse(p['windowStart'], start); end = parse(p['windowEnd'], end);
  }
  @override void dispose() { for (final c in fields.values) { c.dispose(); } super.dispose(); }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Automation')), body: PageBody(children: [
    const Heading('Your rules.\nSHIFT follows.', 'Define the boundaries before automation begins.'),
    const Panel(glass: true, child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.pause_circle_outline), title: Text('Cloud automation inactive'), subtitle: Text('No worker, account or authorization connected.'))),
    const SizedBox(height: 16),
    OutlinedButton.icon(onPressed: () async { final w = ref.read(workspaceProvider); w.preferences['paused'] = 'true'; w.record('Local automation pause preference saved', '/automation'); final ok = await w.persist(); if (context.mounted) toast(context, ok ? 'Local pause preference saved. No cloud automation exists.' : 'Could not persist pause preference.'); }, icon: const Icon(Icons.pause), label: const Text('Keep automation paused')),
    Form(key: form, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Section('Publishing mode'),
      ...['Manual', 'Approval required', 'Trusted Autopilot'].map((s) => RadioListTile<String>(contentPadding: EdgeInsets.zero, value: s, groupValue: mode, title: Text(s), subtitle: Text(s == 'Manual' ? 'Every publication needs your action.' : s == 'Approval required' ? 'Review exact content and destinations.' : 'Only within explicit account and content rules.'), onChanged: (v) => setState(() => mode = v!))),
      const Section('Content boundaries'),
      ...labels.entries.map((e) => Padding(padding: const EdgeInsets.only(bottom: 16), child: TextFormField(controller: fields[e.key], keyboardType: e.key.contains('Limit') || e.key == 'weeklyTarget' ? TextInputType.number : TextInputType.text, decoration: InputDecoration(labelText: e.value), validator: (v) {
        if (e.key == 'dailyLimit' || e.key == 'weeklyTarget') { final n = int.tryParse(v ?? ''); if (n == null || n < 1 || n > (e.key == 'dailyLimit' ? 10 : 70)) return 'Use 1–${e.key == 'dailyLimit' ? 10 : 70}'; }
        return null;
      }))),
      SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Allow generated images'), value: images, onChanged: (v) => setState(() => images = v)),
      SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Require source-backed research'), value: sourceBacked, onChanged: (v) => setState(() => sourceBacked = v)),
      const Section('Posting schedule'),
      DropdownButtonFormField<String>(value: schedule, decoration: const InputDecoration(labelText: 'Scheduling preference'), items: ['Custom', 'AI recommended'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(), onChanged: (v) => setState(() => schedule = v!)),
      if (schedule == 'AI recommended') const Padding(padding: EdgeInsets.only(top: 12), child: Text('Recommendations are unavailable without account history. They will be estimates, not guaranteed optimal times.')),
      const SizedBox(height: 16),
      Wrap(spacing: 8, runSpacing: 8, children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].map((d) => FilterChip(label: Text(d), selected: days.contains(d), onSelected: (v) => setState(() { if (v) { days.add(d); } else { days.remove(d); } }))).toList()),
      const SizedBox(height: 12),
      ListTile(contentPadding: EdgeInsets.zero, title: const Text('Posting window start'), trailing: Text(start.format(context)), onTap: () async { final v = await showTimePicker(context: context, initialTime: start); if (v != null) setState(() => start = v); }),
      ListTile(contentPadding: EdgeInsets.zero, title: const Text('Posting window end'), trailing: Text(end.format(context)), onTap: () async { final v = await showTimePicker(context: context, initialTime: end); if (v != null) setState(() => end = v); }),
      const Text('Window follows your chosen timezone when a cloud scheduler is connected. Overnight windows are not supported by this preference form.', style: TextStyle(fontSize: 12)),
      const Section('Autopilot authorization'),
      const Text('Approved accounts: none\nSensitive or unverified claims: human review required'),
      ListTile(contentPadding: EdgeInsets.zero, title: const Text('Authorization expiry preference'), subtitle: Text(expires == null ? 'Not set' : DateFormat.yMMMd().format(expires!)), onTap: () async { final now = DateTime.now(); final d = await showDatePicker(context: context, initialDate: expires != null && expires!.isAfter(now) ? expires! : now.add(const Duration(days: 30)), firstDate: now, lastDate: now.add(const Duration(days: 365))); if (d != null) setState(() => expires = d); }),
      const SizedBox(height: 20),
      FilledButton(onPressed: busy ? null : () async {
        if (!form.currentState!.validate()) return;
        if (days.isEmpty) { toast(context, 'Select at least one weekday.'); return; }
        if (end.hour * 60 + end.minute <= start.hour * 60 + start.minute) { toast(context, 'End time must follow start time.'); return; }
        if (mode == 'Trusted Autopilot') {
          if (expires == null || !expires!.isAfter(DateTime.now())) { toast(context, 'Choose a future expiry date.'); return; }
          if (!await confirm(context, 'Save an inactive Autopilot preference?', 'No accounts are connected. This does not enable or authorize automatic publishing. Actual activation will require account selection and explicit authorization.', action: 'Save inactive preference')) return;
        }
        setState(() => busy = true);
        final w = ref.read(workspaceProvider);
        w.preferences.addAll({for (final e in fields.entries) e.key: e.value.text.trim(), 'mode': mode, 'schedulePreference': schedule, 'days': days.join(','), 'allowImages': '$images', 'sourceBacked': '$sourceBacked', 'windowStart': '${start.hour}:${start.minute}', 'windowEnd': '${end.hour}:${end.minute}', 'authorizationExpiry': expires?.toIso8601String() ?? '', 'paused': 'true'});
        w.record('Inactive automation preferences updated', '/automation');
        final ok = await w.persist();
        if (mounted) { setState(() => busy = false); toast(context, ok ? 'Preferences saved. Automation remains inactive.' : 'Could not persist preferences.'); }
      }, child: Text(busy ? 'Saving…' : 'Save preferences')),
      const SizedBox(height: 8), OutlinedButton(onPressed: () => unavailable(context, 'Autopilot activation'), child: const Text('Review activation requirements')),
      TextButton(onPressed: () => unavailable(context, 'Cloud automation run'), child: const Text('Run now')),
    ])),
  ]));
}
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});
  @override ConsumerState<NotificationsScreen> createState() => _NotificationsState();
}
class _NotificationsState extends ConsumerState<NotificationsScreen> {
  bool activity = false;
  @override Widget build(BuildContext context) {
    final w = ref.watch(workspaceProvider);
    return Scaffold(appBar: AppBar(title: const Text('Your updates'), actions: [IconButton(tooltip: 'Notification preferences', onPressed: () => context.push('/settings/notifications'), icon: const Icon(Icons.tune))]), body: PageBody(children: [
      SegmentedButton<bool>(segments: const [ButtonSegment(value: false, label: Text('Notifications')), ButtonSegment(value: true, label: Text('Local activity'))], selected: {activity}, onSelectionChanged: (v) => setState(() => activity = v.first)),
      const SizedBox(height: 20),
      if (!activity) const Empty('You’re all caught up', 'No server notifications have been received. Push delivery is not connected.', icon: Icons.notifications_none),
      if (activity && w.activity.isEmpty) const Empty('A fresh start', 'Your local workspace changes will appear here.'),
      if (activity) ...w.activity.map((a) => ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.history), title: Text(a['title']!), subtitle: Text('Local • ${DateFormat.MMMd().add_jm().format(DateTime.parse(a['at']!))}'), trailing: const Icon(Icons.chevron_right), onTap: () => context.push(a['route']!))),
    ]));
  }
}
