import 'package:flutter_test/flutter_test.dart';
import 'package:shift_mobile/core/social/social_platforms.dart';

void main() {
  test('all known destinations are visible once and keep their own names', () {
    final names = ShiftSocialPlatforms.names;
    expect(names.length, 9);
    expect(names.toSet().length, names.length);
    expect(names, containsAll([
      'Instagram', 'Facebook', 'TikTok', 'LinkedIn', 'X',
      'Threads', 'YouTube', 'Bluesky', 'Pinterest',
    ]));
  });

  test('non-native SDK destinations are flagged for separate integration', () {
    expect(ShiftSocialPlatforms.byName('Facebook').directSdk, isFalse);
    expect(ShiftSocialPlatforms.byName('Pinterest').directSdk, isFalse);
    expect(ShiftSocialPlatforms.byName('TikTok').directSdk, isTrue);
  });

  test('platform setup points to valid HTTPS developer portals', () {
    for (final platform in ShiftSocialPlatforms.all) {
      expect(Uri.parse(platform.developerUrl).scheme, 'https');
      expect(Uri.parse(platform.homeUrl).scheme, 'https');
      expect(platform.connectionNote, isNotEmpty);
      expect(platform.publishingNote, isNotEmpty);
    }
  });
}
