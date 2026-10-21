import 'package:flutter/material.dart';

class ShiftWelcome extends StatefulWidget {
  const ShiftWelcome({super.key, required this.onContinue});
  final VoidCallback onContinue;
  @override State<ShiftWelcome> createState()=>_ShiftWelcomeState();
}
class _ShiftWelcomeState extends State<ShiftWelcome> {
  final form=GlobalKey<FormState>();
  final name=TextEditingController();
  final email=TextEditingController();
  bool accepted=false;
  @override void dispose(){name.dispose();email.dispose();super.dispose();}
  @override Widget build(BuildContext context) {
    final scheme=Theme.of(context).colorScheme;
    return Scaffold(body:SafeArea(child:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:480),child:ListView(padding:const EdgeInsets.all(25),shrinkWrap:true,children:[
      const SizedBox(height:28),
      Container(width:66,height:66,alignment:Alignment.center,decoration:BoxDecoration(color:scheme.onSurface,borderRadius:BorderRadius.circular(20)),child:Text('S',style:TextStyle(color:scheme.surface,fontSize:44,fontWeight:FontWeight.w900))),
      const SizedBox(height:26),
      const Text('Your ideas.\nIn motion.',style:TextStyle(fontSize:42,fontWeight:FontWeight.w900,height:1.05,letterSpacing:-2)),
      const SizedBox(height:15),
      Text('Welcome to SHIFT — your AI-first social media workspace.',style:TextStyle(fontSize:15,color:scheme.onSurfaceVariant)),
      const SizedBox(height:29),
      Card(elevation:0,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(22),side:BorderSide(color:scheme.outlineVariant)),child:Padding(padding:const EdgeInsets.all(19),child:Form(key:form,child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        const Text('Set up your preview',style:TextStyle(fontSize:20,fontWeight:FontWeight.w800)),
        const SizedBox(height:15),
        TextFormField(controller:name,decoration:const InputDecoration(labelText:'Your name',border:OutlineInputBorder()),validator:(v)=>v==null||v.trim().isEmpty?'Enter your name':null),
        const SizedBox(height:12),
        TextFormField(controller:email,keyboardType:TextInputType.emailAddress,decoration:const InputDecoration(labelText:'Email address',border:OutlineInputBorder()),validator:(v)=>v==null||!RegExp(r'^[^@ ]+@[^@ ]+\.[^@ ]+$').hasMatch(v)?'Enter a valid email':null),
        const SizedBox(height:12),
        CheckboxListTile(contentPadding:EdgeInsets.zero,title:const Text('I understand this is a frontend preview. No account is created.',style:TextStyle(fontSize:12)),value:accepted,onChanged:(v)=>setState(()=>accepted=v??false)),
        const SizedBox(height:8),
        FilledButton(onPressed:accepted?(){if(form.currentState!.validate())widget.onContinue();}:null,child:const Padding(padding:EdgeInsets.all(12),child:Text('Enter SHIFT'))),
      ])))),
      const SizedBox(height:15),
      Text('Authentication and permanent workspace storage will be enabled when the SHIFT Supabase backend is connected.',textAlign:TextAlign.center,style:TextStyle(fontSize:12,color:scheme.onSurfaceVariant)),
    ])))));
  }
}
