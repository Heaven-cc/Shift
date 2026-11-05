import 'package:supabase_flutter/supabase_flutter.dart';
import '../cloud/shift_cloud.dart';

/// Supabase-native social connection and scheduled publishing bridge.
/// Never persists provider secrets on the device.
class ShiftDirectBridge {
  const ShiftDirectBridge._();

  static Future<Map<String,dynamic>> call(String action,
      [Map<String,dynamic> arguments = const {}]) async {
    if (ShiftCloud.user == null) {
      throw StateError('Sign in to your SHIFT account to connect or schedule.');
    }
    try {
      final response = await ShiftCloud.client.functions.invoke(
        'shift-direct',body: <String,dynamic>{'action':action,...arguments},
      );
      if(response.data is! Map) throw StateError('Unexpected scheduler response.');
      final data=Map<String,dynamic>.from(response.data as Map);
      if(data['error']!=null) throw StateError(message(data['error'].toString()));
      return data;
    } on FunctionException catch(e) {
      throw StateError('Could not reach SHIFT publishing service: ${e.reasonPhrase}');
    }
  }

  static String message(String error) => switch(error) {
    'approved_version_required' => 'Approve the saved cloud revision before scheduling.',
    'account_not_connected' => 'Connect the selected account first.',
    'daily_limit_reached' => 'Daily scheduling limit reached for this account.',
    'bluesky_text_limit' => 'Bluesky posts must be 300 bytes or fewer.',
    'unsupported_platform_or_media' => 'Bluesky text posts are the currently enabled direct publishing format.',
    'provider_unauthorized' => 'Bluesky rejected the account credentials. Use a valid app password.',
    'provider_rate_limited' => 'Bluesky is rate limiting requests.',
    'already_scheduled' => 'This exact post was already scheduled.',
    'invalid_schedule_time' => 'Choose a valid future time.',
    _ => 'Publishing service: $error',
  };

  static Future<List<ShiftDirectAccount>> accounts() async {
    final response=await call('accounts');
    final items=response['accounts'] as List? ?? const [];
    return items.map((item) => ShiftDirectAccount.fromJson(
      Map<String,dynamic>.from(item as Map),
    )).toList(growable:false);
  }
}

class ShiftDirectAccount {
  const ShiftDirectAccount({required this.id,required this.platform,
    required this.handle,required this.did});
  final String id,platform,handle,did;

  factory ShiftDirectAccount.fromJson(Map<String,dynamic> json) =>
    ShiftDirectAccount(id:json['id'] as String,
      platform:json['platform'] as String,handle:json['handle'] as String,
      did:json['did'] as String);
}
