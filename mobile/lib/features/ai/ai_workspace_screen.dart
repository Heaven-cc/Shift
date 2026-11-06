import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
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
  final mediaPrompt=TextEditingController();
  final semanticQuery=TextEditingController();
  bool nemotronConfigured=false,semanticBusy=false;
  int knowledgeCount=0;
  List<Map<String,dynamic>> semanticMatches=[];
  List<Map<String,dynamic>> mediaHistory=[];
  String mediaType='image';
  String? selectedSourcePath;
  Set<String> availableMediaTypes={};
  Map<String,dynamic>? generatedMedia;
  bool mediaBusy=false;
  bool loading=false,configured=false,research=false;
  String mode='ideas',message='',progress='';
  Map<String,dynamic>? output;
  List<Map<String,dynamic>> plans=[],history=[];
  @override void initState(){super.initState();WidgetsBinding.instance.addPostFrameCallback((_)=>refresh());}
  @override void dispose(){
    prompt.dispose();mediaPrompt.dispose();semanticQuery.dispose();super.dispose();
  }
  String displayAiError(Object error){
    final raw=error.toString();
    if(isTransientConnectionError(error))return
      'Cannot connect to SHIFT Cloud. Check your Wi-Fi or mobile-data connection, '
      'then reopen AI History to retrieve the saved job. Do not repeat Run SHIFT AI.';
    if(raw.contains('provider_timeout'))return
      'SHIFT AI took too long to respond. Your request was not completed. '
      'Try a shorter prompt or check your saved history.';
    if(raw.contains('provider_credentials_rejected'))return
      'SHIFT AI credentials were rejected. The service configuration needs attention.';
    if(raw.contains('provider_model_or_request_invalid'))return
      'SHIFT AI rejected the request format. Please retry with a simpler instruction.';
    if(raw.contains('provider_rate_limited'))return
      'SHIFT AI is currently busy. Try again later.';
    if(raw.contains('provider_upstream_error')||raw.contains('provider_network_error'))return
      'SHIFT AI is temporarily unavailable. Please retry later.';
    if(raw.contains('provider_empty_response')||raw.contains('provider_invalid_response')
       ||raw.contains('invalid_model_output'))return
      'The AI response was incomplete. Try a simpler request, then retry.';
    if(raw.contains('research_provider_not_configured'))return
      'Online research needs SHIFT_BRAVE_SEARCH_API_KEY in SHIFT Supabase secrets.';
    if(raw.contains('ai_provider_not_configured'))return
      'SHIFT AI is not configured on the server.';
    if(raw.contains('generation_limit_reached'))return
      'SHIFT AI request limit reached. Try again later.';
    return 'SHIFT AI request failed. '+raw.replaceFirst('Bad state: ', '');
  }
  Future<Map<String,dynamic>> action(String operation,[Map<String,dynamic> extra=const {}])async{
    final r=await ShiftCloud.client.functions.invoke('shift-ai',
      body:<String,dynamic>{'action':operation,...extra});
    if(r.data is! Map)throw StateError('Invalid AI response');
    final data=Map<String,dynamic>.from(r.data as Map);
    if(data['error']!=null)throw StateError(data['error'].toString());
    return data;
  }
  Future<Map<String,dynamic>> nemotronRequest(String operation,
      [Map<String,dynamic> payload=const {}]) async {
    final response=await ShiftCloud.client.functions.invoke('shift-nemotron',
      body:<String,dynamic>{'action':operation,...payload});
    if(response.data is! Map)throw StateError('Unexpected semantic-search response');
    final data=Map<String,dynamic>.from(response.data as Map);
    if(data['error']!=null)throw StateError(data['error'].toString());
    return data;
  }
  Future<void> indexKnowledge() async {
    if(semanticBusy)return;
    setState((){semanticBusy=true;message='';});
    try{
      final outcome=await nemotronRequest('index');
      await loadNemotronStatus();
      if(mounted)toast(context,
        'Indexed ${outcome['indexed']??0} sources. '
        '${outcome['remaining']??0} remaining.');
    }catch(e){
      if(mounted)setState(()=>message='Semantic index: '+e.toString());
    }finally{if(mounted)setState(()=>semanticBusy=false);}
  }
  Future<void> loadNemotronStatus()async{
    final data=await nemotronRequest('status');
    if(!mounted)return;
    setState((){
      nemotronConfigured=data['configured']==true;
      knowledgeCount=(data['indexedCount'] as num?)?.toInt()??0;
    });
  }
  Future<void> searchKnowledge() async {
    if(semanticBusy)return;
    final question=semanticQuery.text.trim();
    if(question.length<3){toast(context,'Enter a search topic.');return;}
    setState((){semanticBusy=true;message='';});
    try{
      final data=await nemotronRequest('search',{'query':question});
      if(mounted)setState(()=>semanticMatches=(data['matches'] as List? ?? const [])
        .map((x)=>Map<String,dynamic>.from(x as Map)).toList());
    }catch(e){
      if(mounted)setState(()=>message='Semantic search: '+e.toString());
    }finally{if(mounted)setState(()=>semanticBusy=false);}
  }
  Future<Map<String,dynamic>> nvidiaRequest(String operation,
      [Map<String,dynamic> payload=const {}]) async {
    final response=await ShiftCloud.client.functions.invoke('shift-nvidia',
      body:<String,dynamic>{'action':operation,...payload});
    if(response.data is! Map)throw StateError('Invalid NVIDIA response');
    final data=Map<String,dynamic>.from(response.data as Map);
    if(data['error']!=null)throw StateError(data['error'].toString());
    return data;
  }
  Future<void> selectPhoto() async {
    if(mediaBusy)return;
    try {
      final picked=await ImagePicker().pickImage(source:ImageSource.gallery,
        imageQuality:85,maxWidth:1600,maxHeight:1600);
      if(picked==null)return;
      final wid=await ShiftCloud.workspaceId();
      final stored=await ShiftCloud.uploadImage(wid,picked.path);
      if(mounted)setState(()=>selectedSourcePath=stored);
    }catch(e){
      if(mounted)setState(()=>message='Image upload failed: '+e.toString());
    }
  }
  Future<void> createMedia() async{
    if(mediaBusy||!availableMediaTypes.contains(mediaType))return;
    final type=mediaType;
    if(mediaPrompt.text.trim().length<5){
      toast(context,'Enter text or instructions first.');return;
    }
    if(type=='image_edit'&&selectedSourcePath==null){
      toast(context,'Select a photo for editing first.');return;
    }
    final operation=type=='voice'?'synthesize_voice':
      type=='image_edit'?'edit_image':'generate_image';
    setState((){mediaBusy=true;message='';generatedMedia=null;});
    try{
      final res=await nvidiaRequest(operation,{
        'prompt':mediaPrompt.text.trim(),
        if(type=='image_edit')'sourcePath':selectedSourcePath,
        if(type=='voice')'language':'en-US',
      });
      if(mounted)setState(()=>generatedMedia=res);
    }catch(e){if(mounted)setState(()=>message='SHIFT AI media: '+e.toString());}
    finally{if(mounted)setState(()=>mediaBusy=false);}
  }
  Future<void> refresh()async{
    if(!mounted||!ref.read(workspaceProvider).cloudAuthenticated)return;
    setState(()=>loading=true);
    try{
      final res=await Future.wait([
        action('status'),action('history'),action('plan_items'),
        nvidiaRequest('status'),nvidiaRequest('history'),
        nemotronRequest('status'),
      ]);
      if(!mounted)return;
      setState((){
        configured=res[0]['configured']==true;
        research=res[0]['researchAvailable']==true;

        history=(res[1]['history'] as List? ?? const [])
          .map((x)=>Map<String,dynamic>.from(x as Map)).toList();
        plans=(res[2]['items'] as List? ?? const [])
          .map((x)=>Map<String,dynamic>.from(x as Map)).toList();
        mediaHistory=(res[4]['items'] as List? ?? const [])
          .map((x)=>Map<String,dynamic>.from(x as Map)).toList();
        availableMediaTypes=(res[3]['availableTypes'] as List? ?? const [])
          .map((x)=>x.toString()).toSet();
        if(!availableMediaTypes.contains(mediaType)&&availableMediaTypes.isNotEmpty){
          mediaType=availableMediaTypes.first;
        }
        nemotronConfigured=res[5]['configured']==true;
        knowledgeCount=(res[5]['indexedCount'] as num?)?.toInt()??0;
        message='';
      });
    }catch(e){if(mounted)setState(()=>message=displayAiError(e));}
    finally{if(mounted)setState(()=>loading=false);}
  }
  // Network and DNS failures are not model failures. Never submit another
  // generation request merely because status polling temporarily disconnects.
  bool isTransientConnectionError(Object error){
    final value=error.toString().toLowerCase();
    return value.contains('socketexception')||
      value.contains('failed host lookup')||
      value.contains('connection reset')||
      value.contains('connection refused')||
      value.contains('connection timed out')||
      value.contains('network is unreachable')||
      value.contains('functionsfetch')||
      value.contains('connection closed before full header')||
      value.contains('clientexception')||
      value.contains('handshakeexception');
  }
  Future<void> waitForJob(String jobId)async{
    var connectionFailures=0;
    // This only checks an existing persisted job; it never creates another
    // NVIDIA request and cannot duplicate provider charges.
    for(var attempt=0;attempt<36;attempt++){
      await Future<void>.delayed(Duration(seconds:connectionFailures>0?6:4));
      if(!mounted)return;
      Map<String,dynamic> current;
      try{
        current=await action('job_status',{'jobId':jobId});
        connectionFailures=0;
        if(mounted&&progress.contains('Connection interrupted')){
          setState(()=>progress='Connected. Checking the saved AI job…');
        }
      }catch(e){
        if(!isTransientConnectionError(e))rethrow;
        connectionFailures++;
        if(mounted)setState(()=>progress='Connection interrupted. '
          'Reconnecting to the saved AI job ($connectionFailures)…');
        if(connectionFailures>=6){
          if(mounted)setState(()=>progress='Unable to check the AI job right now. '
            'The saved job remains in SHIFT Cloud. Reconnect and check AI History; '
            'do not submit the same request again.');
          return;
        }
        continue;
      }
      final state=current['status']?.toString();
      if(state=='completed'&&current['result'] is Map){
        setState((){
          output=Map<String,dynamic>.from(current['result'] as Map);
          progress='';
        });
        // A history refresh is optional; it must not hide a successful result
        // if connectivity fails again after the job completed.
        try{await refresh();}catch(_){/* result already shown */}
        return;
      }
      if(state=='failed')throw StateError(current['error']?.toString()??'ai_failed');
      if(state=='completed')throw StateError('AI returned no usable result.');
    }
    if(mounted){
      setState(()=>progress='This job is saved in SHIFT Cloud. '
        'Check AI History for its result later; do not submit it again.');
    }
  }
  Future<void> run()async{
    if(prompt.text.trim().length<5){toast(context,'Enter instructions first.');return;}
    setState((){loading=true;message='';progress='Sending AI request…';});
    try{
      final res=await action('run',{
        'async':true,
        'mode':mode,'prompt':prompt.text.trim(),
        'requestKey':'shift-workspace-'+DateTime.now().microsecondsSinceEpoch.toString()});
      if(res['status']=='completed'&&res['result'] is Map){
        if(mounted)setState((){
          output=Map<String,dynamic>.from(res['result'] as Map);
          progress='';
        });
        await refresh();
      }else if(res['status']=='running'&&res['jobId'] is String){
        if(mounted)setState(()=>progress='SHIFT AI is generating in the cloud. '
          'You can leave this page and return to its saved job.');
        await waitForJob(res['jobId'] as String);
      }else{
        throw StateError('The AI server did not accept the request.');
      }
    }catch(e){if(mounted)setState((){
      progress='';
      message=displayAiError(e);
    });}
    finally{if(mounted)setState(()=>loading=false);}
  }
  Future<void> resumeJob(Map<String,dynamic> job)async{
    final id=job['id']?.toString();
    if(id==null||loading)return;
    setState((){loading=true;message='';progress='Checking existing AI job…';});
    try{
      final current=await action('job_status',{'jobId':id});
      if(current['status']=='completed'&&current['result'] is Map){
        if(mounted)setState((){
          output=Map<String,dynamic>.from(current['result'] as Map);
          progress='';
        });
      }else if(current['status']=='failed'){
        throw StateError(current['error']?.toString()??'ai_failed');
      }else if(current['status']=='running'||current['status']=='pending'){
        await waitForJob(id);
      }
    }catch(e){if(mounted)setState((){
      progress='';
      message=displayAiError(e);
    });}
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
    }catch(e){if(mounted)setState(()=>message=displayAiError(e));}
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
            Text(configured?'SHIFT AI configured':'SHIFT AI unavailable',
              style:Theme.of(context).textTheme.titleMedium),
            const SizedBox(height:6),
            Text(configured?'Models are chosen automatically. A successful generation is required to confirm they work.':'An administrator needs to configure a working AI connection.'),
            const SizedBox(height:6),
            Text(research?'Live research available':
              'For live research configure Brave Search or OpenAI native web search.',
              style:const TextStyle(fontSize:12)),
          ])),
          const Section('AI request'),
          DropdownButtonFormField<String>(
            value:mode,decoration:const InputDecoration(labelText:'Task'),
            items:modes.entries.where((v)=>research||
                (v.key!='research'&&v.key!='competitors'))
              .map((v)=>DropdownMenuItem(
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
          if(progress.isNotEmpty)Text(progress,
            style:Theme.of(context).textTheme.bodySmall),
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
          const Section('SHIFT AI knowledge'),
          Panel(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text('SHIFT AI knowledge search',
              style:Theme.of(context).textTheme.titleMedium),
            const SizedBox(height:8),
            Text(nemotronConfigured
              ?'Ready for indexing • $knowledgeCount saved knowledge entries'
              :'Knowledge search is not configured yet.'),
            const SizedBox(height:8),
            const Text('Find relevant saved research by meaning, not just keywords. '
              'Saved research helps SHIFT AI respond with relevant context.',
              style:TextStyle(fontSize:12)),
            const SizedBox(height:12),
            OutlinedButton.icon(
              onPressed:semanticBusy||!nemotronConfigured?null:indexKnowledge,
              icon:const Icon(Icons.library_add_outlined),
              label:const Text('Index saved research')),
            const SizedBox(height:12),
            TextField(controller:semanticQuery,
              decoration:const InputDecoration(
                labelText:'Search your research',
                hintText:'What marketing trends match my audience?')),
            const SizedBox(height:8),
            FilledButton.icon(
              onPressed:semanticBusy||!nemotronConfigured?null:searchKnowledge,
              icon:const Icon(Icons.manage_search),
              label:const Text('Semantic search')),
            if(semanticBusy)const LinearProgressIndicator(),
            if(semanticMatches.isNotEmpty)...[
              const SizedBox(height:12),
              Text('Relevant saved sources',
                style:Theme.of(context).textTheme.titleSmall),
              ...semanticMatches.map((item)=>ListTile(
                contentPadding:EdgeInsets.zero,
                title:Text(item['title']?.toString()??'Saved research'),
                subtitle:Text(item['snippet']?.toString()??'',
                  maxLines:3,overflow:TextOverflow.ellipsis),
                trailing:const Icon(Icons.open_in_new,size:18),
                onTap:(){
                  final link=Uri.tryParse(item['url']?.toString()??'');
                  if(link!=null&&link.scheme=='https'){
                    launchUrl(link,mode:LaunchMode.externalApplication);
                  }
                },
              )),
            ],
          ])),
          const Section('SHIFT AI media'),
          if(availableMediaTypes.isNotEmpty)...[
            DropdownButtonFormField<String>(
              value:availableMediaTypes.contains(mediaType)?mediaType:null,
              isExpanded:true,
              decoration:const InputDecoration(labelText:'Create'),
              items:const <String,String>{
                'image':'Image','image_edit':'Edit image','voice':'Voice',
              }.entries.where((entry)=>availableMediaTypes.contains(entry.key))
                .map((entry)=>DropdownMenuItem<String>(
                  value:entry.key,child:Text(entry.value))).toList(),
              onChanged:mediaBusy?null:(v)=>setState(()=>mediaType=v??'image'),
            ),
            const SizedBox(height:12),
            TextField(controller:mediaPrompt,maxLines:3,
              decoration:const InputDecoration(labelText:'Creative instructions')),
            if(mediaType=='image_edit')...[
              const SizedBox(height:8),
              OutlinedButton.icon(onPressed:mediaBusy?null:selectPhoto,
                icon:const Icon(Icons.image_outlined),
                label:Text(selectedSourcePath==null?'Select image to edit':'Image selected')),
            ],
            const SizedBox(height:12),
            FilledButton.icon(
              onPressed:mediaBusy||!availableMediaTypes.contains(mediaType)
                ?null:createMedia,
              icon:const Icon(Icons.auto_awesome),
              label:Text(mediaBusy?'Generating…':'Generate media')),
            if(mediaBusy)const LinearProgressIndicator(),
            if(generatedMedia!=null)...[
              const SizedBox(height:8),
              if(generatedMedia!['type']=='image'||generatedMedia!['type']=='image_edit')
                Image.network(generatedMedia!['url']?.toString()??'',
                  height:230,fit:BoxFit.contain),
              ListTile(
                title:const Text('Generated file saved privately'),
                subtitle:const Text('Signed link expires after 10 minutes'),
                trailing:const Icon(Icons.open_in_new),
                onTap:(){
                  final url=Uri.tryParse(generatedMedia!['url']?.toString()??'');
                  if(url!=null)launchUrl(url,mode:LaunchMode.externalApplication);
                },
              ),
            ],
          ],
          const Section('Generated media history'),
          const Text('Generated images and voice files are stored in your private SHIFT cloud workspace.'),
          if(mediaHistory.isEmpty)
            const Text('No SHIFT AI media created yet.'),
          ...mediaHistory.take(12).map((m)=>ListTile(
            contentPadding:EdgeInsets.zero,
            leading:Icon(m['type']=='voice'
              ?Icons.record_voice_over_outlined:Icons.image_outlined),
            title:Text(m['type']=='voice'?'SHIFT AI voice':'SHIFT AI image'),
            subtitle:Text((m['prompt']??'').toString(),
              maxLines:2,overflow:TextOverflow.ellipsis),
            trailing:const Icon(Icons.open_in_new,size:18),
            onTap:(){
              final url=Uri.tryParse(m['url']?.toString()??'');
              if(url!=null)launchUrl(url,mode:LaunchMode.externalApplication);
            },
          )),
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
            onTap:()=>resumeJob(h),
          )),
        ],
      ]));
  }
}
