import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/models.dart';

final workspaceProvider = ChangeNotifierProvider<Workspace>((ref) => Workspace());

class Workspace extends ChangeNotifier {
  ThemeMode theme = ThemeMode.system;
  bool entered = false, onboardingComplete = false;
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
    if (storageError != null) { notifyListeners(); return false; }
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
  Future<bool> retrySave() { storageError = null; return persist(); }
  void record(String title, String route) {
    activity.insert(0, {'title': title, 'route': route, 'at': DateTime.now().toIso8601String()});
    if (activity.length > 100) activity.removeLast();
  }
  Future<bool> savePost(LocalPost post) {
    final index = posts.indexWhere((p) => p.id == post.id);
    if (index < 0) { posts.insert(0, post); } else { posts[index] = post; }
    record('Draft saved: ${post.title}', '/post/${post.id}');
    return persist();
  }
  Future<bool> changePost(LocalPost post, String action) {
    final index = posts.indexWhere((p) => p.id == post.id);
    if (index < 0) return Future.value(false);
    posts[index] = post;
    record(action, '/post/${post.id}');
    return persist();
  }
  Future<bool> removePost(String id) {
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
