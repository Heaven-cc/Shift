import 'package:supabase_flutter/supabase_flutter.dart';

class ShiftCloud {
  static const url = 'https://axgzpbtnqhuytlsanyto.supabase.co';
  static const publishableKey = String.fromEnvironment('SHIFT_SUPABASE_PUBLISHABLE_KEY');
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

  static Future<List<Map<String,dynamic>>> loadPosts(String wid) async {
    final rows = await client.from('shift_content_posts').select().eq('workspace_id',wid).order('updated_at',ascending:false);
    final out = <Map<String,dynamic>>[];
    for (final p in rows) {
      final versions = await client.from('shift_content_versions').select().eq('post_id',p['id'] as String).order('version_number');
      out.add({...p,'versions':versions});
    }
    return out;
  }

  static Future<void> savePost(String wid, Map<String,dynamic> p, List<Map<String,dynamic>> versions) async {
    final existing = await client.from('shift_content_posts').select('id,current_version,status')
      .eq('workspace_id',wid).eq('client_id',p['client_id'] as String).limit(1);
    String id;
    int remoteVersion;
    if (existing.isEmpty) {
      final created = await client.from('shift_content_posts').insert({
        'workspace_id':wid, 'client_id':p['client_id'],'title':p['title'],
        'planned_at':p['planned_at'],'planning_timezone':p['planning_timezone'],'note':p['note'],
      }).select('id').single();
      id=created['id'] as String; remoteVersion=0;
    } else {
      id=existing.first['id'] as String;
      remoteVersion=existing.first['current_version'] as int;
      if (existing.first['status'] != 'draft' && versions.length <= remoteVersion) {
        throw StateError('A cloud review is active. Change the cloud post using a reviewed workflow.');
      }
    }
    for (var i=remoteVersion;i<versions.length;i++) {
      await client.from('shift_content_versions').insert({...versions[i],'post_id':id,'version_number':i+1});
    }
    await client.from('shift_content_posts').update({
      'title':p['title'], 'planned_at':p['planned_at'],
      'planning_timezone':p['planning_timezone'], 'note':p['note'],
    }).eq('id',id);
  }
}
