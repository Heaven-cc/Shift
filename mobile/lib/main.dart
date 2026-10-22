import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/state/workspace.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final workspace = Workspace();
  await workspace.restore();
  runApp(ProviderScope(overrides: [
    workspaceProvider.overrideWith((ref) => workspace),
  ], child: const ShiftApp()));
}
