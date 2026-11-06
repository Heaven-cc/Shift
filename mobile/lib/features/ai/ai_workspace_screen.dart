import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/cloud/shift_cloud.dart';
import '../../core/state/workspace.dart';
import '../../core/ui/design.dart';

/// One AI surface; only the backend selects NVIDIA specialists.
class AiWorkspaceScreen extends ConsumerStatefulWidget {
  const AiWorkspaceScreen({super.key});
  @override ConsumerState<AiWorkspaceScreen> createState()=>_AiState();
}
class _AiState extends ConsumerState<AiWorkspaceScreen>{
  final prompt=TextEditingController();
  bool loading=false,running=false,knowledgeBusy=false;
  String? sourcePath;
  String message='',progress='';
  Map<String,dynamic> capabilities={};
  Map<String,dynamic>? result;
  List<Map<String,dynamic>> history=[],plans=[],mediaHistory=[];
  @override void initState(){
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_)=>refresh());
  }
  @override void dispose(){prompt.dispose();super.dispose();}
  String readable(Object error){
    final text=error.toString().toLowerCase();
    if(networkError(error))return 'Cannot reach SHIFT Cloud. Check your connection. '
      'Your saved task can be reopened without submitting it again.';
    if(text.contains('provider_timeout'))return
      'The NVIDIA text model timed out. Its configuration has not been changed.';
    if(text.contains('provider_credentials_rejected'))return
      'NVIDIA rejected its credentials or the model is not available for the account.';
    if(text.contains('provider_model_or_request_invalid'))return
      'NVIDIA rejected the model or its request format.';
    if(text.contains('provider_rate_limited'))return 'NVIDIA rate limit reached.';
    if(text.contains('research_provider_not_configured'))return
      'Live research needs a configured search service in SHIFT Supabase.';
    if(text.contains('capability_not_configured')||
       text.contains('text_not_configured'))return
      'The requested AI capability is not configured yet.';
    return error.toString().replaceFirst('Bad state: ','');
  }
  bool networkError(Object error){
    final s=error.toString().toLowerCase();
    return s.contains('socketexception')||s.contains('failed host lookup')||
      s.contains('functionsfetch')||s.contains('connection reset')||
      s.contains('network is unreachable')||s.contains('connection timed out');
  }
  Future<Map<String,dynamic>> call(String action,
      [Map<String,dynamic> options=const {}])async{
    final response=await ShiftCloud.client.functions.invoke('shift-unified',
      body:<String,dynamic>{'action':action,...options});
    if(response.data is! Map)throw StateError('Invalid SHIFT AI response.');
    final data=Map<String,dynamic>.from(response.data as Map);
    if(data['error']!=null)throw StateError(data['error'].toString());
    return data;
  }
  Future<void> refresh()async{
    if(!mounted||!ref.read(workspaceProvider).cloudAuthenticated)return;
    setState(()=>loading=true);
    try{
      final data=await call('status');
      if(!mounted)return;
      setState((){
        capabilities=Map<String,dynamic>.from(data['capabilities'] as Map? ?? {});
        message='';
      });
      try{
        final response=await Future.wait([
          call('history'),call('plan_items'),call('media_history')]);
        if(!mounted)return;
        setState((){
          history=(response[0]['history'] as List? ?? const [])
            .map((v)=>Map<String,dynamic>.from(v as Map)).toList();
          plans=(response[1]['items'] as List? ?? const [])
            .map((v)=>Map<String,dynamic>.from(v as Map)).toList();
          mediaHistory=(response[2]['items'] as List? ?? const [])
            .map((v)=>Map<String,dynamic>.from(v as Map)).toList();
        });
      }catch(_){/* History is optional; keep the generator usable. */}
    }catch(e){if(mounted)setState(()=>message=readable(e));}
    finally{if(mounted)setState(()=>loading=false);}
  }
  Future<void> attachPhoto()async{
    if(running)return;
    try{
      final photo=await ImagePicker().pickImage(source:ImageSource.gallery,
        imageQuality:85,maxHeight:1600,maxWidth:1600);
      if(photo==null)return;
      final wid=await ShiftCloud.workspaceId();
      final stored=await ShiftCloud.uploadImage(wid,photo.path);
      if(mounted)setState(()=>sourcePath=stored);
    }catch(e){
      if(mounted)setState(()=>message='Image upload failed: '+readable(e));
    }
  }
  Future<void> poll(String id)async{
    var errors=0;
    for(var i=0;i<36;i++){
      await Future<void>.delayed(const Duration(seconds:4));
      if(!mounted)return;
      Map<String,dynamic> response;
      try{
        response=await call('job_status',{'jobId':id});
        errors=0;
      }catch(e){
        if(!networkError(e))rethrow;
        errors++;
        if(mounted)setState(()=>progress='Reconnecting to saved AI job…');
        if(errors>=5){
          if(mounted)setState(()=>progress=
            'Connection lost. Check the job in History when you reconnect.');
          return;
        }
        continue;
      }
      if(response['status']=='completed'&&response['result'] is Map){
        if(mounted)setState((){
          result=Map<String,dynamic>.from(response['result'] as Map);
          progress='';
        });
        return;
      }
      if(response['status']=='failed'){
        throw StateError((response['error']??'generation_failed').toString());
      }
    }
    if(mounted)setState(()=>progress='Task saved. Check its status in History.');
  }
  Future<void> run()async{
    if(running)return;
    if(prompt.text.trim().length<5){
      toast(context,'Describe what SHIFT should create.');return;
    }
    setState((){
      running=true;message='';progress='SHIFT is working…';result=null;
    });
    try{
      final response=await call('run',{
        'prompt':prompt.text.trim(),
        'requestKey':'shift-workspace-'+DateTime.now().microsecondsSinceEpoch.toString(),
        if(sourcePath!=null)'sourcePath':sourcePath,
      });
      if(response['status']=='running'&&response['jobId'] is String){
        if(mounted)setState(()=>progress='SHIFT is working in the cloud. You can reopen this job.');
        await poll(response['jobId'] as String);
      }else if(response['result'] is Map){
        if(mounted)setState((){
          result=Map<String,dynamic>.from(response['result'] as Map);
          progress='';
        });
      }else if(response['type']!=null||response['matches'] is List){
        if(mounted)setState((){
          result=response;
          progress='';
        });
      }else{throw StateError('No AI result returned.');}
      if(mounted&&result!=null){try{await refresh();}catch(_){}}
    }catch(e){
      if(mounted)setState((){
        progress='';
        message=readable(e);
      });
    }finally{if(mounted)setState(()=>running=false);}
  }
  Future<void> resume(Map<String,dynamic> job)async{
    final id=job['id']?.toString();
    if(id==null||running)return;
    setState(()=>running=true);
    try{await poll(id);}
    catch(e){if(mounted)setState(()=>message=readable(e));}
    finally{if(mounted)setState(()=>running=false);}
  }
  Future<void> indexKnowledge()async{
    if(knowledgeBusy)return;
    setState(()=>knowledgeBusy=true);
    try{
      final result=await call('index_knowledge');
      if(mounted)toast(context,'Updated saved research index.');
    }catch(e){if(mounted)setState(()=>message=readable(e));}
    finally{if(mounted)setState(()=>knowledgeBusy=false);}
  }
  Future<void> accept(Map<String,dynamic> item)async{
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      title:const Text('Add a draft?'),
      content:Text((item['title']??'Proposed post').toString()+
        '\n\nThe draft will not publish automatically.'),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(ctx,false),
          child:const Text('Cancel')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,true),
          child:const Text('Add draft')),
      ]))??false;
    if(!ok||!mounted)return;
    setState(()=>running=true);
    try{
      await call('accept_plan',{'itemId':item['id']});
      await ref.read(workspaceProvider).openCloud();
      await refresh();
      if(mounted)toast(context,'Saved as a draft for review.');
    }catch(e){if(mounted)setState(()=>message=readable(e));}
    finally{if(mounted)setState(()=>running=false);}
  }
  Widget points(String title,dynamic data){
    if(data is! List||data.isEmpty)return const SizedBox.shrink();
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const SizedBox(height:12),
      Text(title,style:Theme.of(context).textTheme.titleMedium),
      ...data.map((v)=>Padding(
        padding:const EdgeInsets.only(top:7),child:SelectableText('• '+v.toString())))
    ]);
  }
  Widget resultView(){
    final x=result!;
    final media=x['type']?.toString()??'';
    final uri=Uri.tryParse(x['url']?.toString()??'');
    if(media=='image'||media=='image_edit'||media=='voice'){
      return Panel(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(media=='voice'?'Voiceover created':'Image created',
          style:Theme.of(context).textTheme.titleMedium),
        const SizedBox(height:10),
        if(media!='voice'&&uri?.scheme=='https')
          Image.network(uri.toString(),height:230,fit:BoxFit.contain),
        const SizedBox(height:8),
        OutlinedButton.icon(onPressed:uri?.scheme=='https'
          ?()=>launchUrl(uri!,mode:LaunchMode.externalApplication):null,
          icon:const Icon(Icons.open_in_new),
          label:Text(media=='voice'?'Open audio':'Open image')),
        const Text('Private media link expires after ten minutes.',
          style:TextStyle(fontSize:12)),
      ]));
    }
    if(x['matches'] is List){
      return Panel(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('Relevant saved research',style:Theme.of(context).textTheme.titleMedium),
        ...((x['matches'] as List).whereType<Map>().map((m){
          final link=Uri.tryParse(m['url']?.toString()??'');
          return ListTile(contentPadding:EdgeInsets.zero,
            title:Text(m['title']?.toString()??'Source'),
            subtitle:Text(m['snippet']?.toString()??'',maxLines:3),
            trailing:const Icon(Icons.open_in_new,size:18),
            onTap:link?.scheme=='https'
              ?()=>launchUrl(link!,mode:LaunchMode.externalApplication):null);
        })),
      ]));
    }
    return Panel(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text('SHIFT response',style:Theme.of(context).textTheme.titleMedium),
      const SizedBox(height:8),
      SelectableText(x['summary']?.toString()??''),
      points('Findings',x['findings']),
      points('Content ideas',x['ideas']),
      points('Recommendations',x['recommendations']),
      points('Content pillars',x['pillars']),
      if(x['sources'] is List && (x['sources'] as List).isNotEmpty)...[
        const SizedBox(height:10),
        Text('Sources',style:Theme.of(context).textTheme.titleMedium),
        ...((x['sources'] as List).whereType<Map>().map((m){
          final link=Uri.tryParse(m['url']?.toString()??'');
          return ListTile(contentPadding:EdgeInsets.zero,
            title:Text(m['title']?.toString()??'Source'),
            trailing:const Icon(Icons.open_in_new,size:18),
            onTap:link?.scheme=='https'
              ?()=>launchUrl(link!,mode:LaunchMode.externalApplication):null);
        })),
      ],
      const SizedBox(height:10),
      const Text('Review suggestions before approval or publication.',
        style:TextStyle(fontSize:12)),
    ]));
  }
  @override Widget build(BuildContext context){
    final w=ref.watch(workspaceProvider);
    final ready=capabilities['creative']==true;
    final active=<String>[
      if(capabilities['text']==true)'Writing',
      if(capabilities['research']==true)'Research',
      if(capabilities['knowledge']==true)'Knowledge',
      if(capabilities['image']==true)'Images',
      if(capabilities['edit']==true)'Image editing',
      if(capabilities['voice']==true)'Voice',
    ];
    return Scaffold(
      appBar:AppBar(title:const Text('SHIFT AI'),
        actions:[IconButton(tooltip:'Refresh',
          onPressed:running||loading?null:refresh,icon:const Icon(Icons.refresh))]),
      body:PageBody(children:[
        const Heading('What should SHIFT create?',
          'One assistant. SHIFT chooses its configured capabilities automatically.'),
        if(!w.cloudAuthenticated)...[
          const Empty('Sign in to SHIFT Cloud',
            'Your AI work is saved securely in your workspace.'),
          FilledButton(onPressed:()=>context.push('/auth'),
            child:const Text('Sign in')),
        ]else...[
          Panel(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(ready?'SHIFT AI configured':'SHIFT AI needs configuration',
              style:Theme.of(context).textTheme.titleMedium),
            const SizedBox(height:8),
            Text(active.isEmpty?'No configured AI capabilities found.'
              :active.join(' · ')),
            const SizedBox(height:6),
            const Text('Configured does not mean a model has passed live testing.',
              style:TextStyle(fontSize:12)),
          ])),
          const Section('Instructions'),
          TextField(controller:prompt,maxLines:5,
            decoration:const InputDecoration(
              labelText:'Ask SHIFT',
              hintText:'Create three Instagram posts for my brand…')),
          const SizedBox(height:10),
          if(capabilities['edit']==true)
            Row(children:[
              OutlinedButton.icon(onPressed:running?null:attachPhoto,
                icon:const Icon(Icons.attach_file),
                label:Text(sourcePath==null?'Attach photo':'Photo attached')),
              if(sourcePath!=null)
                IconButton(tooltip:'Remove photo',
                  onPressed:running?null:()=>setState(()=>sourcePath=null),
                  icon:const Icon(Icons.close)),
            ]),
          const SizedBox(height:10),
          FilledButton.icon(onPressed:running||loading||!ready?null:run,
            icon:const Icon(Icons.auto_awesome),
            label:Text(running?'SHIFT is working…':'Generate with SHIFT')),
          if(running||loading)const LinearProgressIndicator(),
          if(progress.isNotEmpty)Text(progress,
            style:Theme.of(context).textTheme.bodySmall),
          if(message.isNotEmpty)Text(message,
            style:TextStyle(color:Theme.of(context).colorScheme.error)),
          if(result!=null)...[
            const Section('Result'),resultView(),
          ],
          if(capabilities['knowledge']==true)...[
            const Section('Saved research'),
            const Text('SHIFT uses saved research for meaning-based search.'),
            OutlinedButton.icon(
              onPressed:knowledgeBusy?null:indexKnowledge,
              icon:const Icon(Icons.library_add_outlined),
              label:Text(knowledgeBusy?'Updating…':'Update saved knowledge')),
          ],
          if(plans.isNotEmpty)...[
            const Section('Content calendar'),
            const Text('Ideas must be approved before being added as drafts.'),
            ...plans.map((item)=>Panel(child:ListTile(
              contentPadding:EdgeInsets.zero,
              title:Text(item['title']?.toString()??'Proposed draft'),
              subtitle:Text((item['planned_at']??'').toString()),
              trailing:item['state']=='proposed'
                ?OutlinedButton(onPressed:running?null:()=>accept(item),
                  child:const Text('Add draft'))
                :const Icon(Icons.check_circle_outline),
            ))),
          ],
          if(mediaHistory.isNotEmpty)...[
            const Section('Created media'),
            ...mediaHistory.take(8).map((m)=>ListTile(
              title:Text((m['prompt']??'Generated media').toString(),
                maxLines:2,overflow:TextOverflow.ellipsis),
              trailing:const Icon(Icons.open_in_new,size:18),
              onTap:(){
                final link=Uri.tryParse(m['url']?.toString()??'');
                if(link?.scheme=='https')
                  launchUrl(link!,mode:LaunchMode.externalApplication);
              },
            ))
          ],
          const Section('AI history'),
          if(history.isEmpty)
            const Empty('No AI jobs yet',
              'Your saved requests will appear here.'),
          ...history.take(15).map((item)=>ListTile(
            title:Text((item['result'] is Map
              ?((item['result'] as Map)['mode']??'SHIFT task')
              :'SHIFT task').toString()),
            subtitle:Text((item['status']??'Unknown').toString()),
            trailing:const Icon(Icons.chevron_right),
            onTap:()=>resume(item),
          )),
        ],
      ]),
    );
  }
}
