/// SHIFT destination catalog. Preview availability never implies OAuth access.
class ShiftSocialPlatform {
  const ShiftSocialPlatform({
    required this.id,
    required this.name,
    required this.accountRequirement,
    required this.publishingNote,
    required this.developerUrl,
    required this.homeUrl,
    required this.connectionNote,
    this.directSdk = true,
  });

  final String id;
  final String name;
  final String accountRequirement;
  final String publishingNote;
  final String developerUrl;
  final String homeUrl;
  final String connectionNote;
  final bool directSdk;

  String get integrationLabel => directSdk
      ? 'Postiz channel available after server setup'
      : 'Postiz-supported channel • setup needed';
}

class ShiftSocialPlatforms {
  const ShiftSocialPlatforms._();

  static const all = <ShiftSocialPlatform>[
    ShiftSocialPlatform(
      id: 'instagram', name: 'Instagram',
      accountRequirement: 'Professional Business or Creator account',
      publishingNote: 'Requires an eligible professional account, approved permissions and compatible media.',
      developerUrl: 'https://developers.facebook.com/docs/instagram-platform/',
      homeUrl: 'https://www.instagram.com/',
      connectionNote: 'Configure Meta app, Instagram permissions and server-side OAuth.',
    ),
    ShiftSocialPlatform(
      id: 'facebook', name: 'Facebook',
      accountRequirement: 'Facebook Page with publishing permissions',
      publishingNote: 'Page publishing requires a Page grant. Social SDK 0.5.0 has no direct Facebook adapter.',
      developerUrl: 'https://developers.facebook.com/docs/pages-api/',
      homeUrl: 'https://www.facebook.com/',
      connectionNote: 'Requires a separate Meta Pages API or supported managed provider.',
      directSdk: false,
    ),
    ShiftSocialPlatform(
      id: 'tiktok', name: 'TikTok',
      accountRequirement: 'Eligible TikTok creator or business account',
      publishingNote: 'Direct video publishing requires TikTok authorization, review and supported video formats.',
      developerUrl: 'https://developers.tiktok.com/',
      homeUrl: 'https://www.tiktok.com/',
      connectionNote: 'Configure TikTok developer app, approved scopes and server-side tokens.',
    ),
    ShiftSocialPlatform(
      id: 'linkedin', name: 'LinkedIn',
      accountRequirement: 'Member or authorized organization account',
      publishingNote: 'Posting permissions and member/organization eligibility depend on LinkedIn API grants.',
      developerUrl: 'https://www.linkedin.com/developers/',
      homeUrl: 'https://www.linkedin.com/',
      connectionNote: 'Configure LinkedIn developer app, requested scopes and OAuth.',
    ),
    ShiftSocialPlatform(
      id: 'x', name: 'X',
      accountRequirement: 'X account with developer API access',
      publishingNote: 'Publishing requires X API access and permission to write posts.',
      developerUrl: 'https://developer.x.com/',
      homeUrl: 'https://x.com/',
      connectionNote: 'Configure X API tier, OAuth credentials and server-side access tokens.',
    ),
    ShiftSocialPlatform(
      id: 'threads', name: 'Threads',
      accountRequirement: 'Eligible Threads profile',
      publishingNote: 'Posting requires Meta Threads permissions and a valid user grant.',
      developerUrl: 'https://developers.facebook.com/docs/threads/',
      homeUrl: 'https://www.threads.net/',
      connectionNote: 'Configure a Meta app for Threads and complete OAuth.',
    ),
    ShiftSocialPlatform(
      id: 'youtube', name: 'YouTube',
      accountRequirement: 'YouTube channel under an authorized Google account',
      publishingNote: 'YouTube publishing centers on video uploads and appropriate Google OAuth scopes.',
      developerUrl: 'https://developers.google.com/youtube/v3',
      homeUrl: 'https://www.youtube.com/',
      connectionNote: 'Configure Google Cloud OAuth consent and YouTube upload permissions.',
    ),
    ShiftSocialPlatform(
      id: 'bluesky', name: 'Bluesky',
      accountRequirement: 'Bluesky account',
      publishingNote: 'Direct Bluesky text publishing is available through SHIFT Supabase after connecting with an app password.',
      developerUrl: 'https://docs.bsky.app/',
      homeUrl: 'https://bsky.app/',
      connectionNote: 'Connect Bluesky in the Supabase publishing panel using a dedicated app password.',
    ),
    ShiftSocialPlatform(
      id: 'pinterest', name: 'Pinterest',
      accountRequirement: 'Pinterest account with approved API access',
      publishingNote: 'Preview and manual export only. Social SDK 0.5.0 has no direct Pinterest adapter.',
      developerUrl: 'https://developers.pinterest.com/',
      homeUrl: 'https://www.pinterest.com/',
      connectionNote: 'Requires a separate Pinterest integration before SHIFT can connect or publish.',
      directSdk: false,
    ),
  ];

  static List<String> get names => [for (final platform in all) platform.name];

  static ShiftSocialPlatform byName(String name) =>
      all.firstWhere((p) => p.name == name, orElse: () => all.first);
}
