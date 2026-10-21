import 'shift_models.dart';
abstract interface class ShiftRepository {
  Future<List<ShiftDraft>> listDrafts();
  Future<ShiftDraft> saveDraft(ShiftDraft draft);
  Future<ShiftDraft> updateStatus(String id, ShiftPublishStatus status);
  Future<void> deleteDraft(String id);
  Future<ShiftBrandProfile?> getBrandProfile();
  Future<void> saveBrandProfile(ShiftBrandProfile profile);
}
class DemoShiftRepository implements ShiftRepository {
  final Map<String,ShiftDraft> _drafts={};
  ShiftBrandProfile? _profile;
  @override Future<List<ShiftDraft>> listDrafts() async =>_drafts.values.toList(growable:false);
  @override Future<ShiftDraft> saveDraft(ShiftDraft draft) async { _drafts[draft.id]=draft; return draft; }
  @override Future<ShiftDraft> updateStatus(String id,ShiftPublishStatus status) async {
    final current=_drafts[id];if(current==null)throw StateError('Draft not found');
    final updated=current.copyWith(status:status);_drafts[id]=updated;return updated;
  }
  @override Future<void> deleteDraft(String id) async {_drafts.remove(id);}
  @override Future<ShiftBrandProfile?> getBrandProfile() async=>_profile;
  @override Future<void> saveBrandProfile(ShiftBrandProfile profile) async {_profile=profile;}
}
