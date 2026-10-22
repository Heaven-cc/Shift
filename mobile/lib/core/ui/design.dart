import 'dart:ui';
import 'package:flutter/material.dart';

ThemeData shiftTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final ink = dark ? const Color(0xFFF5F5F5) : const Color(0xFF101014);
  final base = dark ? const Color(0xFF08080A) : const Color(0xFFF8F8F8);
  final surface = dark ? const Color(0xFF18181B) : Colors.white;
  final scheme = ColorScheme.fromSeed(seedColor: ink, brightness: brightness).copyWith(primary: ink, onPrimary: base, surface: surface, onSurface: ink, secondary: ink, onSecondary: base, primaryContainer: dark ? const Color(0xFF303034) : const Color(0xFFEAEAEA), onPrimaryContainer: ink);
  return ThemeData(useMaterial3: true, brightness: brightness, colorScheme: scheme, scaffoldBackgroundColor: base,
    appBarTheme: AppBarTheme(backgroundColor: base, foregroundColor: ink, elevation: 0, centerTitle: false),
    inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: ink.withValues(alpha: .15))), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: ink.withValues(alpha: .15))), contentPadding: const EdgeInsets.all(16)),
    filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(minimumSize: const Size(48, 48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)))),
    outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)))),
    chipTheme: ChipThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
    dividerTheme: DividerThemeData(color: ink.withValues(alpha: .1)),
    textTheme: TextTheme(headlineLarge: TextStyle(fontSize: 34, height: 1.12, fontWeight: FontWeight.w800, letterSpacing: -1.3, color: ink), headlineSmall: TextStyle(fontSize: 23, fontWeight: FontWeight.w700, letterSpacing: -.5, color: ink), titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: ink)),
  );
}
class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.glass = false, this.padding = const EdgeInsets.all(16)});
  final Widget child;
  final bool glass;
  final EdgeInsets padding;
  @override Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final box = Container(width: double.infinity, padding: padding, decoration: BoxDecoration(color: theme.colorScheme.surface.withValues(alpha: glass ? .8 : 1), borderRadius: BorderRadius.circular(20), border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: .1))), child: child);
    if (!glass) return box;
    return ClipRRect(borderRadius: BorderRadius.circular(20), child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), child: box));
  }
}
class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children});
  final List<Widget> children;
  @override Widget build(BuildContext context) => Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 680), child: ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 28), children: children)));
}
class Heading extends StatelessWidget {
  const Heading(this.title, this.subtitle, {super.key});
  final String title, subtitle;
  @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: Theme.of(context).textTheme.headlineLarge), const SizedBox(height: 8), Text(subtitle, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.5))]));
}
class Section extends StatelessWidget {
  const Section(this.title, {super.key, this.action});
  final String title;
  final Widget? action;
  @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(top: 20, bottom: 12), child: Row(children: [Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)), if (action != null) action!]));
}
class Empty extends StatelessWidget {
  const Empty(this.title, this.body, {super.key, this.icon = Icons.layers_outlined, this.action});
  final String title, body;
  final IconData icon;
  final Widget? action;
  @override Widget build(BuildContext context) => Panel(child: Column(children: [const SizedBox(height: 12), Icon(icon, size: 32), const SizedBox(height: 16), Text(title, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center), const SizedBox(height: 8), Text(body, textAlign: TextAlign.center), if (action != null) Padding(padding: const EdgeInsets.only(top: 16), child: action!), const SizedBox(height: 12)]));
}
class ServiceNotice extends StatelessWidget {
  const ServiceNotice({super.key, this.text = 'Local workspace • Cloud services are not connected'});
  final String text;
  @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 16), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.cloud_off_outlined, size: 16), const SizedBox(width: 8), Expanded(child: Text(text, style: const TextStyle(fontSize: 12)))]));
}
void toast(BuildContext context, String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
Future<void> unavailable(BuildContext context, String feature) => showModalBottomSheet<void>(context: context, showDragHandle: true, isScrollControlled: true, builder: (c) => SafeArea(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [Text('$feature is not connected', style: Theme.of(c).textTheme.headlineSmall), const SizedBox(height: 12), const Text('This frontend cannot run cloud jobs or access social accounts yet. No request has been sent and nothing has been published.'), const SizedBox(height: 20), FilledButton(onPressed: () => Navigator.pop(c), child: const Text('Understood'))]))));
Future<bool> confirm(BuildContext context, String title, String body, {String action = 'Confirm'}) async => await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: Text(title), content: Text(body), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(action))])) ?? false;
class Field extends StatelessWidget {
  const Field(this.label, {super.key, required this.controller, this.lines = 1, this.required = false, this.hint, this.keyboard});
  final String label;
  final TextEditingController controller;
  final int lines;
  final bool required;
  final String? hint;
  final TextInputType? keyboard;
  @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 16), child: TextFormField(controller: controller, maxLines: lines, keyboardType: keyboard, decoration: InputDecoration(labelText: label, hintText: hint), validator: (v) => required && (v == null || v.trim().isEmpty) ? 'Enter $label' : null));
}
