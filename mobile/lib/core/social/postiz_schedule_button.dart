import 'package:flutter/material.dart';
import '../cloud/shift_cloud.dart';
import '../domain/models.dart';
import 'postiz_bridge.dart';

/// Explicit user-triggered scheduling, never a background action.
class PostizScheduleButton extends StatelessWidget {
  const PostizScheduleButton({super.key, required this.post});
  final LocalPost post;

  static String normalize(String provider) =>
      provider == 'linkedin-page' ? 'linkedin' : provider == 'instagram-standalone' ? 'instagram' : provider;

  static const textProviders = {
    'x', 'linkedin', 'linkedin-page', 'facebook', 'threads', 'bluesky',
    'mastodon', 'telegram',
  };

  Future<void> schedule(BuildContext context) async {
    if (ShiftCloud.user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Sign in to SHIFT Cloud before scheduling a post.')));
      return;
    }
    if (post.status != PostStatus.approved) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Approve the exact content version before scheduling.')));
      return;
    }
    try {
      final options = await ShiftPostizBridge.accounts();
      final matched = options.where((channel) =>
        normalize(channel.provider) == post.current.platform.toLowerCase() &&
        textProviders.contains(channel.provider)).toList();
      if (!context.mounted) return;
      if (matched.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No eligible text-only Postiz account matches this draft. Connect an account or edit the destination. Media scheduling is not enabled yet.')));
        return;
      }
      final chosen = await showDialog<ShiftPostizChannel>(
        context: context,
        builder: (dialog) => SimpleDialog(
          title: const Text('Select connected account'),
          children: matched.map((channel) => SimpleDialogOption(
            onPressed: () => Navigator.pop(dialog, channel),
            child: Text('${channel.name} · ${channel.provider}'),
          )).toList(),
        ),
      );
      if (chosen == null || !context.mounted) return;
      final now = DateTime.now();
      final initial = now.add(const Duration(days: 1));
      final date = await showDatePicker(
        context: context, initialDate: initial,
        firstDate: DateUtils.dateOnly(now),
        lastDate: now.add(const Duration(days: 365)),
      );
      if (date == null || !context.mounted) return;
      final time = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(initial),
      );
      if (time == null || !context.mounted) return;
      final when = DateTime(date.year,date.month,date.day,time.hour,time.minute);
      if (!when.isAfter(DateTime.now().add(const Duration(minutes: 1)))) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Choose a future time at least one minute away.')));
        return;
      }
      final approved = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: const Text('Schedule this approved post?'),
          content: Text('Account: ${chosen.name}\nTime: ${when.toLocal()}\n\nPostiz will publish at this time, even if SHIFT is closed. This cannot be stopped by pausing SHIFT cloud automation.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialog,false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialog,true), child: const Text('Schedule in Postiz')),
          ],
        ),
      ) ?? false;
      if (!approved || !context.mounted) return;
      final wid = await ShiftCloud.workspaceId();
      final rows = await ShiftCloud.client.from('shift_content_posts')
          .select('id').eq('workspace_id',wid).eq('client_id',post.id).limit(1);
      if (rows.isEmpty) throw StateError('Cloud post not found. Save and approve the post in SHIFT Cloud.');
      final result = await ShiftPostizBridge.invoke('schedule',{
        'postId': rows.first['id'], 'accountId':chosen.id,
        'scheduledAt':when.toUtc().toIso8601String(),
      });
      if (!context.mounted) return;
      final status = result['status'];
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(status == 'scheduled'
          ? 'Post accepted by Postiz for scheduled publishing.'
          : 'Submission outcome uncertain. Check Postiz before attempting again.'),
      ));
    } catch (error) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error.toString().replaceFirst('Bad state: ','')),
      ));
    }
  }

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: () => schedule(context),
    child: const Text('Schedule with Postiz'),
  );
}
