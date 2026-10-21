import 'package:flutter/material.dart';

class ShiftFeatureHub extends StatefulWidget {
  const ShiftFeatureHub({super.key});
  @override State<ShiftFeatureHub> createState()=>_ShiftFeatureHubState();
}
class _ShiftFeatureHubState extends State<ShiftFeatureHub> {
  int tab=0;
  final List<Map<String,String>> approvals=[
    {'title':'How creativity grows','platform':'Instagram','reason':'Requires manual approval'},
    {'title':'Ask your community','platform':'Facebook','reason':'Requires manual approval'},
  ];
  final List<Map<String,String>> notifications=[
    {'title':'Welcome to SHIFT','detail':'Your mobile workspace is ready for setup.'},
    {'title':'Connect a social account','detail':'Publishing will remain disabled until authorized.'},
  ];
  final brandName=TextEditingController();
  final voice=TextEditingController();
  final audience=TextEditingController();
  bool autoPublish=false;
  bool notifyApprovals=true;
  bool notifyFailures=true;
  @override void dispose(){brandName.dispose();voice.dispose();audience.dispose();super.dispose();}
  void toast(String text)=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(text)));
  Widget panel(Widget child)=>Card(margin:const EdgeInsets.only(bottom:13),elevation:0,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(22),side:BorderSide(color:Theme.of(context).dividerColor.withValues(alpha:.2))),child:Padding(padding:const EdgeInsets.all(18),child:child));
  Widget info(String title,String body)=>panel(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontWeight:FontWeight.w800,fontSize:17)),const SizedBox(height:8),Text(body,style:TextStyle(fontSize:13,color:Theme.of(context).colorScheme.onSurfaceVariant))]));
  Widget approvalsPage()=>Column(children:[
    info('Approval inbox','Review drafts before publication. These are sample items, not real pending social posts.'),
    ...approvals.map((p)=>panel(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(p['title']!,style:const TextStyle(fontWeight:FontWeight.w700)),
      const SizedBox(height:7),Text("${p['platform']} · ${p['reason']}",style:const TextStyle(fontSize:12)),
      const SizedBox(height:14),
      Wrap(spacing:9,children:[
        FilledButton(onPressed:()=>setState(()=>approvals.remove(p)),child:const Text('Approve demo')),
        OutlinedButton(onPressed:()=>setState(()=>approvals.remove(p)),child:const Text('Reject demo')),
      ]),
    ]))),
    if(approvals.isEmpty)info('All caught up','There are no sample approvals remaining.'),
  ]);
  Widget accountsPage()=>Column(children:[
    info('Account connections','Official OAuth connections will be enabled when SHIFT cloud services are configured. Never enter social passwords in this preview.'),
    ...[('Instagram',Icons.camera_alt_outlined),('Facebook',Icons.people_outline),('X',Icons.alternate_email),('TikTok',Icons.music_note_outlined)].map((p)=>panel(ListTile(contentPadding:EdgeInsets.zero,leading:Icon(p.$2),title:Text(p.$1),subtitle:const Text('Not connected'),trailing:const Icon(Icons.add_circle_outline),onTap:()=>toast('OAuth connection not configured yet.')))),
  ]);
  Widget brandPage()=>Column(children:[
    info('Brand voice','Define the style and audience for future AI-assisted content.'),
    panel(Column(children:[
      TextField(controller:brandName,decoration:const InputDecoration(labelText:'Brand name',border:OutlineInputBorder())),
      const SizedBox(height:13),
      TextField(controller:voice,maxLines:3,decoration:const InputDecoration(labelText:'Brand voice',hintText:'Confident, helpful, conversational...',border:OutlineInputBorder())),
      const SizedBox(height:13),
      TextField(controller:audience,maxLines:2,decoration:const InputDecoration(labelText:'Target audience',border:OutlineInputBorder())),
      const SizedBox(height:15),
      FilledButton(onPressed:()=>toast('Brand settings are session-only until Supabase is connected.'),child:const Text('Save brand profile')),
    ])),
  ]);
  Widget automationPage()=>Column(children:[
    info('Publishing controls','SHIFT uses approval-first onboarding. Autonomous publishing requires explicit authorization and cloud jobs. This screen does not enable real publishing.'),
    panel(Column(children:[
      SwitchListTile(title:const Text('Trusted auto-publishing'),subtitle:const Text('Demo preference only; publishing remains disabled'),value:autoPublish,onChanged:(v)=>setState(()=>autoPublish=v)),
      SwitchListTile(title:const Text('Approval reminders'),value:notifyApprovals,onChanged:(v)=>setState(()=>notifyApprovals=v)),
      SwitchListTile(title:const Text('Publishing failure alerts'),value:notifyFailures,onChanged:(v)=>setState(()=>notifyFailures=v)),
      const Divider(),
      const ListTile(contentPadding:EdgeInsets.zero,leading:Icon(Icons.schedule_outlined),title:Text('Recommended posting times'),subtitle:Text('Available after analytics and scheduling are connected')),
    ])),
  ]);
  Widget alertsPage()=>Column(children:[
    info('Activity and notifications','This inbox contains example notifications. Push notifications are not configured.'),
    ...notifications.map((n)=>panel(ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.notifications_none),title:Text(n['title']!),subtitle:Text(n['detail']!)))),
  ]);
  @override Widget build(BuildContext context){
    final titles=['Approvals','Accounts','Brand','Automation','Notifications'];
    final icons=[Icons.fact_check_outlined,Icons.link_outlined,Icons.palette_outlined,Icons.bolt_outlined,Icons.notifications_outlined];
    final screens=[approvalsPage,accountsPage,brandPage,automationPage,alertsPage];
    return Scaffold(appBar:AppBar(title:const Text('SHIFT workspace',style:TextStyle(fontWeight:FontWeight.w800))),body:SafeArea(child:ListView(padding:const EdgeInsets.all(17),children:[
      Text(titles[tab],style:const TextStyle(fontSize:30,fontWeight:FontWeight.w800)),
      const SizedBox(height:15),
      SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:List.generate(titles.length,(i)=>Padding(padding:const EdgeInsets.only(right:8),child:ChoiceChip(label:Text(titles[i]),avatar:Icon(icons[i],size:17),selected:tab==i,onSelected:(_)=>setState(()=>tab=i)))))),
      const SizedBox(height:19),
      screens[tab](),
    ]))));
  }
}
