import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/state/workspace.dart';
import '../../core/ui/design.dart';
import '../content/post_screen.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});
  @override ConsumerState<CalendarScreen> createState() => _CalendarState();
}
class _CalendarState extends ConsumerState<CalendarScreen> {
  DateTime selected = DateUtils.dateOnly(DateTime.now());
  String view = 'Month', status = 'All';
  void move(int by) => setState(() {
    selected = view == 'Month' ? DateTime(selected.year, selected.month + by, 1) : selected.add(Duration(days: (view == 'Week' ? 7 : 1) * by));
  });
  @override Widget build(BuildContext context) {
    final w = ref.watch(workspaceProvider);
    final planned = w.posts.where((p) => p.plannedAt != null && (status == 'All' || p.status.name == status)).toList()..sort((a, b) => a.plannedAt!.compareTo(b.plannedAt!));
    final start = selected.subtract(Duration(days: selected.weekday - 1));
    final visible = planned.where((p) {
      final d = DateUtils.dateOnly(p.plannedAt!);
      return view == 'List' || (view == 'Month' && d.year == selected.year && d.month == selected.month) || (view == 'Week' && !d.isBefore(start) && d.isBefore(start.add(const Duration(days: 7)))) || (view == 'Day' && DateUtils.isSameDay(d, selected));
    }).toList();
    return PageBody(children: [
      const Heading('Give your ideas\na place in time.', 'A clear view of your content plan.'),
      const ServiceNotice(text: 'Local planning only • Server schedules and publishing are unavailable'),
      Wrap(spacing: 8, children: ['Month', 'Week', 'Day', 'List'].map((s) => ChoiceChip(label: Text(s), selected: view == s, onSelected: (_) => setState(() => view = s))).toList()),
      Row(children: [
        IconButton(tooltip: 'Previous period', onPressed: () => move(-1), icon: const Icon(Icons.chevron_left)),
        Expanded(child: TextButton(onPressed: () async { final d = await showDatePicker(context: context, initialDate: selected, firstDate: DateTime(2020), lastDate: DateTime(2100)); if (d != null) setState(() => selected = d); }, child: Text(DateFormat(view == 'Month' ? 'MMMM yyyy' : 'MMM d, yyyy').format(selected)))),
        IconButton(tooltip: 'Next period', onPressed: () => move(1), icon: const Icon(Icons.chevron_right)),
        TextButton(onPressed: () => setState(() => selected = DateUtils.dateOnly(DateTime.now())), child: const Text('Today')),
      ]),
      if (view == 'Month') Panel(child: Column(children: [
        Row(children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((s) => Expanded(child: Center(child: Text(s, style: const TextStyle(fontSize: 12))))).toList()),
        const SizedBox(height: 12),
        GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, childAspectRatio: .85), itemCount: DateTime(selected.year, selected.month, 1).weekday - 1 + DateUtils.getDaysInMonth(selected.year, selected.month), itemBuilder: (c, index) {
          final day = index - DateTime(selected.year, selected.month, 1).weekday + 2;
          if (day < 1) return const SizedBox.shrink();
          final date = DateTime(selected.year, selected.month, day);
          final count = planned.where((p) => DateUtils.isSameDay(p.plannedAt, date)).length;
          return InkWell(borderRadius: BorderRadius.circular(12), onTap: () => setState(() { selected = date; view = 'Day'; }), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('$day', style: TextStyle(fontWeight: DateUtils.isSameDay(date, DateTime.now()) ? FontWeight.w900 : FontWeight.normal)),
            Text(count == 0 ? ' ' : '•', semanticsLabel: '$count local plans', style: const TextStyle(fontSize: 14)),
          ]));
        }),
      ])),
      if (view == 'Week') SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: List.generate(7, (i) { final d = start.add(Duration(days: i)); return Padding(padding: const EdgeInsets.only(right: 8), child: ActionChip(label: Text(DateFormat('E d').format(d)), onPressed: () => setState(() { selected = d; view = 'Day'; }))); }))),
      const Section('Content in this view'),
      DropdownButton<String>(value: status, isExpanded: true, items: ['All', 'draft', 'pendingApproval', 'approved', 'scheduled', 'publishing', 'published', 'failed', 'canceled'].map((s) => DropdownMenuItem(value: s, child: Text(s == 'All' ? 'All statuses' : s))).toList(), onChanged: (v) => setState(() => status = v!)),
      if (visible.isEmpty) Empty('A little breathing room', 'No local plans in this view. Add a planning date from any saved draft.', icon: Icons.event_note_outlined, action: OutlinedButton(onPressed: () => context.push('/drafts'), child: const Text('Open drafts'))),
      ...visible.map((p) => PostTile(post: p)),
      const Section('Schedule preferences'),
      OutlinedButton(onPressed: () => context.push('/automation'), child: const Text('Weekly targets & posting windows')),
      TextButton(onPressed: () => unavailable(context, 'AI content planning and recommended times'), child: const Text('Ask SHIFT for a content plan')),
    ]);
  }
}
