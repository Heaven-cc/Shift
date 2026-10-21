import 'package:flutter_test/flutter_test.dart';
import 'package:shift_mobile/shift_models.dart';
import 'package:shift_mobile/shift_repository.dart';
void main(){
  test('demo repository can save and update a draft',() async {
    final repository=DemoShiftRepository();
    final draft=ShiftDraft(id:'1',title:'Example',caption:'Hello',platform:ShiftPlatform.instagram,status:ShiftPublishStatus.draft,createdAt:DateTime.utc(2026,10,21));
    await repository.saveDraft(draft);
    expect((await repository.listDrafts()).length,1);
    await repository.updateStatus('1',ShiftPublishStatus.pendingApproval);
    expect((await repository.listDrafts()).single.status,ShiftPublishStatus.pendingApproval);
  });
}
