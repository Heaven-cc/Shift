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
  List<Map<String,dynamic>> nvidiaModels=[],mediaHistory=[];
  String? selectedModel,selectedSourcePath;
  Map<String,dynamic>? generatedMedia;
  bool mediaBusy=false;
  bool loading=false,configured=false,research=false;
  String mode='research',message='',provider='',progress='';
  Map<String,dynamic>? output;
  List<Map<String,dynamic>> plans=[],history=[];
  @override void initState(){super.initState();WidgetsBinding.instance.addPostFrameCallback((_)=>refresh());}
  @override void dispose(){prompt.dispose();mediaPrompt.dispose();super.dispose();}
  String displayAiError(Object error){
    final raw=error.toString();
    if(raw.contains('provider_timeout'))return
      'The NVIDIA model took too long to respond. Try a shorter request or retry. '
      'Your API key and model selection have not been changed.';
    if(raw.contains('provider_credentials_rejected'))return
      'NVIDIA rejected the API key or this model is not authorized for your account. '
      'Check the key and model access in NVIDIA Build.';
    if(raw.contains('provider_model_or_request_invalid'))return
      'NVIDIA rejected the model ID or request format. Check the exact model ID '
      'shown on its NVIDIA Build API page.';
    if(raw.contains('provider_rate_limited'))return
      'NVIDIA rate limit reached. Try again later or review your provider quota.';
    if(raw.contains('provider_upstream_error')||raw.contains('provider_network_error'))return
      'NVIDIA is temporarily unavailable or the connection failed. Try again.';
    if(raw.contains('provider_empty_response')||raw.contains('provider_invalid_response')
       ||raw.contains('invalid_model_output'))return
      'The AI response was incomplete. Try a simpler request, then retry.';
    if(raw.contains('research_provider_not_configured'))return
      'Online research needs SHIFT_BRAVE_SEARCH_API_KEY in SHIFT Supabase secrets.';
    if(raw.contains('ai_provider_not_configured'))return
      'Set the NVIDIA API key and exact Mistral/Kimi model ID in SHIFT Supabase secrets.';
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
    final matches=nvidiaModels.where((x)=>x['id']==selectedModel);
    if(matches.isEmpty||mediaBusy)return;
    final type=matches.first['type']?.toString()??'';
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
        'modelId':selectedModel,'prompt':mediaPrompt.text.trim(),
        if(type=='image_edit')'sourcePath':selectedSourcePath,
        if(type=='voice')'language':'en-US',
      });
      if(mounted)setState(()=>generatedMedia=res);
    }catch(e){if(mounted)setState(()=>message='NVIDIA media: '+e.toString());}
    finally{if(mounted)setState(()=>mediaBusy=false);}
  }
  Future<void> refresh()async{
    if(!mounted||!ref.read(workspaceProvider).cloudAuthenticated)return;
    setState(()=>loading=true);
    try{
      final res=await Future.wait([
        action('status'),action('history'),action('plan_items'),
        nvidiaRequest('status'),nvidiaRequest('history'),
      ]);
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
        mediaHistory=(res[4]['items'] as List? ?? const [])
          .map((x)=>Map<String,dynamic>.from(x as Map)).toList();
        nvidiaModels=(res[3]['models'] as List? ?? const [])
          .map((x)=>Map<String,dynamic>.from(x as Map)).toList();
        if(selectedModel==null||!nvidiaModels.any((m)=>m['id']==selectedModel)){
          final media=nvidiaModels.where((m)=>m['type']!='text');
          selectedModel=media.isEmpty?null:media.first['id']?.toString();
        }
        message='';
      });
    }catch(e){if(mounted)setState(()=>message=displayAiError(e));}
    finally{if(mounted)setState(()=>loading=false);}
  }
  Future<void> waitForJob(String jobId)async{
    // Poll one existing cloud job: never create a second NVIDIA request.
    for(var attempt=0;attempt<28;attempt++){
      await Future<void>.delayed(const Duration(seconds:4));
      if(!mounted)return;
      final current=await action('job_status',{'jobId':jobId});
      final state=current['status']?.toString();
      if(state=='completed'&&current['result'] is Map){
        setState((){
          output=Map<String,dynamic>.from(current['result'] as Map);
          progress='';
        });
        await refresh();
        return;
      }
      if(state=='failed')throw StateError(current['error']?.toString()??'ai_failed');
      if(state=='completed')throw StateError('AI returned no usable result.');
    }
    if(mounted){
      setState(()=>progress='Still processing. This job is saved in AI history. '
        'Use Refresh to check it later.');
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
    }catch(e){if(mounted)setState(()=>message=displayAiError(e));}
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
    }catch(e){if(mounted)setState(()=>message=displayAiError(e));}
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
          const Section('NVIDIA model library'),
          const Text('Models use backend NVIDIA keys. Configured is not a successful live test.'),
          if(nvidiaModels.isEmpty)
            const Text('Model statuses unavailable. Refresh your account.'),
          ...nvidiaModels.map((m)=>ListTile(
            contentPadding:EdgeInsets.zero,
            dense:true,
            leading:Icon(m['configured']==true
              ?Icons.check_circle_outline:Icons.lock_outline),
            title:Text(m['label']?.toString()??'Model'),
            subtitle:Text((m['type']??'').toString()+' • '+
              (m['model']??'Set model ID in Supabase').toString()),
            trailing:Text(m['configured']==true?'Configured':'Setup needed',
              style:const TextStyle(fontSize:11)),
          )),
          const Section('Generate media with NVIDIA'),
          if(nvidiaModels.any((m)=>m['type']!='text'))...[
            DropdownButtonFormField<String>(
              value:selectedModel,
              isExpanded:true,
              decoration:const InputDecoration(labelText:'Image, edit or voice model'),
              items:nvidiaModels.where((m)=>m['type']!='text').map((m)=>
                DropdownMenuItem<String>(
                  value:m['id']?.toString(),
                  child:Text(m['label']?.toString()??'Model',
                    overflow:TextOverflow.ellipsis))).toList(),
              onChanged:mediaBusy?null:(v)=>setState(()=>selectedModel=v),
            ),
            const SizedBox(height:12),
            TextField(controller:mediaPrompt,maxLines:3,
              decoration:const InputDecoration(labelText:'Creative instructions')),
            if(nvidiaModels.any((m)=>m['id']==selectedModel&&m['type']=='image_edit'))...[
              const SizedBox(height:8),
              OutlinedButton.icon(onPressed:mediaBusy?null:selectPhoto,
                icon:const Icon(Icons.image_outlined),
                label:Text(selectedSourcePath==null?'Select image to edit':'Image selected')),
            ],
            const SizedBox(height:12),
            FilledButton.icon(
              onPressed:mediaBusy||!nvidiaModels.any((m)=>
                  m['id']==selectedModel&&m['configured']==true&&m['type']!='text')
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
          const Text('Recent generated images and voice files are stored in your private SHIFT cloud workspace.'),
          if(mediaHistory.isEmpty)
            const Text('No NVIDIA media created yet.'),
          ...mediaHistory.take(12).map((m)=>ListTile(
            contentPadding:EdgeInsets.zero,
            leading:Icon(m['type']=='voice'
              ?Icons.record_voice_over_outlined:Icons.image_outlined),
            title:Text((m['modelId']??'NVIDIA model').toString()),
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
