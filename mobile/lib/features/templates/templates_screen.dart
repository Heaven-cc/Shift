import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/cloud/shift_cloud.dart';
import '../../core/state/workspace.dart';
import '../../core/ui/design.dart';

class TemplatesScreen extends ConsumerStatefulWidget {
  const TemplatesScreen({super.key});
  @override
  ConsumerState<TemplatesScreen> createState() => _TemplatesState();
}

class _TemplatesState extends ConsumerState<TemplatesScreen> {
  List<Map<String,dynamic>> templates=[];
  bool loading=false;
  String? error;

  @override
  void initState(){
    super.initState();
    Future.microtask(_reload);
  }

  Future<void> _reload() async {
    final workspace=ref.read(workspaceProvider);
    if(!workspace.cloudAuthenticated)return;
    if(mounted)setState(()=>loading=true);
    try {
      final rows=await ShiftCloud.loadTemplates(workspace.cloudWorkspaceId!);
      if(mounted)setState(() {templates=rows;error=null;});
    } catch(e){
      if(mounted)setState(()=>error='Could not load templates: $e');
    } finally {
      if(mounted)setState(()=>loading=false);
    }
  }

  Future<void> _edit([Map<String,dynamic>? current]) async {
    final workspace=ref.read(workspaceProvider);
    if(!workspace.cloudAuthenticated)return;
    final title=TextEditingController(text:current?['title'] as String? ?? '');
    final body=TextEditingController(text:current?['body'] as String? ?? '');
    var platform=current?['platform'] as String? ?? 'Any';
    final form=GlobalKey<FormState>();
    final saved=await showDialog<bool>(context:context,builder:(dialog)=>StatefulBuilder(
      builder:(context,update)=>AlertDialog(
        title:Text(current==null?'New template':'Edit template'),
        content:Form(key:form,child:SingleChildScrollView(child:Column(
          mainAxisSize:MainAxisSize.min,children:[
            TextFormField(controller:title,maxLength:160,
              decoration:const InputDecoration(labelText:'Template name'),
              validator:(v)=>v==null||v.trim().isEmpty?'Enter a name':null),
            const SizedBox(height:12),
            TextFormField(controller:body,maxLines:6,maxLength:5000,
              decoration:const InputDecoration(labelText:'Reusable caption or instructions')),
            const SizedBox(height:12),
            DropdownButtonFormField<String>(
              value:platform,
              decoration:const InputDecoration(labelText:'Platform'),
              items:['Any','Instagram','Facebook'].map((s)=>DropdownMenuItem(
                value:s,child:Text(s))).toList(),
              onChanged:(v)=>update(()=>platform=v??'Any')),
          ]))),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(dialog,false),
            child:const Text('Cancel')),
          FilledButton(onPressed:(){
            if(form.currentState!.validate())Navigator.pop(dialog,true);
          },child:const Text('Save')),
        ],
      ),
    ));
    if(saved==true) {
      try {
        await ShiftCloud.saveTemplate(workspace.cloudWorkspaceId!,
          id:current?['id'] as String?,title:title.text.trim(),
          body:body.text.trim(),platform:platform);
        if(mounted){toast(context,'Template saved.');await _reload();}
      } catch(e){
        if(mounted)toast(context,'Could not save template: $e');
      }
    }
    title.dispose();body.dispose();
  }

  Future<void> _delete(Map<String,dynamic> t) async {
    if(!await confirm(context,'Delete this template?',
      'Your existing content drafts will not be affected.',action:'Delete'))return;
    try {
      final wid=ref.read(workspaceProvider).cloudWorkspaceId!;
      await ShiftCloud.deleteTemplate(wid,t['id'] as String);
      if(mounted)await _reload();
    } catch(e){
      if(mounted)toast(context,'Could not delete template: $e');
    }
  }

  @override
  Widget build(BuildContext context){
    final workspace=ref.watch(workspaceProvider);
    return Scaffold(
      appBar:AppBar(title:const Text('Content templates'),
        actions:[
          IconButton(tooltip:'Refresh templates',onPressed:_reload,
            icon:const Icon(Icons.refresh)),
        ]),
      body:PageBody(children:[
        const Heading('Write once.\nReuse wisely.',
          'Save writing patterns for your brand and platforms.'),
        if(!workspace.cloudAuthenticated) const Empty(
          'Sign in to save templates',
          'Your templates are private to your SHIFT Cloud account.',
          icon:Icons.lock_outline),
        if(workspace.cloudAuthenticated) ...[
          FilledButton.icon(onPressed:()=>_edit(),icon:const Icon(Icons.add),
            label:const Text('New template')),
          if(error!=null) Padding(
            padding:const EdgeInsets.only(top:12),child:Text(error!)),
          if(loading) const Padding(
            padding:EdgeInsets.only(top:16),child:LinearProgressIndicator()),
          if(!loading && templates.isEmpty) const Empty(
            'No templates yet','Create a reusable caption or writing instruction.',
            icon:Icons.note_add_outlined),
          ...templates.map((t)=>Padding(
            padding:const EdgeInsets.only(top:12),
            child:Panel(child:Column(
              crossAxisAlignment:CrossAxisAlignment.start,children:[
                Text(t['title'] as String,style:Theme.of(context).textTheme.titleMedium),
                const SizedBox(height:6),
                Text(t['platform'] as String? ?? 'Any'),
                const SizedBox(height:8),
                Text(t['body'] as String? ?? '',maxLines:4,
                  overflow:TextOverflow.ellipsis),
                Row(mainAxisAlignment:MainAxisAlignment.end,children:[
                  TextButton(onPressed:()=>_edit(t),child:const Text('Edit')),
                  TextButton(onPressed:()=>_delete(t),child:const Text('Delete')),
                ]),
              ]),
            ),
          )),
        ],
      ]),
    );
  }
}
