import 'package:flutter_test/flutter_test.dart';
import 'package:shift_mobile/core/domain/models.dart';

void main() {
  test('content version round-trips without losing instructions', () {
    final timestamp = DateTime.utc(2026, 11, 4, 10);
    final source = ContentVersion(
      caption: 'Test caption', createdAt: timestamp,
      platform: 'Instagram', headline: 'Headline',
      hashtags: '#shift', metadata: const {'goal': 'Educate', 'tone': 'Direct'},
    );
    final after = ContentVersion.fromJson(source.toJson());
    expect(after.caption, source.caption);
    expect(after.createdAt, timestamp);
    expect(after.metadata['tone'], 'Direct');
    expect(after.platform, 'Instagram');
  });

  test('restoring local post preserves a planned UTC time and versions', () {
    final when = DateTime.utc(2026, 12, 1, 13);
    final post = LocalPost(
      id: 'local-1', title: 'Sample', plannedAt: when,
      timezone: 'Africa/Lagos',
      versions: [ContentVersion(caption: 'A', createdAt: when)],
    );
    final after = LocalPost.fromJson(post.toJson());
    expect(after.id, 'local-1');
    expect(after.versions.single.caption, 'A');
    expect(after.plannedAt!.toUtc(), when);
  });

  test('content revision cannot keep local reviewed status when reset', () {
    final stamp = DateTime.utc(2026, 11, 4);
    final post = LocalPost(
      id: 'local-2', title: 'Approved',
      status: PostStatus.approved,
      versions: [ContentVersion(caption: 'A', createdAt: stamp)],
    );
    final modified = post.copyWith(
      status: PostStatus.draft,
      versions: [...post.versions, ContentVersion(caption: 'B', createdAt: stamp)],
    );
    expect(post.status, PostStatus.approved);
    expect(modified.status, PostStatus.draft);
    expect(modified.versions.length, 2);
  });
}
