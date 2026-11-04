import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/cloud/shift_cloud.dart';
import 'core/state/workspace.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final workspace = Workspace();
  await workspace.restore();
  await ShiftCloud.initialize();
  if (ShiftCloud.user != null) {
    try { await workspace.openCloud(); } catch (_) { workspace.cloudError = 'Your SHIFT cloud session could not be restored. Sign in again or check your connection.'; workspace.entered = false; }
  }
  runApp(ProviderScope(overrides: [
    workspaceProvider.overrideWith((ref) => workspace),
  ], child: const ShiftApp()));
}
