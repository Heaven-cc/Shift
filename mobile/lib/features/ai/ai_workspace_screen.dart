import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/cloud/shift_cloud.dart';
import '../../core/state/workspace.dart';
import '../../core/ui/design.dart';

class AiWorkspaceScreen extends ConsumerStatefulWidget {
  const AiWorkspaceScreen({super.key});
  @override ConsumerState<AiWorkspaceScreen> createState()=>_AiState();
}
class _AiState extends ConsumerState<AiWorkspaceScreen>{
  static const modes=<String,String>{
    'research':'Live research','competitors':'Competitor research',
    'analyze':'Analyze sources','ideas':'Content ideas',
    'strategy':'Content strategy','calendar':'Content calendar',
    'improve':'Improve content'};
  final prompt=TextEditingController();
  bool loading=false,configured=false,research=false;
  String mode='research',message='',provider='';
  Map<String,dynamic>? output;
  List<Map<String,dynamic>> plans=[],history=[];
  @override void initState(){super.initState();WidgetsBinding.instance.addPostFrameCallback((_)=>refresh());}
  @override void dispose(){prompt.dispose();super.dispose();}
  Future<Map<String,dynamic>> action(String operation,[Map<String,dynamic> extra=const {}])async{
    final r=await ShiftCloud.client.functions.invoke('shift-ai',
      body:<String,dynamic>{'action':operation,...extra});
    if(r.data is! Map)throw StateError('Invalid AI response');
    final data=Map<String,dynamic>.from(r.data as Map);
    if(data['error']!=null)throw StateError(data['error'].toString());
    return data;
  }
  Future<void> refresh()async{
    if(!mounted||!ref.read(workspaceProvider).cloudAuthenticated)return;
    setState(()=>loading=true);
    try{
      final res=await Future.wait([action('status'),action('history'),action('plan_items')]);
      if(!mounted)return;
      setState((){
        configured=res[0]['configured']==true;
        research=res[0]['researchAvailable']==true;
        provider=(res[0]['provider']??'Not configured').toString()+' • '+
          (res[0]['model']??'').toString();
        history=(res[1]['history'] as List? ?? const [])
          .map((x)=>Map<String,dynamic>.from(x as Map)).toList();
        plans=(res[2]['items'] as List? ?? const [])
          .map((x)=>Map<String,dynamic>.from(x as Map)).toList();
        message='';
      });
    }catch(e){if(mounted)setState(()=>message=e.toString());}
    finally{if(mounted)setState(()=>loading=false);}
  }
  Future<void> run()async{
    if(prompt.text.trim().length<5){toast(context,'Enter instructions first.');return;}
    setState((){loading=true;message='';});
    try{
      final res=await action('run',{'mode':mode,'prompt':prompt.text.trim(),
        'requestKey':'shift-workspace-'+DateTime.now().microsecondsSinceEpoch.toString()});
      if(res['status']!='completed'||res['result'] is! Map)throw StateError('Request did not complete');
      if(mounted)setState(()=>output=Map<String,dynamic>.from(res['result'] as Map));
      await refresh();
    }catch(e){if(mounted)setState(()=>message=e.toString());}
    finally{if(mounted)setState(()=>loading=false);}
  }
  Future<void> accept(Map<String,dynamic> p)async{
    final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(
      title:const Text('Save calendar draft?'),
      content:Text((p['title']??'AI suggestion').toString()+
        '\n\nCreates an unapproved cloud draft. Does not schedule or publish.'),
      actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancel')),
      FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Save draft'))]))??false;
    if(!ok||!mounted)return;
    setState(()=>loading=true);
    try{await action('accept_plan',{'itemId':p['id']});
      await ref.read(workspaceProvider).openCloud();await refresh();
      if(mounted)toast(context,'Saved as an unapproved cloud draft.');
    }catch(e){if(mounted)setState(()=>message=e.toString());}
    finally{if(mounted)setState(()=>loading=false);}
  }
  Widget section(String label,dynamic data){
    if(data is! List||data.isEmpty)return const SizedBox.shrink();
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const SizedBox(height:12),
      Text(label,style:Theme.of(context).textTheme.titleMedium),
      ...data.map((x)=>Padding(padding:const EdgeInsets.only(top:6),
        child:SelectableText('• '+x.toString()))),
    ]);
  }
  @override Widget build(BuildContext context){
    final w=ref.watch(workspaceProvider);
    return Scaffold(appBar:AppBar(title:const Text('SHIFT AI Workspace'),
      actions:[IconButton(onPressed:loading?null:refresh,
        tooltip:'Refresh status',icon:const Icon(Icons.refresh))]),
      body:PageBody(children:[
        const Heading('Research. Plan. Create.',
          'AI uses your saved brand identity and requires approval for drafts.'),
        if(!w.cloudAuthenticated)...[
          const Empty('Sign in required','Sign in to use secure AI and save research online.'),
          FilledButton(onPressed:()=>context.push('/auth'),child:const Text('Sign in')),
        ]else ...[
          Panel(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(configured?'AI provider configured':'AI provider not configured',
              style:Theme.of(context).textTheme.titleMedium),
            const SizedBox(height:6),
            Text(configured?provider:'Add SHIFT_AI_PROVIDER, SHIFT_AI_MODEL and SHIFT_AI_API_KEY in Supabase Edge Function secrets.'),
            const SizedBox(height:6),
            Text(research?'Live research available':
              'For live research configure Brave Search or OpenAI native web search.',
              style:const TextStyle(fontSize:12)),
          ])),
          const Section('AI request'),
          DropdownButtonFormField<String>(
            value:mode,decoration:const InputDecoration(labelText:'Task'),
            items:modes.entries.map((v)=>DropdownMenuItem(
              value:v.key,child:Text(v.value))).toList(),
            onChanged:loading?null:(v)=>setState(()=>mode=v??'research')),
          const SizedBox(height:12),
          TextField(controller:prompt,maxLines:4,
            decoration:const InputDecoration(labelText:'Instructions',
              hintText:'Research my niche and suggest content opportunities')),
          const SizedBox(height:12),
          FilledButton.icon(onPressed:loading||!configured?null:run,
            icon:const Icon(Icons.auto_awesome),
            label:const Text('Run SHIFT AI')),
          if(loading)const LinearProgressIndicator(),
          if(message.isNotEmpty)Text(message,
            style:TextStyle(color:Theme.of(context).colorScheme.error)),
          if(output!=null)...[
            const Section('Latest result'),
            Panel(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              SelectableText((output!['summary']??'').toString()),
              section('Findings',output!['findings']),
              section('Ideas',output!['ideas']),
              section('Recommendations',output!['recommendations']),
              section('Content pillars',output!['pillars']),
              section('Source references',(output!['sources'] as List? ?? const [])
                .map((v)=>v is Map?(v['title'].toString()+' — '+v['url'].toString()):v)
                .toList()),
              const SizedBox(height:12),
              const Text('AI findings are suggestions; verify claims and sources.',
                style:TextStyle(fontSize:12)),
            ])),
          ],
          const Section('Cloud calendar proposals'),
          const Text('Accepting a proposal creates an unapproved draft and a planning date, not a publishing job.'),
          if(plans.isEmpty)const Empty('No proposals','Run the Content calendar task first.'),
          ...plans.map((p)=>Panel(child:ListTile(
            contentPadding:EdgeInsets.zero,
            title:Text((p['title']??'Draft').toString()),
            subtitle:Text((p['platform']??'').toString()+' • '+
              (p['planned_at']??'').toString()+'\n'+(p['state']??'').toString()),
            isThreeLine:true,
            trailing:p['state']=='proposed'
              ?OutlinedButton(onPressed:loading?null:()=>accept(p),
                 child:const Text('Add draft'))
              :const Icon(Icons.check_circle_outline),
          ))),
          const Section('Cloud AI history'),
          ...history.map((h)=>ListTile(
            title:Text('AI job • '+(h['status']??'').toString()),
            subtitle:Text((h['created_at']??'').toString()),
            onTap:(){if(h['result'] is Map)setState(()=>
              output=Map<String,dynamic>.from(h['result'] as Map));},
          )),
        ],
      ]));
  }
}
