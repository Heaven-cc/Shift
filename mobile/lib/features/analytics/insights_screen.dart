import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/ui/design.dart';
import '../../core/social/social_platforms.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});
  @override State<InsightsScreen> createState() => _InsightsState();
}
class _InsightsState extends State<InsightsScreen> {
  String period = 'Last 30 days', platform = 'All platforms';
  @override Widget build(BuildContext context) => PageBody(children: [
    const Heading('Understand your impact.', 'A clear view of what is working and where to go next.'),
    Panel(glass: true, padding: const EdgeInsets.all(16), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('PERFORMANCE OVERVIEW', style: Theme.of(context).textTheme.labelSmall?.copyWith(letterSpacing: 1.2, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: DropdownButtonFormField<String>(value: period, isExpanded: true,
            decoration: const InputDecoration(labelText: 'Period'),
            items: ['Last 7 days', 'Last 30 days', 'Last 90 days'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: (v) => setState(() => period = v!))),
          const SizedBox(width: 10),
          Expanded(child: DropdownButtonFormField<String>(value: platform, isExpanded: true,
            decoration: const InputDecoration(labelText: 'Platform'),
            items: ['All platforms', ...ShiftSocialPlatforms.names].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: (v) => setState(() => platform = v!))),
        ]),
      ])),
    const SizedBox(height: 10),
    const ServiceNotice(text: 'No account metrics have been received yet. A dash means unavailable, not zero.'),
    const Section('Your key metrics'),
    GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.65,
      children: ['Published posts', 'Views / impressions', 'Reach', 'Engagement', 'Likes', 'Comments', 'Shares', 'Follower growth'].map((label) =>
        Panel(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Icon(Icons.insights_outlined, size: 18, color: Theme.of(context).colorScheme.primary),
            const Text('—', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800, height: 1)),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ]))).toList()),
    const Section('Performance over time'),
    const Empty('No performance data yet', 'Engagement history will appear here when connected platforms return real metrics for the selected period.', icon: Icons.show_chart_rounded),
    const Section('Publishing consistency'),
    const Empty('Your publishing rhythm', 'Confirmed publications will be compared with your content plan. Local draft dates are not counted as published posts.', icon: Icons.calendar_month_outlined),
    const Section('Top content'),
    const Empty('Your best-performing posts', 'Content rankings need real performance records from your connected accounts.'),
    const Section('Recommendations'),
    const Empty('Insights will grow with your data', 'SHIFT will use your actual content and account performance to identify useful next steps. No recommendations are fabricated.', icon: Icons.auto_awesome_outlined),
    const SizedBox(height: 16),
    FilledButton.icon(onPressed: () => context.push('/accounts'), icon: const Icon(Icons.link_rounded), label: const Text('Manage social accounts')),
    OutlinedButton(onPressed: () => unavailable(context, 'Analytics sync'), child: const Text('Sync metrics')),
  ]);
}
