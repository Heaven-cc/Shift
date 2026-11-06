import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../../core/state/workspace.dart';
import '../../core/cloud/shift_cloud.dart';
import '../../core/ui/design.dart';
import '../../core/social/social_platforms.dart';
import '../../core/social/platform_setup.dart';
import '../../core/social/direct_connections_panel.dart';

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
          ('SHIFT AI Workspace', 'Brand research, ideas, strategy and content plans', Icons.psychology_outlined, '/ai-workspace'),
          ('Automation', 'Rules, limits and posting windows', Icons.bolt_outlined, '/automation'),
          ('Approvals', 'Review your drafts and cloud content', Icons.fact_check_outlined, '/approvals'),
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
        ServiceNotice(text: w.cloudAuthenticated ? 'Notification preferences sync to SHIFT Cloud. Push delivery is not configured.' : 'Offline preferences are saved on this device. Push delivery is not configured.'),
        ...w.notificationPreferences.keys.map((k) => SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(k), value: w.notificationPreferences[k]!, onChanged: (v) { w.notificationPreferences[k] = v; w.persist(); })),
        const Section('Delivery'),
        const ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.phonelink_erase), title: Text('Push notifications'), subtitle: Text('Unavailable until mobile push services are connected')),
        const ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.notifications_none), title: Text('In-app notifications'), subtitle: Text('Cloud notifications require a signed-in workspace; push delivery is not yet connected')),
      ],
      if (section == 'privacy') ...[
        const Heading('You stay in control.', 'Your local workspace and account data.'),
        Panel(child: Text(w.cloudAuthenticated ? 'Signed in to SHIFT. Profile, brand preferences, drafts and supported private images sync securely with SHIFT. Offline drafts are imported only when you choose to import them.' : 'Local workspace: content is stored on this device and is not a cloud backup.')),
        const Section('Sessions & permissions'),
        ListTile(contentPadding: EdgeInsets.zero, title: const Text('Session'), subtitle: Text(w.cloudAuthenticated ? 'Signed in: ${ShiftCloud.user?.email ?? 'SHIFT account'}' : 'Local workspace only')),
        ListTile(contentPadding: EdgeInsets.zero, title: const Text('Connected app permissions'), trailing: const Icon(Icons.chevron_right), onTap: () => context.push('/accounts')),
        const Section('Data controls'),
        if(w.cloudAuthenticated) OutlinedButton(
          onPressed:() async {
            if(!await confirm(context,'Import local text drafts?',
              'Copy locally saved draft text and version history into this SHIFT account. Local approvals do not transfer. Images and existing local files stay on this device. Your original local workspace will be preserved.',
              action:'Import drafts'))return;
            final ok=await w.importLocalDrafts();
            if(context.mounted)toast(context,ok?'Local draft text imported.':'Import failed or incomplete. Local originals remain unchanged.');
          },
          child:const Text('Import device drafts to SHIFT Cloud'),
        ),
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
        TextButton(onPressed: () async { if (w.cloudAuthenticated) { await w.leaveCloud(); } else { w.entered = false; await w.persist(); } }, child: Text(w.cloudAuthenticated ? 'Sign out of SHIFT' : 'Leave local workspace')),
      ],
      if (section == 'help') ...[
        const Heading('A little help,\nwhen you need it.', 'SHIFT • Frontend edition 0.2.0'),
        const ExpansionTile(tilePadding: EdgeInsets.zero, title: Text('Does SHIFT publish while closed?'), children: [Padding(padding: EdgeInsets.only(bottom: 16), child: Text('Yes, for approved posts scheduled to connected supported accounts. SHIFT Scheduler checks the queue every minute even when SHIFT is closed. Local planning dates alone do not publish posts. Autonomous AI content creation remains paused.'))]),
        const ExpansionTile(tilePadding: EdgeInsets.zero, title: Text('Where are my drafts?'), children: [Padding(padding: EdgeInsets.only(bottom: 16), child: Text('When signed into SHIFT Cloud, drafts, version history, settings and uploaded draft images sync securely with SHIFT. Offline work remains on this device and must be explicitly imported. A local planning date is not a publishing schedule.'))]),
        const ExpansionTile(tilePadding: EdgeInsets.zero, title: Text('Which accounts can I connect?'), children: [Padding(padding: EdgeInsets.only(bottom: 16), child: Text('Bluesky direct account linking is implemented through a dedicated app password. Instagram, Facebook and other platforms still require OAuth developer credentials and publishing adapters. Postiz integration is preserved for VPS hosting.'))]),
        const SizedBox(height: 20), const Panel(child: Text('Support contact has not been configured. No support message is sent from this edition.')),
        const SizedBox(height: 12), OutlinedButton(onPressed: () => showAboutDialog(context: context, applicationName: 'SHIFT', applicationVersion: '0.2.0', applicationIcon: const Icon(Icons.bolt, size: 40), children: [const Text('Your AI social media manager. Native Flutter frontend for Android and iOS.')]), child: const Text('About SHIFT & licenses')),
      ],
    ]));
  }
}
class PreferenceForm extends ConsumerStatefulWidget {
  const PreferenceForm({super.key,required this.section});
  final String section;
  @override ConsumerState<PreferenceForm> createState()=>_PreferenceFormState();
}
class _PreferenceFormState extends ConsumerState<PreferenceForm> {
  final form=GlobalKey<FormState>();
  final fields=<String,TextEditingController>{};
  String? imagePath;
  bool busy=false;
  Map<String,String> get labels => switch(widget.section) {
    'profile'=>{'name':'Display name','email':'Sign-in email',
      'language':'Preferred language','timezone':'Timezone (e.g. Africa/Lagos)'},
    'brand'=>{'name':'Brand or creator name','description':'Description',
      'niche':'Content niche','audience':'Target audience',
      'market':'Country / primary market','language':'Language',
      'tone':'Writing tone','topics':'Preferred topics',
      'blocked':'Blocked topics','colors':'Brand colors',
      'guidelines':'Brand guidelines'},
    _=>{'style':'Writing style','length':'Preferred content length',
      'language':'Content language','images':'Image preferences',
      'categories':'Research categories','avoid':'Topics to avoid'},
  };
  @override void initState(){
    super.initState();
    final w=ref.read(workspaceProvider);
    final source=widget.section=='profile'?w.profile:
      widget.section=='brand'?w.brand:w.preferences;
    for(final k in labels.keys){fields[k]=TextEditingController(text:source[k]??'');}
    imagePath=source[widget.section=='profile'?'avatar':'logo'];
  }
  @override void dispose(){
    for(final c in fields.values){c.dispose();}
    super.dispose();
  }
  Future<void> chooseImage() async {
    try{
      final image=await ImagePicker().pickImage(source:ImageSource.gallery,
        maxWidth:512,imageQuality:85);
      if(image==null)return;
      if(await image.length()>10*1024*1024){
        if(mounted)toast(context,'Choose an image under 10 MB.');return;
      }
      final dir=await getApplicationDocumentsDirectory();
      final folder=Directory(dir.path+'/shift_identity');
      await folder.create(recursive:true);
      final name=DateTime.now().microsecondsSinceEpoch.toString()+'.jpg';
      final file=File(folder.path+'/'+name);
      await image.saveTo(file.path);
      if(mounted)setState(()=>imagePath=file.path);
    }catch(e){if(mounted)toast(context,'Unable to select image: $e');}
  }
  Future<void> changeEmail() async {
    if(ShiftCloud.user==null)return;
    final email=TextEditingController(text:ShiftCloud.user?.email??'');
    final next=await showDialog<String>(context:context,builder:(dialog)=>
      AlertDialog(
        title:const Text('Change sign-in email'),
        content:TextField(controller:email,
          keyboardType:TextInputType.emailAddress,
          decoration:const InputDecoration(labelText:'New email address')),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(dialog),child:const Text('Cancel')),
          FilledButton(onPressed:()=>Navigator.pop(dialog,email.text.trim()),
            child:const Text('Request verification')),
        ],
      ));
    await Future<void>.delayed(const Duration(milliseconds:250));
    email.dispose();
    if(next==null||next.isEmpty)return;
    if(!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(next)){
      if(mounted)toast(context,'Enter a valid email.');return;
    }
    try{
      await ShiftCloud.client.auth.updateUser(UserAttributes(email:next));
      if(mounted)toast(context,'Email update requested. Verify using the confirmation emails.');
    }catch(e){if(mounted)toast(context,'Email update failed: $e');}
  }
  Future<void> save() async {
    if(!form.currentState!.validate()||busy)return;
    setState(()=>busy=true);
    final w=ref.read(workspaceProvider);
    final values={for(final e in fields.entries)e.key:e.value.text.trim()};
    bool saved=false;
    try{
      if(imagePath!=null&&widget.section!='ai'){
        final k=widget.section=='profile'?'avatar':'logo';
        final previous=widget.section=='profile'?w.profile[k]:w.brand[k];
        values[k]=imagePath!;
        if(w.cloudAuthenticated&&imagePath!=previous){
          final remote=await ShiftCloud.uploadIdentityImage(
            w.cloudWorkspaceId!,File(imagePath!),
            widget.section=='profile'?'avatar':'brand');
          values[widget.section=='profile'?'avatarCloudPath':'logoCloudPath']=remote;
        }
      }
      saved=await w.updateSettings(widget.section,values);
    }catch(e){
      if(mounted)toast(context,'Save failed: $e');
    }finally{
      if(mounted)setState(()=>busy=false);
    }
    if(mounted)toast(context,saved
      ?(w.cloudAuthenticated?'Saved to SHIFT Cloud.':'Saved on this device.')
      :'Save failed. Previous settings were restored.');
  }
  @override Widget build(BuildContext context){
    final cloud=ref.watch(workspaceProvider).cloudAuthenticated;
    return Scaffold(appBar:AppBar(title:Text(
      widget.section=='profile'?'Profile':
      widget.section=='brand'?'Brand identity':'AI preferences')),
      body:PageBody(children:[
        ServiceNotice(text:cloud
          ?'Your settings are saved to your authenticated SHIFT workspace.'
          :'Offline settings are device-only. Sign in for cloud sync.'),
        Form(key:form,child:Column(
          crossAxisAlignment:CrossAxisAlignment.stretch,children:[
            if(widget.section!='ai') ...[
              if(imagePath!=null)Align(child:ClipRRect(
                borderRadius:BorderRadius.circular(30),
                child:Image.file(File(imagePath!),width:72,height:72,
                  fit:BoxFit.cover,errorBuilder:(_,__,___)=>
                    const Icon(Icons.person_outline,size:48)))),
              OutlinedButton.icon(onPressed:chooseImage,
                icon:const Icon(Icons.add_photo_alternate_outlined),
                label:Text(widget.section=='brand'?'Choose logo':'Choose avatar')),
              const SizedBox(height:16),
            ],
            ...labels.entries.map((e)=>Padding(
              padding:const EdgeInsets.only(bottom:16),
              child:TextFormField(controller:fields[e.key],
                readOnly:cloud&&widget.section=='profile'&&e.key=='email',
                maxLines:['description','guidelines','blocked','topics','avoid','images']
                  .contains(e.key)?3:1,
                decoration:InputDecoration(labelText:e.value),
                validator:(v){
                  if(e.key=='name'&&(v?.trim().isEmpty??true))return 'Enter a name';
                  if(e.key=='email'&&v?.isNotEmpty==true&&
                    !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v!))
                    return 'Enter a valid email';
                  if(e.key=='timezone'&&v?.isNotEmpty==true&&
                    !RegExp(r'^[A-Za-z_]+/[A-Za-z_]+(?:/[A-Za-z_]+)?$').hasMatch(v!))
                    return 'Use an IANA timezone, such as Africa/Lagos';
                  return null;
                },
              ))),
            if(widget.section=='profile') ...[
              const Text('Your timezone is synced to SHIFT Cloud. Scheduled UTC times are displayed locally.',
                style:TextStyle(fontSize:12)),
              if(cloud)TextButton.icon(onPressed:changeEmail,
                icon:const Icon(Icons.alternate_email),
                label:const Text('Change account email')),
            ],
            const SizedBox(height:20),
            FilledButton(onPressed:busy?null:save,
              child:Text(busy?'Saving…':'Save preferences')),
          ])),
      ]),
    );
  }
}
class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Social accounts')),
    body: PageBody(children: [
      const Heading('Your presence.\nOne workspace.', 'Manage destinations and prepare official account connections.'),
      const ServiceNotice(
        text: 'SHIFT Scheduler is the current scheduling backend. Postiz is preserved for VPS hosting later. Only verified connected platforms can publish.',
      ),
      const DirectConnectionsPanel(),
      const Section('Social destinations'),
      ...ShiftSocialPlatforms.all.map((platform) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Panel(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text(platform.name,
                  style: Theme.of(context).textTheme.titleMedium)),
              const Icon(Icons.link_off, size: 18),
            ]),
            const SizedBox(height: 6),
            Text(platform.accountRequirement),
            const SizedBox(height: 6),
            Text(platform.integrationLabel,
                style: TextStyle(fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            Text(platform.publishingNote),
            const SizedBox(height: 8),
            Text(platform.id == 'bluesky'
                ? 'Live connection status appears in the SHIFT connections above.'
                : 'Direct OAuth is not yet configured for this provider.',
                style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              OutlinedButton.icon(
                onPressed: () => showPlatformSetup(context, platform),
                icon: const Icon(Icons.settings_outlined, size: 18),
                label: const Text('Connection setup'),
              ),
              TextButton(
                onPressed: () => openPlatformHome(context, platform),
                child: const Text('Open platform'),
              ),
            ]),
          ],
        )),
      )),
      const Section('Manual export'),
      const Text('Copy content from a draft and publish through a platform directly. SHIFT does not mark manual exports as published. Social SDK stays available for direct adapters. Postiz handles authorized account connections and manual scheduling once the server is configured.'),
      const SizedBox(height: 16),
      OutlinedButton(
        onPressed: () => context.push('/drafts'),
        child: const Text('Open draft library'),
      ),
    ]),
  );
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
    const Panel(glass: true, child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.pause_circle_outline), title: Text('AI autopilot paused; manual SHIFT scheduling active'), subtitle: Text('SHIFT Scheduler can publish manually scheduled approved posts to supported accounts. AI autopilot and recurring AI tasks remain paused.'))),
    const SizedBox(height: 16),
    OutlinedButton.icon(onPressed: () async { final w = ref.read(workspaceProvider); w.preferences['paused'] = 'true'; w.record('Local automation pause preference saved', '/automation'); final ok = await w.persist(); if (context.mounted) toast(context, ok ? 'AI autopilot remains paused; manually approved SHIFT schedules are unaffected.' : 'Could not persist pause preference.'); }, icon: const Icon(Icons.pause), label: const Text('Keep automation paused')),
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
  @override ConsumerState<NotificationsScreen> createState()=>_NotificationsState();
}
class _NotificationsState extends ConsumerState<NotificationsScreen> {
  bool activity=false,loading=false;
  String? error;
  List<Map<String,dynamic>> notifications=[];
  @override void initState(){
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_)=>refresh());
  }
  Future<void> refresh() async {
    final w=ref.read(workspaceProvider);
    if(!mounted)return;
    if(!w.cloudAuthenticated){
      setState(()=>notifications=[]);
      return;
    }
    setState((){loading=true;error=null;});
    try{
      final rows=await ShiftCloud.client.from('shift_notifications')
        .select('id,kind,title,body,read_at,created_at,payload')
        .eq('workspace_id',w.cloudWorkspaceId!)
        .order('created_at',ascending:false).limit(100);
      if(mounted)setState(()=>notifications=List<Map<String,dynamic>>.from(rows));
    }catch(e){
      if(mounted)setState(()=>error='Unable to load cloud notifications: $e');
    }finally{
      if(mounted)setState(()=>loading=false);
    }
  }
  Future<void> markRead(Map<String,dynamic> item) async {
    final w=ref.read(workspaceProvider);
    if(!w.cloudAuthenticated||item['read_at']!=null)return;
    try{
      await ShiftCloud.client.from('shift_notifications').update({
        'read_at':DateTime.now().toUtc().toIso8601String()
      }).eq('id',item['id']).eq('workspace_id',w.cloudWorkspaceId!);
      await refresh();
    }catch(e){
      if(mounted)toast(context,'Unable to mark notification as read: $e');
    }
  }
  @override Widget build(BuildContext context){
    final w=ref.watch(workspaceProvider);
    return Scaffold(
      appBar:AppBar(title:const Text('Your updates'),actions:[
        IconButton(tooltip:'Refresh updates',onPressed:loading?null:refresh,
          icon:const Icon(Icons.refresh)),
        IconButton(tooltip:'Notification preferences',
          onPressed:()=>context.push('/settings/notifications'),
          icon:const Icon(Icons.tune)),
      ]),
      body:PageBody(children:[
        SegmentedButton<bool>(segments:const [
          ButtonSegment(value:false,label:Text('Notifications')),
          ButtonSegment(value:true,label:Text('Activity')),
        ],selected:{activity},
          onSelectionChanged:(v)=>setState(()=>activity=v.first)),
        const SizedBox(height:20),
        if(!activity)...[
          ServiceNotice(text:w.cloudAuthenticated
            ?'Notifications are read from SHIFT Cloud. Push delivery is not configured yet.'
            :'Offline workspace • Sign in to see server notifications.'),
          if(loading)const ShiftSkeleton(rows:4),
          ShiftErrorNotice(error,title:'Unable to load notifications'),
          if(!loading&&notifications.isEmpty)
            const Empty('You’re all caught up',
              'No cloud notifications have been received.',
              icon:Icons.notifications_none),
          ...notifications.map((item)=>Padding(
            padding:const EdgeInsets.only(bottom:8),
            child:Panel(child:ListTile(
              contentPadding:EdgeInsets.zero,
              leading:Icon(item['read_at']==null?
                Icons.notifications_active_outlined:Icons.notifications_none),
              title:Text(item['title']?.toString()??'SHIFT update'),
              subtitle:Text(item['body']?.toString()??''),
              trailing:item['read_at']==null
                ?TextButton(onPressed:()=>markRead(item),child:const Text('Mark read'))
                :null,
              onTap:()=>markRead(item),
            )))),
        ]else...[
          ServiceNotice(text:w.cloudAuthenticated
            ?'Current-session activity. Scheduled publishing status is in Calendar.'
            :'Offline activity is kept on this device.'),
          if(w.activity.isEmpty)const Empty('A fresh start',
            'Recent changes will appear here.'),
          ...w.activity.map((a)=>ListTile(
            contentPadding:EdgeInsets.zero,leading:const Icon(Icons.history),
            title:Text(a['title']??'Activity'),
            subtitle:Text(DateFormat.MMMd().add_jm()
              .format(DateTime.parse(a['at']!))),
            trailing:const Icon(Icons.chevron_right),
            onTap:()=>context.push(a['route']!),
          )),
        ],
      ]),
    );
  }
}
