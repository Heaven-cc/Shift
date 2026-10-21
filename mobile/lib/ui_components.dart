import 'dart:ui';
import 'package:flutter/material.dart';
class ShiftGlassCard extends StatelessWidget {
  const ShiftGlassCard({super.key,required this.child,this.padding=const EdgeInsets.all(18)});
  final Widget child;
  final EdgeInsets padding;
  @override Widget build(BuildContext context){
    final dark=Theme.of(context).brightness==Brightness.dark;
    return ClipRRect(borderRadius:BorderRadius.circular(22),child:BackdropFilter(filter:ImageFilter.blur(sigmaX:16,sigmaY:16),child:Container(
      padding:padding,decoration:BoxDecoration(color:dark?Colors.white.withValues(alpha:.07):Colors.white.withValues(alpha:.8),border:Border.all(color:dark?Colors.white12:Colors.black12),borderRadius:BorderRadius.circular(22)),
      child:child,
    )));
  }
}
class ShiftEmptyState extends StatelessWidget {
  const ShiftEmptyState({super.key,required this.title,required this.description,this.icon=Icons.inbox_outlined});
  final String title,description;
  final IconData icon;
  @override Widget build(BuildContext context)=>ShiftGlassCard(child:Column(children:[
    const SizedBox(height:12),Icon(icon,size:40,color:Theme.of(context).colorScheme.onSurfaceVariant),const SizedBox(height:12),
    Text(title,style:const TextStyle(fontSize:17,fontWeight:FontWeight.w800)),
    const SizedBox(height:8),Text(description,textAlign:TextAlign.center,style:TextStyle(fontSize:13,color:Theme.of(context).colorScheme.onSurfaceVariant)),
    const SizedBox(height:12),
  ]));
}
