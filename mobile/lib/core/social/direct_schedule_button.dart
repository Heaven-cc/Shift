import 'package:flutter/material.dart';
import '../ui/design.dart';
import '../cloud/shift_cloud.dart';
import '../domain/models.dart';
import 'direct_bridge.dart';

class DirectScheduleButton extends StatelessWidget {
  const DirectScheduleButton({super.key,required this.post});
  final LocalPost post;

  Future<void> schedule(BuildContext context) async{
    if(ShiftCloud.user==null){
      showShiftMessage(context,'Sign in required','Sign in to SHIFT before scheduling a post.');return;
    }
    if(post.status!=PostStatus.approved){
      showShiftMessage(context,'Approval required','Approve the saved post before scheduling it.');return;
    }
    if(post.current.platform!='Bluesky'||post.current.imagePath!=null){
      showShiftMessage(context,'Destination not supported','Direct scheduling currently supports Bluesky text posts only.');return;
    }
    try{
      final accounts=(await ShiftDirectBridge.accounts()).where((a)=>a.platform=='bluesky').toList();
      if(!context.mounted)return;
      if(accounts.isEmpty){
        showShiftMessage(context,'Connect an account','Connect Bluesky under Social Accounts first.');return;
      }
      final choice=await showDialog<ShiftDirectAccount>(context:context,builder:(c)=>SimpleDialog(
        title:const Text('Publishing account'),
        children:accounts.map((a)=>SimpleDialogOption(onPressed:()=>Navigator.pop(c,a),child:Text(a.handle))).toList()));
      if(choice==null||!context.mounted)return;
      final now=DateTime.now(),initial=DateTime.now().add(const Duration(days:1));
      final date=await showDatePicker(context:context,initialDate:initial,
        firstDate:DateUtils.dateOnly(now),lastDate:now.add(const Duration(days:365)));
      if(date==null||!context.mounted)return;
      final time=await showTimePicker(context:context,initialTime:TimeOfDay.fromDateTime(initial));
      if(time==null||!context.mounted)return;
      final when=DateTime(date.year,date.month,date.day,time.hour,time.minute);
      if(!when.isAfter(DateTime.now().add(const Duration(minutes:1)))){
        showShiftMessage(context,'Choose another time','Select a time at least one minute in the future.');return;
      }
      final confirmed=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(
        title:const Text('Confirm scheduled post'),
        content:Text('Account: ${choice.handle}\nScheduled for: $when\n\nSHIFT Scheduler will publish this approved post even when the app is closed.'),
        actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancel')),
          FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Schedule'))]))??false;
      if(!confirmed||!context.mounted)return;
      final wid=await ShiftCloud.workspaceId();
      final rows=await ShiftCloud.client.from('shift_content_posts')
        .select('id').eq('workspace_id',wid).eq('client_id',post.id).limit(1);
      if(rows.isEmpty)throw StateError('Save and approve the cloud version first.');
      await ShiftDirectBridge.call('schedule',{
        'postId':rows.first['id'],'accountId':choice.id,
        'scheduledAt':when.toUtc().toIso8601String()
      });
      if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content:Text('Post queued in SHIFT. Publishing depends on the connected account remaining valid.')));
    }catch(e){if(context.mounted)showShiftError(context,e,title:'Unable to schedule post');}
  }
  @override Widget build(BuildContext context)=>OutlinedButton(
    onPressed:()=>schedule(context),child:const Text('Schedule with SHIFT'));
}
