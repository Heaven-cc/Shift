import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'media_validation.dart';

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

  static Future<void> saveSettings({
    required String workspaceId,
    required Map<String,String> profile,
    required Map<String,String> brand,
    required Map<String,String> preferences,
    required Set<String> interests,
    required Map<String,bool> notifications,
    required bool onboardingComplete,
  }) async {
    final u = user;
    if (u == null) throw StateError('No cloud session');
    await client.from('shift_profiles').update({
      'display_name': profile['name'] ?? '',
      'locale': profile['language'] ?? 'en',
      'timezone': profile['timezone'] ?? 'UTC',
    }).eq('user_id', u.id);
    await client.from('shift_brands').update({
      'name': brand['name'] ?? '',
      'description': brand['description'] ?? '',
      'audience': brand['audience'] ?? '',
      'brand_voice': brand['tone'] ?? '',
      'guidelines': brand['guidelines'] ?? '',
      'settings': brand,
    }).eq('workspace_id',workspaceId);
    await client.from('shift_preferences').update({
      'preferences': preferences,
      'interests': interests.toList(),
      'notification_preferences': notifications,
    }).eq('workspace_id',workspaceId);
    await client.from('shift_workspaces').update({
      'name': brand['name']?.isNotEmpty == true ? brand['name'] : 'My workspace',
      'onboarding_completed': onboardingComplete,
      'timezone': profile['timezone'] ?? 'UTC',
    }).eq('id',workspaceId);
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

  static Future<void> saveBookmark(String wid, Map<String,dynamic> entry) async {
    final existing=await client.from('shift_research_bookmarks').select('id')
      .eq('workspace_id',wid).eq('client_id',entry['client_id'] as String).limit(1);
    if(existing.isEmpty) {
      await client.from('shift_research_bookmarks').insert({...entry,'workspace_id':wid});
    } else {
      await client.from('shift_research_bookmarks').update({
        'topic':entry['topic'],'url':entry['url'],'notes':entry['notes'],
        'publisher':entry['publisher'],'published_at':entry['published_at'],
      }).eq('id',existing.first['id'] as String);
    }
  }

  static Future<void> deleteBookmark(String wid,String clientId) async {
    await client.from('shift_research_bookmarks').delete()
      .eq('workspace_id',wid).eq('client_id',clientId);
  }

  static Future<void> deleteDraft(String wid,String clientId) async {
    final rows=await client.from('shift_content_posts').select('id,status')
      .eq('workspace_id',wid).eq('client_id',clientId).limit(1);
    if(rows.isEmpty) throw StateError('Cloud draft not found');
    if(rows.first['status']!='draft') throw StateError('Only unreviewed cloud drafts can be deleted');
    await client.from('shift_content_posts').delete().eq('id',rows.first['id'] as String).eq('status','draft');
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
    // Never trust the original extension or a client-supplied MIME string.
    final header=await file.openRead(0,16).first;
    final recognized=ShiftImageType.fromHeader(header);
    if(recognized==null)throw StateError('Unsupported image bytes: JPEG, PNG, or WebP required');
    final path='$userId/$wid/${DateTime.now().microsecondsSinceEpoch}.${recognized.extension}';
    await client.storage.from('shift-media').upload(path,file,
      fileOptions:FileOptions(contentType:recognized.mime,upsert:false));
    await client.from('shift_media_assets').insert({
      'workspace_id':wid,'storage_path':path,
      'mime_type':recognized.mime,'size_bytes':size,
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

  static Future<Map<String,dynamic>> searchWeb({
    required String query,String freshness='pm',String country='US',
    String language='en',
  }) async {
    if(user==null)throw StateError('Sign in to research live topics.');
    final response=await client.functions.invoke('shift-research',body:{
      'requestKey':'research-${DateTime.now().microsecondsSinceEpoch}',
      'query':query,'freshness':freshness,
      'country':country,'language':language,
    });
    final raw=response.data;
    if(raw is! Map)throw StateError('Research service response unavailable.');
    final result=Map<String,dynamic>.from(raw);
    if(result['status']!='completed') {
      throw StateError(result['error']?.toString() ?? 'Live research is unavailable.');
    }
    return result;
  }

  static Future<Map<String,dynamic>> generateText({
    required String instructions,
    required String platform,
    required String goal,
    required String tone,
    required String language,
    required String length,
    required String audience,
  }) async {
    if(user==null)throw StateError('Sign in to use AI drafting.');
    final response=await client.functions.invoke('shift-generate-text',body:{
      'requestKey':'shift-${DateTime.now().microsecondsSinceEpoch}',
      'prompt':instructions,
      'platform':platform,'goal':goal,'tone':tone,
      'language':language,'length':length,'audience':audience,
    });
    final raw=response.data;
    if(raw is! Map)throw StateError('AI service returned an invalid response.');
    final result=Map<String,dynamic>.from(raw);
    if(result['status']!='completed' || result['result'] is! Map) {
      throw StateError(result['error']?.toString() ?? 'AI model is not configured yet.');
    }
    return Map<String,dynamic>.from(result['result'] as Map);
  }

  static Future<List<Map<String,dynamic>>> loadNotifications(String wid) async {
    final rows = await client.from('shift_notifications')
        .select('id,kind,title,body,payload,read_at,created_at')
        .eq('workspace_id',wid).order('created_at',ascending:false).limit(100);
    return List<Map<String,dynamic>>.from(rows);
  }

  static Future<void> markNotificationRead(String wid,String id) async {
    final updated=await client.from('shift_notifications')
      .update({'read_at':DateTime.now().toUtc().toIso8601String()})
      .eq('workspace_id',wid).eq('id',id).select('id');
    if(updated.isEmpty) throw StateError('Notification no longer available');
  }

  static Future<List<Map<String,dynamic>>> loadTemplates(String wid) async {
    final rows=await client.from('shift_content_templates')
      .select('id,title,body,platform,created_at')
      .eq('workspace_id',wid).order('created_at',ascending:false).limit(100);
    return List<Map<String,dynamic>>.from(rows);
  }

  static Future<void> saveTemplate(
    String wid,{String? id,required String title,required String body,required String platform}
  ) async {
    if (id==null) {
      await client.from('shift_content_templates').insert({
        'workspace_id':wid,'title':title,'body':body,'platform':platform,
      });
    } else {
      final result=await client.from('shift_content_templates').update({
        'title':title,'body':body,'platform':platform,
      }).eq('workspace_id',wid).eq('id',id).select('id');
      if(result.isEmpty) throw StateError('Template no longer exists');
    }
  }

  static Future<void> deleteTemplate(String wid,String id) async {
    final result=await client.from('shift_content_templates').delete()
      .eq('workspace_id',wid).eq('id',id).select('id');
    if(result.isEmpty) throw StateError('Template no longer exists');
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

  // Each version is committed through a single owner-checked transaction.
  // The expected version and deterministic operation key reject duplicate
  // retries and stale multi-device writes instead of silently overwriting them.
  static Future<void> savePost(
    String wid, Map<String,dynamic> p, List<Map<String,dynamic>> versions,
  ) async {
    final clientId = p['client_id'] as String;
    final existing = await client.from('shift_content_posts')
        .select('id,current_version,status')
        .eq('workspace_id', wid).eq('client_id', clientId).limit(1);
    final remoteVersion = existing.isEmpty
        ? 0
        : existing.first['current_version'] as int;
    if (remoteVersion > versions.length) {
      throw StateError('Cloud revision is newer. Reload to resolve this conflict.');
    }
    if (versions.isEmpty) {
      throw StateError('A caption is required before saving a draft.');
    }
    for (var i = remoteVersion; i < versions.length; i++) {
      final draft = Map<String,dynamic>.from(versions[i]);
      final imagePath = draft.remove('local_image_path') as String?;
      final storagePath = await uploadImage(wid, imagePath);
      final expectedVersion = i;
      await client.rpc('shift_save_content_revision', params: {
        'p_client_id': clientId,
        'p_expected_version': expectedVersion,
        'p_title': p['title'],
        'p_caption': draft['caption'],
        'p_platform': draft['platform'],
        'p_headline': draft['headline'],
        'p_hashtags': draft['hashtags'],
        'p_details': draft['details'],
        'p_media_path': storagePath,
        'p_idempotency_key': '$clientId:version:${i + 1}',
      });
    }
    // Reviewed and published posts cannot be edited through this action.
    // Only update draft planning metadata after the revision has committed.
    if (existing.isEmpty || remoteVersion < versions.length ||
        existing.first['status'] == 'draft') {
      await client.rpc('shift_update_content_plan', params: {
        'p_client_id': clientId,
        'p_expected_version': versions.length,
        'p_title': p['title'],
        'p_planned_at': p['planned_at'],
        'p_timezone': p['planning_timezone'],
        'p_note': p['note'],
      });
    }
  }
}
