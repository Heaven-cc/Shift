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
    try { await workspace.openCloud(); } catch (e) { workspace.cloudError = 'Cloud restore failed: $e'; workspace.entered = false; }
  }
  runApp(ProviderScope(overrides: [
    workspaceProvider.overrideWith((ref) => workspace),
  ], child: const ShiftApp()));
}
