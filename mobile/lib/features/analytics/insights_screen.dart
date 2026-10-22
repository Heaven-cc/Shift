import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/ui/design.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});
  @override State<InsightsScreen> createState() => _InsightsState();
}
class _InsightsState extends State<InsightsScreen> {
  String period = 'Last 30 days', platform = 'All platforms';
  @override Widget build(BuildContext context) => PageBody(children: [
    const Heading('See what resonates.', 'Real performance. Better decisions.'),
    Wrap(spacing: 8, runSpacing: 8, children: [
      DropdownButton<String>(value: period, items: ['Last 7 days', 'Last 30 days', 'Last 90 days'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(), onChanged: (v) => setState(() => period = v!)),
      DropdownButton<String>(value: platform, items: ['All platforms', 'Instagram', 'Facebook'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(), onChanged: (v) => setState(() => platform = v!)),
    ]),
    const SizedBox(height: 12), const ServiceNotice(text: 'No account metrics have been received. A dash means unavailable, not zero.'),
    LayoutBuilder(builder: (c, box) => Wrap(spacing: 12, runSpacing: 12, children: ['Published posts', 'Views / impressions', 'Reach', 'Engagement', 'Likes', 'Comments', 'Shares', 'Follower growth'].map((s) => SizedBox(width: (box.maxWidth - 12) / 2, child: Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('—', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700)), Text(s)])))).toList())),
    const Section('Engagement over time'), const Empty('No data to chart', 'Engagement history will use the selected period and available provider metrics.', icon: Icons.show_chart),
    const Section('Publishing frequency'), const Empty('No confirmed publications', 'Local draft plans are excluded from publishing analytics.', icon: Icons.calendar_month_outlined),
    const Section('Top content & platform comparison'), const Empty('Your results belong here', 'Content rankings and format comparisons need real performance records.'),
    const Section('AI recommendations'), const Empty('SHIFT is still learning', 'No personalized recommendations yet. A useful starting point: write for a clear audience and keep a consistent voice.', icon: Icons.auto_awesome_outlined),
    const SizedBox(height: 20),
    FilledButton(onPressed: () => context.push('/accounts'), child: const Text('Manage social accounts')),
    const SizedBox(height: 8), OutlinedButton(onPressed: () => unavailable(context, 'Analytics sync'), child: const Text('Sync metrics')),
  ]);
}
