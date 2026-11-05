import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ShiftCloud {
  static const url = 'https://axgzpbtnqhuytlsanyto.supabase.co';
  // The publishable key identifies SHIFT's public Supabase project; it is not a secret.
  // Allow CI/builds to override it without requiring a Dart define for local builds.
  static const publishableKey = String.fromEnvironment(
    'SHIFT_SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_14hzpNBb_GovwwP-uTWliA_6O828Ihx',
  );
  static bool get configured => publishableKey.isNotEmpty;
  static SupabaseClient get client => Supabase.instance.client;
  static User? get user => configured ? client.auth.currentUser : null;

  static Future<void> initialize() async {
    if (!configured) return;
    await Supabase.initialize(url: url, publishableKey: publishableKey);
  }

  static Future<String> workspaceId() async {
    final u = user;
    if (u == null) throw StateError('Sign in to access SHIFT cloud data.');
    final rows = await client.from('shift_workspaces').select('id').eq('owner_id', u.id).limit(1);
    if (rows.isEmpty) throw StateError('Account provisioning is incomplete. Please contact support.');
    return rows.first['id'] as String;
  }

  /// Upload a private identity image under the owner-scoped Storage path.
  /// Never put a device filesystem path into the cloud settings record.
  static Future<String> uploadIdentityImage(
    String workspaceId, File file, String kind,
  ) async {
    final account = user;
    if (account == null) throw StateError('Sign in to upload your image.');
    if (!['avatar', 'brand'].contains(kind)) throw ArgumentError('Invalid image type');
    if (!await file.exists()) throw StateError('Image no longer exists on this device.');
    final bytes = await file.length();
    if (bytes < 1 || bytes > 10 * 1024 * 1024) {
      throw StateError('Choose an image smaller than 10 MB.');
    }
    final path = '${account.id}/$workspaceId/identity/${kind}_${DateTime.now().microsecondsSinceEpoch}.jpg';
    await client.storage.from('shift-media').upload(
      path, file, fileOptions: const FileOptions(
        contentType: 'image/jpeg', upsert: false,
      ),
    );
    return path;
  }

  static Future<Map<String,dynamic>> workspaceAction(String action,
    [Map<String,dynamic> fields = const {}]) async {
    if (user == null) throw StateError('Sign in to SHIFT Cloud first.');
    final response = await client.functions.invoke(
      'shift-workspace', body: {'action':action,...fields});
    if (response.data is! Map) {
      throw StateError('SHIFT workspace returned an invalid response.');
    }
    final result = Map<String,dynamic>.from(response.data as Map);
    if (result['error'] != null) {
      throw StateError('SHIFT Cloud rejected the change: ${result['error']}');
    }
    return result;
  }

  static Future<void> saveSettings({
    required String workspaceId,
    required Map<String,String> profile,
    required Map<String,String> brand,
    required Map<String,String> preferences,
    required Set<String> interests,
    required Map<String,bool> notifications,
    required bool onboardingComplete,
  }) async {
    if (workspaceId != await ShiftCloud.workspaceId()) {
      throw StateError('Workspace mismatch.');
    }
    await workspaceAction('save_settings', {
      'profile':profile,'brand':brand,'preferences':preferences,
      'interests':interests.toList(),'notifications':notifications,
      'onboardingComplete':onboardingComplete,
    });
  }

  static Future<Map<String,dynamic>> loadSettings(String workspaceId) async {
    final data = await Future.wait([
      client.from('shift_workspaces').select().eq('id',workspaceId).single(),
      client.from('shift_profiles').select().eq('user_id',user!.id).single(),
      client.from('shift_brands').select().eq('workspace_id',workspaceId).single(),
      client.from('shift_preferences').select().eq('workspace_id',workspaceId).single(),
    ]);
    return {'workspace': data[0], 'profile': data[1], 'brand': data[2], 'preferences': data[3]};
  }


  static Future<List<Map<String,dynamic>>> loadBookmarks(String wid) async {
    final rows = await client.from('shift_research_bookmarks').select()
      .eq('workspace_id',wid).order('saved_at',ascending:false);
    return List<Map<String,dynamic>>.from(rows);
  }

  static Future<void> saveBookmark(String wid,Map<String,dynamic> entry) async {
    if (wid != await workspaceId()) throw StateError('Workspace mismatch.');
    await workspaceAction('save_bookmark',{'bookmark':entry});
  }
  static Future<void> deleteBookmark(String wid,String clientId) async {
    if (wid != await workspaceId()) throw StateError('Workspace mismatch.');
    await workspaceAction('delete_bookmark',{'clientId':clientId});
  }
  static Future<void> deleteDraft(String wid,String clientId) async {
    if (wid != await workspaceId()) throw StateError('Workspace mismatch.');
    await workspaceAction('delete_draft',{'clientId':clientId});
  }

  static Future<String?> uploadImage(String wid,String? imagePath) async {
    if(imagePath==null)return null;
    if(imagePath.startsWith('cloud:'))return imagePath.substring(6);
    final userId=user?.id;
    if(userId==null)throw StateError('Sign in to upload images');
    final file=File(imagePath);
    if(!await file.exists())throw StateError('Selected image is no longer on this device');
    final size=await file.length();
    if(size<=0 || size>10*1024*1024)throw StateError('Image must be under 10 MB');
    // Images selected by SHIFT's picker are normalized as JPEG.
    final path='$userId/$wid/${DateTime.now().microsecondsSinceEpoch}.jpg';
    await client.storage.from('shift-media').upload(path,file,
      fileOptions:const FileOptions(contentType:'image/jpeg',upsert:false));
    await workspaceAction('register_media', {
      'path':path,'mimeType':'image/jpeg','sizeBytes':size,
    });
    return path;
  }

  static Future<String?> downloadImage(String? path) async {
    if(path==null)return null;
    final bytes=await client.storage.from('shift-media').download(path);
    final dir=await getApplicationDocumentsDirectory();
    final folder=Directory('${dir.path}/shift_cloud_media');
    await folder.create(recursive:true);
    final safe=path.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'),'_');
    final file=File('${folder.path}/$safe.jpg');
    await file.writeAsBytes(bytes,flush:true);
    return file.path;
  }

  static Future<List<Map<String,dynamic>>> loadPosts(String wid) async {
    final rows = await client.from('shift_content_posts').select().eq('workspace_id',wid).order('updated_at',ascending:false);
    final out = <Map<String,dynamic>>[];
    for (final p in rows) {
      final versions = await client.from('shift_content_versions').select().eq('post_id',p['id'] as String).order('version_number');
      out.add({...p,'versions':versions});
    }
    return out;
  }

  static Future<void> savePost(String wid, Map<String,dynamic> p,
    List<Map<String,dynamic>> versions) async {
    if (wid != await workspaceId()) throw StateError('Workspace mismatch.');
    final existing = await client.from('shift_content_posts')
      .select('id,current_version,status')
      .eq('workspace_id',wid).eq('client_id',p['client_id'] as String).limit(1);
    var remoteVersion = existing.isEmpty ? 0 :
      existing.first['current_version'] as int;
    final status = existing.isEmpty ? 'draft' :
      existing.first['status'] as String;
    if (versions.length < remoteVersion) {
      throw StateError('Cloud has newer draft revisions. Reload before saving.');
    }
    if (status == 'published' || status == 'publishing' || status == 'scheduled') {
      throw StateError('This cloud post can no longer be edited.');
    }
    for (var i = remoteVersion; i < versions.length; i++) {
      final draft=Map<String,dynamic>.from(versions[i]);
      final imagePath=draft.remove('local_image_path') as String?;
      final remoteImage=await uploadImage(wid,imagePath);
      final expected=i;
      await client.rpc('shift_save_content_revision',params:{
        'p_client_id':p['client_id'],
        'p_expected_version':expected,
        'p_title':p['title'],
        'p_caption':draft['caption'],
        'p_platform':draft['platform'],
        'p_headline':draft['headline']??'',
        'p_hashtags':draft['hashtags']??'',
        'p_details':draft['details']??<String,dynamic>{},
        'p_media_path':remoteImage,
        'p_idempotency_key':'shift-${p['client_id']}-v${i+1}',
      });
      remoteVersion=i+1;
    }
    if (remoteVersion<1) throw StateError('A draft requires a content revision.');
    if (status=='draft'||existing.isEmpty) {
      await client.rpc('shift_update_content_plan',params:{
        'p_client_id':p['client_id'],
        'p_expected_version':remoteVersion,
        'p_title':p['title'],
        'p_planned_at':p['planned_at'],
        'p_timezone':p['planning_timezone']??'UTC',
        'p_note':p['note']??'',
      });
    }
  }
}
