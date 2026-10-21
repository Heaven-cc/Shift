enum ShiftPublishStatus { draft, pendingApproval, approved, scheduled, publishing, published, failed }
enum ShiftPlatform { instagram, facebook, x, tiktok }
class ShiftDraft {
  const ShiftDraft({required this.id,required this.title,required this.caption,required this.platform,required this.status,required this.createdAt,this.scheduledAt});
  final String id;
  final String title;
  final String caption;
  final ShiftPlatform platform;
  final ShiftPublishStatus status;
  final DateTime createdAt;
  final DateTime? scheduledAt;
  ShiftDraft copyWith({ShiftPublishStatus? status,DateTime? scheduledAt})=>ShiftDraft(id:id,title:title,caption:caption,platform:platform,status:status??this.status,createdAt:createdAt,scheduledAt:scheduledAt??this.scheduledAt);
}
class ShiftBrandProfile {
  const ShiftBrandProfile({required this.name,required this.voice,required this.audience});
  final String name;
  final String voice;
  final String audience;
}
