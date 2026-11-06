import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'postiz_bridge.dart';

/// Explicit connection through the Postiz workspace. Social accounts are
/// connected within that workspace, not by accepting secrets inside SHIFT.
class PostizConnectionsPanel extends StatefulWidget {
  const PostizConnectionsPanel({super.key});
  @override
  State<PostizConnectionsPanel> createState() => _PostizConnectionsPanelState();
}
class _PostizConnectionsPanelState extends State<PostizConnectionsPanel> {
  bool loading = true, connected = false;
  String? error;
  List<ShiftPostizChannel> channels = const [];

  @override
  void initState() { super.initState(); refresh(); }

  Future<void> refresh() async {
    if (mounted) setState(() {loading = true; error = null;});
    try {
      final available = await ShiftPostizBridge.connected();
      final result = available ? await ShiftPostizBridge.accounts() : <ShiftPostizChannel>[];
      if (mounted) setState(() {connected = available; channels = result;});
    } catch (e) {
      if (mounted) setState(() {error = e.toString().replaceFirst('Bad state: ', '');});
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> connect() async {
    try {
      final link = await ShiftPostizBridge.authorizeUrl();
      final uri = Uri.tryParse(link);
      if (uri == null || uri.scheme != 'https') {
        throw StateError('Postiz authorization URL is invalid.');
      }
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) throw StateError('Cannot open Postiz in the browser.');
    } catch (e) {
      if (mounted) setState(() => error = e.toString().replaceFirst('Bad state: ', ''));
    }
  }

  Future<void> disconnect() async {
    final approved = await showDialog<bool>(context: context, builder: (dialog) =>
      AlertDialog(
        title: const Text('Disconnect Postiz?'),
        content: const Text('SHIFT will no longer access this Postiz workspace. Existing posts scheduled in Postiz may still publish. Revoke SHIFT under Approved Apps in Postiz to revoke the issued token.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Disconnect')),
        ],
      )) ?? false;
    if (!approved) return;
    try {
      await ShiftPostizBridge.invoke('disconnect');
      await refresh();
    } catch(e) {
      if(mounted)setState(()=>error=e.toString());
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Postiz connection', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        const Text('Connect your Postiz workspace, then add your social channels in Postiz. SHIFT can list channels and submit approved posts for scheduling when the server is configured.'),
        if (loading) const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: ShiftSkeleton(rows:3),
        ),
        if (error != null) Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ),
        if (!loading) ...[
          Text(connected ? 'Postiz workspace connected' : 'Postiz workspace not connected'),
          if (connected) ...[
            const SizedBox(height: 12),
            if (channels.isEmpty) const Text('No social channels found. Open Postiz, add a channel, then refresh.'),
            ...channels.map((c) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.check_circle_outline),
              title: Text(c.name),
              subtitle: Text(c.provider),
            )),
          ],
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            if (!connected) FilledButton.icon(
              onPressed: connect,
              icon: const Icon(Icons.link),
              label: const Text('Connect with Postiz'),
            ),
            OutlinedButton.icon(
              onPressed: refresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh accounts'),
            ),
            if (connected) OutlinedButton(
              onPressed: disconnect,
              child: const Text('Disconnect'),
            ),
          ]),
        ],
      ]),
    ),
  );
}
