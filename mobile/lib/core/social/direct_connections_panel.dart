import 'package:flutter/material.dart';
import '../cloud/shift_cloud.dart';
import 'direct_bridge.dart';

/// Direct-provider setup independent of Postiz, with no stored passwords in Flutter.
class DirectConnectionsPanel extends StatefulWidget {
  const DirectConnectionsPanel({super.key});
  @override State<DirectConnectionsPanel> createState()=>_DirectConnectionsPanelState();
}
class _DirectConnectionsPanelState extends State<DirectConnectionsPanel>{
  final handle=TextEditingController(),password=TextEditingController();
  bool loading=false;
  String? message;
  List<ShiftDirectAccount> accounts=const [];

  @override void initState(){super.initState();refresh();}
  @override void dispose(){handle.dispose();password.dispose();super.dispose();}

  Future<void> refresh() async{
    if(ShiftCloud.user==null)return;
    if(mounted)setState(()=>loading=true);
    try{
      final items=await ShiftDirectBridge.accounts();
      if(mounted)setState(()=>accounts=items);
    }catch(e){
      if(mounted)setState(()=>message=e.toString().replaceFirst('Bad state: ',''));
    }finally{if(mounted)setState(()=>loading=false);}
  }

  Future<void> connect() async{
    if(loading)return;
    setState((){loading=true;message=null;});
    try{
      await ShiftDirectBridge.call('connect_bluesky',{
        'handle':handle.text.trim(),'appPassword':password.text.trim()
      });
      password.clear();
      final items=await ShiftDirectBridge.accounts();
      if(mounted)setState((){accounts=items;message='Bluesky connected securely.';});
    }catch(e){
      if(mounted)setState(()=>message=e.toString().replaceFirst('Bad state: ',''));
    }finally{if(mounted)setState(()=>loading=false);}
  }
  Future<void> disconnect(ShiftDirectAccount account) async{
    final yes=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(
      title:const Text('Disconnect Bluesky?'),
      content:Text('Remove ${account.handle} from SHIFT? Queued posts for this account will no longer be dispatched.'),
      actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancel')),
        FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Disconnect'))],
    ))??false;
    if(!yes)return;
    try{
      await ShiftDirectBridge.call('disconnect',{'accountId':account.id});
      await refresh();
    }catch(e){if(mounted)setState(()=>message=e.toString());}
  }
  @override Widget build(BuildContext context)=>Card(
    child:Padding(padding:const EdgeInsets.all(16),child:Column(
      crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('SHIFT publishing',style:Theme.of(context).textTheme.titleMedium),
        const SizedBox(height:8),
        const Text('Schedule approved posts without a VPS. Supported now: Bluesky text posts. Other networks still require their provider OAuth setup.'),
        const SizedBox(height:12),
        if(ShiftCloud.user==null)
          const Text('Sign in to SHIFT to connect an account.')
        else ...[
          ...accounts.map((a)=>ListTile(contentPadding:EdgeInsets.zero,
            leading:const Icon(Icons.check_circle_outline),
            title:Text(a.handle),subtitle:const Text('Bluesky · Connected'),
            trailing:IconButton(tooltip:'Disconnect',icon:const Icon(Icons.link_off),
              onPressed:()=>disconnect(a)))),
          const SizedBox(height:8),
          TextField(controller:handle,autocorrect:false,
            decoration:const InputDecoration(labelText:'Bluesky handle',hintText:'you.bsky.social')),
          const SizedBox(height:10),
          TextField(controller:password,obscureText:true,autocorrect:false,
            enableSuggestions:false,
            decoration:const InputDecoration(labelText:'Bluesky app password')),
          const SizedBox(height:8),
          const Text('Create a Bluesky app password in your Bluesky account settings. Do not use your main password.',
            style:TextStyle(fontSize:12)),
          const SizedBox(height:12),
          FilledButton.icon(onPressed:loading?null:connect,icon:const Icon(Icons.link),
            label:const Text('Connect Bluesky')),
          const SizedBox(height:8),
          TextButton.icon(onPressed:loading?null:refresh,
            icon:const Icon(Icons.refresh),label:const Text('Refresh accounts')),
        ],
        if(loading)const ShiftSkeleton(rows:3),
        if(message!=null)Padding(padding:const EdgeInsets.only(top:8),
          child:Text(message!)),
    ])),
  );
}
