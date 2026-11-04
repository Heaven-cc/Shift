import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/cloud/shift_cloud.dart';
import '../../core/state/workspace.dart';
import '../../core/ui/design.dart';

class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});
  @override ConsumerState<InsightsScreen> createState() => _InsightsState();
}

class _InsightsState extends ConsumerState<InsightsScreen> {
  String period='Last 30 days', platform='All platforms';
  bool loading=false;
  String? error;
  List<Map<String,dynamic>> daily=[];
  Map<String,String> accountProvider={};
  DateTime? refreshedAt;

  @override void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => refresh());
  }

  int get days => period=='Last 7 days'?7:period=='Last 90 days'?90:30;

  Future<void> refresh() async {
    if(!mounted)return;
    final workspace=ref.read(workspaceProvider);
    if(!workspace.cloudAuthenticated || workspace.cloudWorkspaceId==null) {
      setState(() {daily=[];error=null;loading=false;});return;
    }
    setState(() {loading=true;error=null;});
    try {
      final wid=workspace.cloudWorkspaceId!;
      final start=DateTime.now().toUtc().subtract(Duration(days:days-1));
      final fromDate='${start.year.toString().padLeft(4,'0')}-${start.month.toString().padLeft(2,'0')}-${start.day.toString().padLeft(2,'0')}';
      final results=await Future.wait([
        ShiftCloud.client.from('shift_analytics_daily').select()
          .eq('workspace_id',wid).gte('day',fromDate).order('day'),
        ShiftCloud.client.from('shift_social_accounts').select('id,provider')
          .eq('workspace_id',wid),
      ]);
      if(!mounted)return;
      final accounts=<String,String>{};
      for(final row in results[1]) {
        accounts[row['id'] as String]=row['provider'] as String? ?? '';
      }
      setState(() {
        accountProvider=accounts;
        daily=List<Map<String,dynamic>>.from(results[0]);
        refreshedAt=DateTime.now();loading=false;
      });
    } catch (_) {
      if(mounted)setState(() {error='Unable to load provider metrics. Try again.';loading=false;});
    }
  }

  @override Widget build(BuildContext context) {
    final workspace=ref.watch(workspaceProvider);
    final filtered=daily.where((row) {
      if(platform=='All platforms')return true;
      return accountProvider[row['social_account_id'] as String]?.toLowerCase()==platform.toLowerCase();
    }).toList();
    final hasMetrics=filtered.isNotEmpty;
    int sum(String field)=>filtered.fold<int>(0,(sum,row)=>sum+((row[field] as num?)?.toInt()??0));
    String metric(String field)=>hasMetrics?sum(field).toString():'—';
    Widget summary(String value,String label)=>Panel(child:Column(crossAxisAlignment:CrossAxisAlignment.start,
      children:[Text(value,style:const TextStyle(fontSize:23,fontWeight:FontWeight.w700)),Text(label)]));
    return PageBody(children:[
      const Heading('See what resonates.','Actual connected-account results. No invented numbers.'),
      Wrap(spacing:10,runSpacing:8,children:[
        DropdownButton<String>(
          value:period,
          items:['Last 7 days','Last 30 days','Last 90 days']
            .map((s)=>DropdownMenuItem(value:s,child:Text(s))).toList(),
          onChanged:(v){if(v!=null){setState(()=>period=v);refresh();}},
        ),
        DropdownButton<String>(
          value:platform,
          items:['All platforms','Instagram','Facebook']
            .map((s)=>DropdownMenuItem(value:s,child:Text(s))).toList(),
          onChanged:(v){if(v!=null)setState(()=>platform=v);},
        ),
      ]),
      if(!workspace.cloudAuthenticated)
        const ServiceNotice(text:'Sign in to view cloud analytics. Device draft plans do not represent published posts.'),
      if(workspace.cloudAuthenticated && !hasMetrics)
        const ServiceNotice(text:'No provider analytics have been synced. A dash means unavailable, not zero.'),
      if(loading)const LinearProgressIndicator(),
      if(error!=null)Panel(child:Column(children:[
        Text(error!),const SizedBox(height:8),
        OutlinedButton(onPressed:refresh,child:const Text('Retry')),
      ])),
      if(refreshedAt!=null)Text('Last fetched from SHIFT Cloud: ${refreshedAt!.toLocal()}',
        style:const TextStyle(fontSize:12)),
      LayoutBuilder(builder:(c,box)=>Wrap(spacing:12,runSpacing:12,children:[
        ('Impressions',metric('impressions')),
        ('Reach',metric('reach')),
        ('Reactions',metric('reactions')),
        ('Comments',metric('comments')),
        ('Shares',metric('shares')),
        ('Clicks',metric('clicks')),
      ].map((m)=>SizedBox(width:(box.maxWidth-12)/2,child:summary(m.$2,m.$1))).toList())),
      if(hasMetrics) ...[
        const Section('Daily activity'),
        ...filtered.reversed.take(15).map((row)=>ListTile(
          title:Text(row['day'] as String? ?? 'Date unavailable'),
          subtitle:Text('Impressions: ${row['impressions']} • Reach: ${row['reach']}'),
          trailing:Text(accountProvider[row['social_account_id'] as String] ?? 'Account'),
        )),
      ] else ...[
        const Section('Engagement over time'),
        const Empty('No provider data available','Connect an eligible social account and finish the provider analytics sync.',
          icon:Icons.show_chart),
      ],
      const Section('Publishing outcomes'),
      const Text('Only provider-confirmed publications count as published. Planning dates and local approvals are excluded.'),
      const Section('AI recommendations'),
      const Empty('No evidence-backed recommendations yet',
        'Recommendations will appear only after actual provider results are collected.'),
      const SizedBox(height:16),
      FilledButton(onPressed:()=>context.push('/accounts'),child:const Text('Manage social accounts')),
      const SizedBox(height:8),
      OutlinedButton(onPressed:loading?null:refresh,child:const Text('Refresh saved metrics')),
    ]);
  }
}
