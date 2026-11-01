import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/models.dart';
import '../cloud/shift_cloud.dart';

final workspaceProvider = ChangeNotifierProvider<Workspace>((ref) => Workspace());

class Workspace extends ChangeNotifier {
  ThemeMode theme = ThemeMode.system;
  bool entered = false, onboardingComplete = false;
  bool cloudMode = false;
  String? cloudWorkspaceId, cloudError;
  bool get cloudAvailable => ShiftCloud.configured;
  bool get cloudAuthenticated => ShiftCloud.user != null && cloudMode;
  String? storageError;
  Map<String, String> profile = {};
  Map<String, String> brand = {};
  Map<String, String> preferences = {};
  Set<String> interests = {};
  Map<String, bool> notificationPreferences = {'Approvals': true, 'Failures': true, 'Published posts': true, 'Research': true, 'Weekly reports': true};
  List<LocalPost> posts = [];
  List<ResearchBookmark> bookmarks = [];
  List<Map<String, String>> activity = [];
  SharedPreferences? _prefs;
  Future<void> _writes = Future.value();

  Future<void> restore() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final raw = _prefs!.getString('shift.workspace.v2');
      if (raw == null) return;
      final j = jsonDecode(raw) as Map<String, dynamic>;
      theme = ThemeMode.values.byName(j['theme'] as String? ?? 'system');
      entered = j['entered'] == true;
      onboardingComplete = j['onboardingComplete'] == true;
      profile = Map<String, String>.from(j['profile'] as Map? ?? {});
      brand = Map<String, String>.from(j['brand'] as Map? ?? {});
      preferences = Map<String, String>.from(j['preferences'] as Map? ?? {});
      interests = Set<String>.from(j['interests'] as List? ?? []);
      if (j['notificationPreferences'] != null) notificationPreferences = Map<String, bool>.from(j['notificationPreferences'] as Map);
      posts = (j['posts'] as List? ?? []).map((p) => LocalPost.fromJson(Map<String, dynamic>.from(p as Map))).toList();
      bookmarks = (j['bookmarks'] as List? ?? []).map((p) => ResearchBookmark.fromJson(Map<String, dynamic>.from(p as Map))).toList();
      activity = (j['activity'] as List? ?? []).map((p) => Map<String, String>.from(p as Map)).toList();
    } catch (_) {
      entered = false;
      storageError = 'Saved workspace could not be restored. Your previous copy has not been overwritten. Retry by reopening SHIFT or reset local data in Settings.';
    }
  }

  Map<String, dynamic> _json() => {'theme': theme.name, 'entered': entered, 'onboardingComplete': onboardingComplete, 'profile': profile, 'brand': brand, 'preferences': preferences, 'interests': interests.toList(), 'notificationPreferences': notificationPreferences, 'posts': posts.map((p) => p.toJson()).toList(), 'bookmarks': bookmarks.map((p) => p.toJson()).toList(), 'activity': activity};
  Future<bool> persist() async {
    if (storageError != null && !cloudAuthenticated) { notifyListeners(); return false; }
    if (cloudAuthenticated) {
      // Cloud account data must not replace the separate device-only workspace.
      return saveCloudSettings();
    }
    final snapshot = jsonEncode(_json());
    bool saved = false;
    _writes = _writes.then((_) async {
      try {
        _prefs ??= await SharedPreferences.getInstance();
        saved = await _prefs!.setString('shift.workspace.v2', snapshot);
        if (!saved) throw StateError('Storage unavailable');
      } catch (_) { storageError = 'Changes are in memory only. Device storage could not be updated. Free storage, then retry saving.'; }
    });
    await _writes;
    notifyListeners();
    return saved;
  }
  
  Future<void> openCloud() async {
    final wid = await ShiftCloud.workspaceId();
    final data = await ShiftCloud.loadSettings(wid);
    final wp = data['workspace'] as Map<String,dynamic>;
    final bp = data['brand'] as Map<String,dynamic>;
    final pref = data['preferences'] as Map<String,dynamic>;
    final profileRow = data['profile'] as Map<String,dynamic>;
    // Never apply local content or local approvals to an authenticated account.
    profile = {'name': profileRow['display_name'] as String? ?? '',
      'language': profileRow['locale'] as String? ?? 'en',
      'timezone': profileRow['timezone'] as String? ?? 'UTC'};
    brand = {for(final e in (bp['settings'] as Map? ?? {}).entries)
      if (e.value is String) e.key.toString(): e.value as String};
    brand['name'] = bp['name'] as String? ?? '';
    preferences = {for(final e in (pref['preferences'] as Map? ?? {}).entries)
      if (e.value is String) e.key.toString(): e.value as String};
    interests = Set<String>.from(pref['interests'] as List? ?? []);
    notificationPreferences = {for (final e in (pref['notification_preferences'] as Map? ?? {}).entries)
      if (e.value is bool) e.key.toString(): e.value as bool};
    final cloudPosts = await ShiftCloud.loadPosts(wid);
    final loaded = <LocalPost>[];
    for (final p in cloudPosts) {
      final versions = (p['versions'] as List).map((raw) {
        final v = raw as Map<String,dynamic>;
        return ContentVersion(caption:v['caption'] as String,
          createdAt:DateTime.parse(v['created_at'] as String),
          platform:v['platform'] as String, headline:v['headline'] as String? ?? '',
          hashtags:v['hashtags'] as String? ?? '',
          metadata:{for(final e in (v['details'] as Map? ?? {}).entries)
            if(e.value is String) e.key.toString():e.value as String});
      }).toList();
      if (versions.isEmpty) continue;
      final status = switch(p['status'] as String) {
        'pending_approval' => PostStatus.pendingApproval,
        'approved' => PostStatus.approved,
        'scheduled' => PostStatus.scheduled,
        'publishing' => PostStatus.publishing,
        'published' => PostStatus.published,
        'failed' => PostStatus.failed,
        'canceled' => PostStatus.canceled,
        _ => PostStatus.draft,
      };
      loaded.add(LocalPost(id:p['client_id'] as String? ?? p['id'] as String,
        title:p['title'] as String,versions:versions,status:status,
        plannedAt:p['planned_at'] == null ? null : DateTime.parse(p['planned_at'] as String).toLocal(),
        timezone:p['planning_timezone'] as String? ?? 'UTC',note:p['note'] as String? ?? ''));
    }
    // Server is authoritative in cloud mode; do not overwrite device-only drafts.
    posts = loaded;
    final sourceRows=await ShiftCloud.loadBookmarks(wid);
    bookmarks=sourceRows.map((b)=>ResearchBookmark(
      id:b['client_id'] as String? ?? b['id'] as String,
      topic:b['topic'] as String,url:b['url'] as String,
      notes:b['notes'] as String,publisher:b['publisher'] as String? ?? '',
      savedAt:DateTime.parse(b['saved_at'] as String),
      publishedAt:b['published_at']==null?null:DateTime.parse(b['published_at'] as String),
    )).toList();
    cloudWorkspaceId = wid;
    cloudMode = true;
    entered = true;
    onboardingComplete = wp['onboarding_completed'] == true;
    cloudError = null;
    notifyListeners();
  }

  Future<void> leaveCloud() async {
    await ShiftCloud.client.auth.signOut();
    cloudMode = false; cloudWorkspaceId = null;
    entered = false; onboardingComplete = false;
    profile = {}; brand = {}; preferences = {}; interests = {};
    posts = []; bookmarks = []; activity = [];
    // Restore the unchanged local workspace, rather than merging identities.
    await restore();
    entered = false;
    notifyListeners();
  }

  Future<bool> saveCloudSettings() async {
    if (!cloudAuthenticated || cloudWorkspaceId == null) return false;
    try {
      await ShiftCloud.saveSettings(
        workspaceId:cloudWorkspaceId!,profile:profile,brand:brand,
        preferences:preferences,interests:interests,
        notifications:notificationPreferences,onboardingComplete:onboardingComplete);
      cloudError=null; notifyListeners(); return true;
    } catch(e) {
      cloudError='Cloud settings could not be saved: $e';
      notifyListeners(); return false;
    }
  }

  Future<bool> saveCloudPost(LocalPost post) async {
    if (!cloudAuthenticated || cloudWorkspaceId == null) return false;
    try {
      await ShiftCloud.savePost(cloudWorkspaceId!,{
        'client_id':post.id,'title':post.title,
        'planned_at':post.plannedAt?.toUtc().toIso8601String(),
        'planning_timezone':post.timezone,'note':post.note,
      },post.versions.map((v) => <String,dynamic>{
        'caption':v.caption,'platform':v.platform,'headline':v.headline,
        'hashtags':v.hashtags,'details':v.metadata,
      }).toList());
      cloudError=null; return true;
    } catch(e) {
      cloudError='Draft saved on this device only. Cloud sync failed: $e';
      notifyListeners(); return false;
    }
  }


  Future<bool> addBookmark(ResearchBookmark b) async {
    if(cloudAuthenticated) {
      try {
        await ShiftCloud.saveBookmark(cloudWorkspaceId!,{
          'client_id':b.id,'topic':b.topic,'url':b.url,
          'notes':b.notes,'publisher':b.publisher,
          'published_at':b.publishedAt?.toUtc().toIso8601String(),
        });
        bookmarks.insert(0,b);notifyListeners();return true;
      } catch(e) {cloudError='Could not save cloud source: $e';notifyListeners();return false;}
    }
    bookmarks.insert(0,b);return persist();
  }

  Future<bool> deleteBookmark(String id) async {
    if(cloudAuthenticated) {
      try {await ShiftCloud.deleteBookmark(cloudWorkspaceId!,id);}
      catch(e){cloudError='Could not remove cloud source: $e';notifyListeners();return false;}
    }
    bookmarks.removeWhere((b)=>b.id==id);
    if(cloudAuthenticated){notifyListeners();return true;}
    return persist();
  }

  Future<bool> importLocalDrafts() async {
    if(!cloudAuthenticated) return false;
    try {
      final saved=await SharedPreferences.getInstance();
      final raw=saved.getString('shift.workspace.v2');
      if(raw==null)return true;
      final json=jsonDecode(raw) as Map<String,dynamic>;
      final local=(json['posts'] as List? ?? []).map((e)=>LocalPost.fromJson(Map<String,dynamic>.from(e as Map))).toList();
      for(final p in local) {
        // Local approvals and statuses never transfer; all imports are drafts.
        await ShiftCloud.savePost(cloudWorkspaceId!,{
          'client_id':p.id,'title':p.title,
          'planned_at':null,'planning_timezone':p.timezone,'note':p.note,
        },p.versions.map((v)=><String,dynamic>{
          'caption':v.caption,'platform':v.platform,'headline':v.headline,
          'hashtags':v.hashtags,'details':v.metadata,
        }).toList());
      }
      await openCloud();return true;
    } catch(e){cloudError='Import stopped; original local data is preserved: $e';notifyListeners();return false;}
  }

  Future<bool> retrySave() { storageError = null; return persist(); }

  void record(String title, String route) {
    activity.insert(0, {'title': title, 'route': route, 'at': DateTime.now().toIso8601String()});
    if (activity.length > 100) activity.removeLast();
  }
  Future<bool> savePost(LocalPost post) {
    final index = posts.indexWhere((p) => p.id == post.id);
    if (index < 0) { posts.insert(0, post); } else { posts[index] = post; }
    record('Draft saved: ${post.title}', '/post/${post.id}');
    if (cloudAuthenticated) { notifyListeners(); return saveCloudPost(post); }
    return persist();
  }
  Future<bool> changePost(LocalPost post, String action) {
    final index = posts.indexWhere((p) => p.id == post.id);
    if (index < 0) return Future.value(false);
    posts[index] = post;
    record(action, '/post/${post.id}');
    if (cloudAuthenticated) { notifyListeners(); return saveCloudPost(post); }
    return persist();
  }
  Future<bool> removePost(String id) {
    if (cloudAuthenticated) {
      try {
        await ShiftCloud.deleteDraft(cloudWorkspaceId!,id);
        posts.removeWhere((p)=>p.id==id);
        notifyListeners();return true;
      } catch(e){cloudError='Could not delete cloud draft: $e';notifyListeners();return false;}
    }
    posts.removeWhere((p) => p.id == id);
    record('Local draft deleted', '/drafts');
    return persist();
  }
  Future<void> clear() async {
    await _writes;
    await _prefs?.remove('shift.workspace.v2');
    profile.clear(); brand.clear(); preferences.clear(); interests.clear();
    posts.clear(); bookmarks.clear(); activity.clear();
    notificationPreferences = {'Approvals': true, 'Failures': true, 'Published posts': true, 'Research': true, 'Weekly reports': true};
    entered = false; onboardingComplete = false; storageError = null; theme = ThemeMode.system;
    notifyListeners();
  }
}
