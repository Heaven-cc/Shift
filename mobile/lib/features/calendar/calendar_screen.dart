import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/state/workspace.dart';
import '../../core/ui/design.dart';
import '../../core/social/direct_bridge.dart';
import '../content/post_screen.dart';

/// Both the content plan and provider-accepted schedules are visible here.
/// A planning date is not a publishing job and is never represented as one.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});
  @override ConsumerState<CalendarScreen> createState() => _CalendarState();
}

class _CalendarState extends ConsumerState<CalendarScreen> {
  DateTime selected = DateUtils.dateOnly(DateTime.now());
  String view = 'Month', status = 'All';
  bool loading = false;
  String? error;
  List<Map<String, dynamic>> cloudJobs = const [];

  @override void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => refresh());
  }

  Future<void> refresh() async {
    if (!mounted) return;
    final w = ref.read(workspaceProvider);
    if (!w.cloudAuthenticated) {
      setState(() { cloudJobs = []; error = null; loading = false; });
      return;
    }
    setState(() { loading = true; error = null; });
    try {
      final result = await ShiftDirectBridge.call('jobs');
      final loaded = (result['jobs'] as List? ?? const [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList(growable: false);
      if (mounted) setState(() => cloudJobs = loaded);
    } catch (e) {
      if (mounted) setState(() =>
          error = e.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  DateTime? scheduledAt(Map<String, dynamic> job) =>
      DateTime.tryParse(job['scheduled_for']?.toString() ?? '')?.toLocal();

  bool visibleDate(DateTime date) {
    final start = selected.subtract(Duration(days: selected.weekday - 1));
    return view == 'List' ||
        (view == 'Month' && date.year == selected.year && date.month == selected.month) ||
        (view == 'Week' && !date.isBefore(start) &&
            date.isBefore(start.add(const Duration(days: 7)))) ||
        (view == 'Day' && DateUtils.isSameDay(date, selected));
  }

  void move(int by) => setState(() {
    selected = view == 'Month'
        ? DateTime(selected.year, selected.month + by, 1)
        : selected.add(Duration(days: (view == 'Week' ? 7 : 1) * by));
  });

  Future<DateTime?> chooseFutureTime(DateTime initial) async {
    final now = DateTime.now();
    final initialDate = initial.isAfter(now)
        ? initial : now.add(const Duration(days: 1));
    final date = await showDatePicker(
      context: context, initialDate: initialDate,
      firstDate: DateUtils.dateOnly(now),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
    );
    if (time == null || !mounted) return null;
    final result = DateTime(date.year, date.month, date.day,
        time.hour, time.minute);
    if (!result.isAfter(DateTime.now().add(const Duration(minutes: 1)))) {
      toast(context, 'Choose a future time at least one minute away.');
      return null;
    }
    return result;
  }

  Future<void> reschedule(Map<String, dynamic> job) async {
    final previous = scheduledAt(job) ?? DateTime.now();
    final next = await chooseFutureTime(previous);
    if (next == null || !mounted) return;
    final confirmed = await confirm(context, 'Reschedule post?',
      'Change the publishing time to ${DateFormat.yMMMd().add_jm().format(next)}?'
      '\nOnly jobs still queued can be rescheduled.',
      action: 'Reschedule');
    if (!confirmed || !mounted) return;
    try {
      await ShiftDirectBridge.call('reschedule', {
        'jobId': job['id'],
        'scheduledAt': next.toUtc().toIso8601String(),
      });
      await refresh();
      if (mounted) toast(context, 'Publishing time updated in Supabase.');
    } catch (e) {
      if (mounted) toast(context, 'Could not reschedule: $e');
    }
  }

  Future<void> cancel(Map<String, dynamic> job) async {
    final confirmed = await confirm(
      context, 'Cancel scheduled publishing?',
      'This prevents the queued Supabase job from publishing.'
      ' Your approved post is retained for future use.',
      action: 'Cancel schedule',
    );
    if (!confirmed || !mounted) return;
    try {
      await ShiftDirectBridge.call('cancel', {'jobId': job['id']});
      await refresh();
      if (mounted) toast(context, 'Publishing schedule canceled.');
    } catch (e) {
      if (mounted) toast(context, 'Could not cancel: $e');
    }
  }

  Widget cloudTile(Map<String, dynamic> job) {
    final time = scheduledAt(job);
    final state = job['state']?.toString() ?? 'unknown';
    final queued = state == 'queued';
    final clientId = job['clientId']?.toString();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Panel(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.cloud_done_outlined, size: 19),
            const SizedBox(width: 8),
            Expanded(child: Text(job['title']?.toString() ?? 'Scheduled post',
              style: Theme.of(context).textTheme.titleMedium)),
          ]),
          const SizedBox(height: 6),
          Text('${job['accountHandle'] ?? 'Social account'} • ${job['platform'] ?? 'Platform'}'),
          const SizedBox(height: 6),
          Text(time == null ? 'Time unavailable'
            : DateFormat.yMMMd().add_jm().format(time)),
          const SizedBox(height: 6),
          Text('Publishing status: $state',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          if (state == 'unknown')
            const Text('Outcome uncertain. Check the provider before attempting again.'),
          if (job['error_code'] != null)
            Text('Status detail: ${job['error_code']}',
              style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            if (clientId != null && clientId.isNotEmpty)
              TextButton(onPressed: () => context.push('/post/$clientId'),
                child: const Text('Open post')),
            if (queued) OutlinedButton.icon(
              onPressed: () => reschedule(job),
              icon: const Icon(Icons.edit_calendar_outlined),
              label: const Text('Reschedule'),
            ),
            if (queued) TextButton(
              onPressed: () => cancel(job),
              child: const Text('Cancel schedule'),
            ),
          ]),
        ],
      )),
    );
  }

  @override Widget build(BuildContext context) {
    final w = ref.watch(workspaceProvider);
    final planned = w.posts.where((p) => p.plannedAt != null &&
      (status == 'All' || p.status.name == status)).toList()
      ..sort((a,b) => a.plannedAt!.compareTo(b.plannedAt!));
    final visiblePlans = planned.where((p) => visibleDate(p.plannedAt!)).toList();
    final currentJobs = (w.cloudAuthenticated ? cloudJobs : <Map<String,dynamic>>[])
      .where((j) => scheduledAt(j) != null &&
        visibleDate(scheduledAt(j)!) &&
        (status == 'All' || j['state'] == status))
      .toList()
      ..sort((a,b) => scheduledAt(a)!.compareTo(scheduledAt(b)!));
    final start = selected.subtract(Duration(days: selected.weekday - 1));
    return PageBody(children: [
      const Heading('Your content calendar.', 'Plans, scheduled posts and publishing status in one place.'),
      ServiceNotice(text: w.cloudAuthenticated
        ? 'Cloud scheduling: Supabase Cron is active. Only scheduled jobs in the cloud queue will publish; planning dates are reminders.'
        : 'Offline workspace: plans stay on this device. Sign in to use cloud scheduling.'),
      Row(children: [
        const Expanded(child: Text('Publishing queue')),
        IconButton(onPressed: loading ? null : refresh,
          tooltip: 'Refresh server schedules', icon: const Icon(Icons.refresh)),
      ]),
      if (loading) const LinearProgressIndicator(),
      if (error != null) Padding(padding: const EdgeInsets.only(bottom: 12),
        child: Text('Unable to load server schedules: $error',
          style: TextStyle(color: Theme.of(context).colorScheme.error))),
      Wrap(spacing: 8, runSpacing: 8, children: ['Month','Week','Day','List']
        .map((s) => ChoiceChip(label: Text(s),
          selected: view == s, onSelected: (_) => setState(() => view = s))).toList()),
      Row(children: [
        IconButton(tooltip: 'Previous period', onPressed: () => move(-1),
          icon: const Icon(Icons.chevron_left)),
        Expanded(child: TextButton(onPressed: () async {
          final d = await showDatePicker(context: context,
            initialDate: selected, firstDate: DateTime(2020),lastDate: DateTime(2100));
          if (d != null) setState(() => selected = d);
        }, child: Text(DateFormat(view == 'Month' ? 'MMMM yyyy' : 'MMM d, yyyy').format(selected)))),
        IconButton(tooltip: 'Next period', onPressed: () => move(1),
          icon: const Icon(Icons.chevron_right)),
        TextButton(onPressed: () => setState(
          () => selected = DateUtils.dateOnly(DateTime.now())),
          child: const Text('Today')),
      ]),
      if (view == 'Month') Panel(child: Column(children: [
        Row(children: ['M','T','W','T','F','S','S']
          .map((label) => Expanded(child: Center(child:
            Text(label, style: const TextStyle(fontSize: 12))))).toList()),
        const SizedBox(height: 12),
        GridView.builder(shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,childAspectRatio: .85),
          itemCount: DateTime(selected.year,selected.month,1).weekday - 1
            + DateUtils.getDaysInMonth(selected.year,selected.month),
          itemBuilder: (c,i) {
            final day = i - DateTime(selected.year,selected.month,1).weekday + 2;
            if (day < 1) return const SizedBox.shrink();
            final date=DateTime(selected.year,selected.month,day);
            final count=planned.where((p)=>DateUtils.isSameDay(p.plannedAt,date)).length
                + (w.cloudAuthenticated ? cloudJobs.where(
                  (j)=>DateUtils.isSameDay(scheduledAt(j),date)).length : 0);
            return InkWell(borderRadius:BorderRadius.circular(12),
              onTap:()=>setState((){selected=date;view='Day';}),
              child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
                Text('$day',style:TextStyle(fontWeight:
                  DateUtils.isSameDay(date,DateTime.now())
                    ? FontWeight.w900:FontWeight.normal)),
                Text(count==0?' ':'•',semanticsLabel:'$count entries',
                  style:const TextStyle(fontSize:14)),
              ]));
          },
        ),
      ])),
      if (view=='Week') SingleChildScrollView(scrollDirection:Axis.horizontal,
        child:Row(children:List.generate(7,(i){
          final d=start.add(Duration(days:i));
          return Padding(padding:const EdgeInsets.only(right:8),
            child:ActionChip(label:Text(DateFormat('E d').format(d)),
              onPressed:()=>setState((){selected=d;view='Day';})));
        }))),
      const Section('Publishing schedules'),
      DropdownButton<String>(value:status,isExpanded:true,
        items:['All','draft','pendingApproval','approved','queued','processing',
          'published','failed','unknown','canceled']
          .map((s)=>DropdownMenuItem(value:s,child:Text(s=='All'?'All statuses':s)))
          .toList(),onChanged:(v)=>setState(()=>status=v!)),
      if (currentJobs.isEmpty)
        const Text('No confirmed server schedules for this view.'),
      ...currentJobs.map(cloudTile),
      const Section('Content plans'),
      if (visiblePlans.isEmpty) Empty('No content plans in this view',
        'Choose a planning date from a saved draft, or create a new post.',
        icon:Icons.event_note_outlined,
        action:OutlinedButton(onPressed:()=>context.push('/drafts'),
          child:const Text('Open drafts'))),
      ...visiblePlans.map((p)=>PostTile(post:p)),
      const Section('Next steps'),
      Wrap(spacing:8,runSpacing:8,children:[
        FilledButton(onPressed:()=>context.go('/create'),
          child:const Text('Create post')),
        OutlinedButton(onPressed:()=>context.push('/drafts'),
          child:const Text('Schedule approved post')),
        OutlinedButton(onPressed:()=>context.push('/automation'),
          child:const Text('Publishing preferences')),
      ]),
      const Text('Manual cloud scheduling currently supports connected Bluesky text accounts. Other platforms require verified API integration.',
        style:TextStyle(fontSize:12)),
    ]);
  }
}
