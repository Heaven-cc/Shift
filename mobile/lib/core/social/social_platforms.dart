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

  String get integrationLabel => id == 'bluesky'
      ? 'SHIFT direct connection available • see account panel'
      : directSdk
          ? 'Account connection requires setup'
          : 'Connection not available yet';
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
      connectionNote: 'Instagram connection is not ready yet. You can create and export drafts now.',
    ),
    ShiftSocialPlatform(
      id: 'facebook', name: 'Facebook',
      accountRequirement: 'Facebook Page with publishing permissions',
      publishingNote: 'Facebook Page publishing requires an approved connected account.',
      developerUrl: 'https://developers.facebook.com/docs/pages-api/',
      homeUrl: 'https://www.facebook.com/',
      connectionNote: 'Facebook Page connection is not ready yet. You can prepare and export posts.',
      directSdk: false,
    ),
    ShiftSocialPlatform(
      id: 'tiktok', name: 'TikTok',
      accountRequirement: 'Eligible TikTok creator or business account',
      publishingNote: 'Direct video publishing requires TikTok authorization, review and supported video formats.',
      developerUrl: 'https://developers.tiktok.com/',
      homeUrl: 'https://www.tiktok.com/',
      connectionNote: 'TikTok publishing needs account authorization before it can be enabled.',
    ),
    ShiftSocialPlatform(
      id: 'linkedin', name: 'LinkedIn',
      accountRequirement: 'Member or authorized organization account',
      publishingNote: 'Posting permissions and member/organization eligibility depend on LinkedIn API grants.',
      developerUrl: 'https://www.linkedin.com/developers/',
      homeUrl: 'https://www.linkedin.com/',
      connectionNote: 'LinkedIn connection requires supported account authorization.',
    ),
    ShiftSocialPlatform(
      id: 'x', name: 'X',
      accountRequirement: 'X account with developer API access',
      publishingNote: 'Publishing requires X API access and permission to write posts.',
      developerUrl: 'https://developer.x.com/',
      homeUrl: 'https://x.com/',
      connectionNote: 'X publishing requires a connected account with posting permission.',
    ),
    ShiftSocialPlatform(
      id: 'threads', name: 'Threads',
      accountRequirement: 'Eligible Threads profile',
      publishingNote: 'Posting requires Meta Threads permissions and a valid user grant.',
      developerUrl: 'https://developers.facebook.com/docs/threads/',
      homeUrl: 'https://www.threads.net/',
      connectionNote: 'Threads connection requires account authorization before posting.',
    ),
    ShiftSocialPlatform(
      id: 'youtube', name: 'YouTube',
      accountRequirement: 'YouTube channel under an authorized Google account',
      publishingNote: 'YouTube publishing centers on video uploads and appropriate Google OAuth scopes.',
      developerUrl: 'https://developers.google.com/youtube/v3',
      homeUrl: 'https://www.youtube.com/',
      connectionNote: 'YouTube publishing requires an authorized channel and video permissions.',
    ),
    ShiftSocialPlatform(
      id: 'bluesky', name: 'Bluesky',
      accountRequirement: 'Bluesky account',
      publishingNote: 'Direct Bluesky text publishing is available through SHIFT after connecting with an app password.',
      developerUrl: 'https://docs.bsky.app/',
      homeUrl: 'https://bsky.app/',
      connectionNote: 'Connect Bluesky in the SHIFT publishing panel using a dedicated app password.',
    ),
    ShiftSocialPlatform(
      id: 'pinterest', name: 'Pinterest',
      accountRequirement: 'Pinterest account with approved API access',
      publishingNote: 'Preview and manual export are available. Direct Pinterest publishing is not connected yet.',
      developerUrl: 'https://developers.pinterest.com/',
      homeUrl: 'https://www.pinterest.com/',
      connectionNote: 'Pinterest connection is not available yet. Drafts can still be exported manually.',
      directSdk: false,
    ),
  ];

  static List<String> get names => [for (final platform in all) platform.name];

  static ShiftSocialPlatform byName(String name) =>
      all.firstWhere((p) => p.name == name, orElse: () => all.first);
}
