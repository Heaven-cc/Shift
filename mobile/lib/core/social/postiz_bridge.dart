import 'package:supabase_flutter/supabase_flutter.dart';
import '../cloud/shift_cloud.dart';

/// The real Postiz API is invoked only through an authenticated SHIFT Edge Function.
/// No Postiz credential or token is ever stored on the device.
class ShiftPostizBridge {
  const ShiftPostizBridge._();

  static Future<Map<String, dynamic>> invoke(String action, [Map<String, dynamic> args = const {}]) async {
    if (ShiftCloud.user == null) {
      throw StateError('Sign in to SHIFT to connect and schedule social accounts.');
    }
    final response = await ShiftCloud.client.functions.invoke(
      'shift-postiz',
      body: <String, dynamic>{'action': action, ...args},
    );
    if (response.data is! Map) {
      throw StateError('SHIFT received an unexpected Postiz response.');
    }
    final data = Map<String, dynamic>.from(response.data as Map);
    final code = data['error'];
    if (code != null) {
      throw StateError(_messageFor(code.toString()));
    }
    return data;
  }

  static String _messageFor(String code) => switch (code) {
    'postiz_not_configured' => 'Postiz has not been configured on the SHIFT server.',
    'postiz_not_connected' => 'Connect your Postiz workspace first.',
    'approved_version_required' => 'Approve this exact version of the draft before scheduling.',
    'draft_destination_mismatch' => 'The selected account does not match this draft’s destination.',
    'platform_requires_media_or_specific_settings' => 'This platform requires media or additional publishing settings.',
    'media_schedule_not_enabled' => 'Image and video scheduling is not enabled yet.',
    'account_not_connected' => 'This social account is not connected through Postiz.',
    'already_submitted' => 'That scheduling request has already been submitted. Check Postiz before retrying.',
    'invalid_schedule_time' => 'Choose a future publishing date and time.',
    _ => 'Postiz operation could not complete ($code).',
  };

  static Future<bool> connected() async =>
      (await invoke('status'))['connected'] == true;

  static Future<String> authorizeUrl() async =>
      (await invoke('connect'))['authorizationUrl'] as String;

  static Future<List<ShiftPostizChannel>> accounts() async {
    final result = await invoke('accounts');
    final rows = result['accounts'] as List? ?? const [];
    return rows.map((row) => ShiftPostizChannel.fromJson(
      Map<String, dynamic>.from(row as Map),
    )).toList(growable: false);
  }
}

class ShiftPostizChannel {
  const ShiftPostizChannel({required this.id, required this.provider, required this.name});
  final String id, provider, name;

  factory ShiftPostizChannel.fromJson(Map<String, dynamic> json) =>
      ShiftPostizChannel(
        id: json['id'] as String,
        provider: json['provider'] as String,
        name: json['name'] as String,
      );
}
