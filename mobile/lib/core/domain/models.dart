enum PostStatus { draft, pendingApproval, approved, scheduled, publishing, published, failed, canceled }
enum PublishingMode { manual, approvalRequired, trustedAutopilot }

String statusLabel(PostStatus s) => switch(s) {
  PostStatus.pendingApproval => 'Pending approval',
  _ => s.name[0].toUpperCase() + s.name.substring(1),
};

class ContentVersion {
  ContentVersion({required this.caption, required this.createdAt, this.imagePath, this.platform = 'Instagram', this.headline = '', this.hashtags = '', this.metadata = const {}});
  final String caption, platform, headline, hashtags;
  final Map<String, String> metadata;
  final String? imagePath;
  final DateTime createdAt;
  Map<String, dynamic> toJson() => {'caption': caption, 'createdAt': createdAt.toIso8601String(), 'imagePath': imagePath, 'platform': platform, 'headline': headline, 'hashtags': hashtags, 'metadata': metadata};
  factory ContentVersion.fromJson(Map<String, dynamic> j) => ContentVersion(caption: j['caption'] as String, createdAt: DateTime.parse(j['createdAt'] as String), imagePath: j['imagePath'] as String?, platform: j['platform'] as String? ?? 'Instagram', headline: j['headline'] as String? ?? '', hashtags: j['hashtags'] as String? ?? '', metadata: Map<String, String>.from(j['metadata'] as Map? ?? {}));
}

class LocalPost {
  LocalPost({required this.id, required this.title, required this.versions, this.status = PostStatus.draft, this.plannedAt, this.timezone = '', this.note = ''});
  final String id, title, timezone, note;
  final List<ContentVersion> versions;
  final PostStatus status;
  // A local planning timestamp is NEVER a confirmed server schedule.
  final DateTime? plannedAt;
  ContentVersion get current => versions.last;
  LocalPost copyWith({String? title, List<ContentVersion>? versions, PostStatus? status, DateTime? plannedAt, bool clearPlan = false, String? timezone, String? note}) => LocalPost(id: id, title: title ?? this.title, versions: versions ?? this.versions, status: status ?? this.status, plannedAt: clearPlan ? null : plannedAt ?? this.plannedAt, timezone: timezone ?? this.timezone, note: note ?? this.note);
  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'versions': versions.map((v) => v.toJson()).toList(), 'status': status.name, 'plannedAt': plannedAt?.toUtc().toIso8601String(), 'timezone': timezone, 'note': note};
  factory LocalPost.fromJson(Map<String, dynamic> j) => LocalPost(id: j['id'] as String, title: j['title'] as String, versions: (j['versions'] as List).map((v) => ContentVersion.fromJson(Map<String, dynamic>.from(v as Map))).toList(), status: PostStatus.values.byName(j['status'] as String), plannedAt: j['plannedAt'] == null ? null : DateTime.parse(j['plannedAt'] as String).toLocal(), timezone: j['timezone'] as String? ?? '', note: j['note'] as String? ?? '');
}

class ResearchBookmark {
  const ResearchBookmark({required this.id, required this.topic, required this.url, required this.notes, required this.savedAt, this.publisher = '', this.publishedAt});
  final String id, topic, url, notes, publisher;
  final DateTime savedAt;
  final DateTime? publishedAt;
  Map<String, dynamic> toJson() => {'id': id, 'topic': topic, 'url': url, 'notes': notes, 'publisher': publisher, 'savedAt': savedAt.toIso8601String(), 'publishedAt': publishedAt?.toIso8601String()};
  factory ResearchBookmark.fromJson(Map<String, dynamic> j) => ResearchBookmark(id: j['id'] as String, topic: j['topic'] as String, url: j['url'] as String, notes: j['notes'] as String, publisher: j['publisher'] as String? ?? '', savedAt: DateTime.parse(j['savedAt'] as String), publishedAt: j['publishedAt'] == null ? null : DateTime.parse(j['publishedAt'] as String));
}
