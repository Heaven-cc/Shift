import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'social_platforms.dart';
import '../ui/design.dart';

/// Informational setup guide. Does not request tokens or claim OAuth succeeded.
Future<void> showPlatformSetup(BuildContext context, ShiftSocialPlatform platform) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24, 8, 24, 24 + MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Set up ${platform.name}', style: Theme.of(sheetContext).textTheme.headlineSmall),
            const SizedBox(height: 12),
            Text(platform.accountRequirement),
            const SizedBox(height: 12),
            Text(platform.connectionNote),
            const SizedBox(height: 12),
            Text(platform.id == 'bluesky'
              ? 'Connect Bluesky from Social Accounts using a dedicated app password. Only approved text posts can be scheduled directly at this time.'
              : 'This platform requires supported account authorization before publishing. You can still create, review and manually export posts for this destination. No post is published from this screen.'),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () async {
                final opened = await launchUrl(
                  Uri.parse(platform.developerUrl),
                  mode: LaunchMode.externalApplication,
                );
                if (!opened && sheetContext.mounted) {
                  showShiftError(sheetContext,'Unable to open the developer website.',title:'Could not open website');
                }
              },
              icon: const Icon(Icons.open_in_new),
              label: const Text('Platform developer information'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => Navigator.pop(sheetContext),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Opens the provider website for manual publication; no SHIFT post is sent.
Future<void> openPlatformHome(BuildContext context, ShiftSocialPlatform platform) async {
  final opened = await launchUrl(
    Uri.parse(platform.homeUrl), mode: LaunchMode.externalApplication,
  );
  if (!opened && context.mounted) {
    showShiftError(context,'Could not open ${platform.name}.',title:'Could not open website');
  }
}
