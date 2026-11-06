import 'dart:ui';
import '../cloud/shift_cloud.dart';
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
  const ServiceNotice({super.key, this.text});
  final String? text;
  @override Widget build(BuildContext context) {
    final connected = ShiftCloud.user != null;
    final message = text ?? (connected
      ? 'Signed in to SHIFT • Drafts and settings sync securely.'
      : 'Offline workspace • Sign in to SHIFT to sync across devices.');
    return Padding(padding: const EdgeInsets.only(bottom: 16), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(connected ? Icons.cloud_done_outlined : Icons.cloud_off_outlined, size: 16), const SizedBox(width: 8), Expanded(child: Text(message, style: const TextStyle(fontSize: 12)))]));
  }
}

String shiftFriendlyError(Object? error) {
  final detail = (error ?? '').toString().trim();
  final raw = detail.toLowerCase();
  // Preserve only short, locally authored validation guidance, never raw
  // service exceptions, identifiers, URLs or provider responses.
  if (detail.length <= 160 &&
      RegExp(r'^(sign in to|choose |enter |select |approve this|write or generate)')
        .hasMatch(raw) &&
      !RegExp(r'(exception|supabase|provider_|api key|https?://)')
        .hasMatch(raw)) {
    return detail;
  }
  if (raw.contains('provider_timeout') || raw.contains('timed out') ||
      raw.contains('timeoutexception')) {
    return 'This request is taking longer than expected. Check your saved activity before trying again.';
  }
  if (raw.contains('generation_limit') || raw.contains('rate_limited') ||
      raw.contains('usage limit') || raw.contains('too many requests')) {
    return 'You have reached the current request limit. Please try again later.';
  }
  if (raw.contains('unauthorized') || raw.contains('jwt') ||
      raw.contains('invalid login') || raw.contains('invalid_credentials')) {
    return 'Your session needs attention. Sign in again and retry.';
  }
  if (raw.contains('not configured') || raw.contains('not_configured') ||
      raw.contains('missing api') || raw.contains('credentials_rejected')) {
    return 'This service is not available yet. Your saved work is still safe.';
  }
  if (raw.contains('socketexception') || raw.contains('network') ||
      raw.contains('connection') || raw.contains('fetch') ||
      raw.contains('failed host lookup')) {
    return 'Cannot connect right now. Check your connection and try again.';
  }
  if (raw.contains('storage') || raw.contains('save failed') ||
      raw.contains('persist')) {
    return 'Your changes could not be saved. Please try again.';
  }
  if (raw.contains('permission') || raw.contains('forbidden') ||
      raw.contains('access denied')) {
    return 'This action is not available for your account.';
  }
  return 'Something went wrong. Please try again. If it continues, check your connection or contact support.';
}

Future<void> showShiftMessage(BuildContext context, String title, String message) async {
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(title),
      content: Text(message),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Got it'),
        ),
      ],
    ),
  );
}

Future<void> showShiftError(BuildContext context, Object? error,
    {String title = 'Could not complete request', VoidCallback? onRetry}) async {
  if (!context.mounted) return;
  final description = shiftFriendlyError(error);
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      icon: const Icon(Icons.error_outline_rounded, size: 32),
      title: Text(title, textAlign: TextAlign.center),
      content: Text(description, textAlign: TextAlign.center),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        if (onRetry != null) TextButton(
          onPressed: () { Navigator.pop(dialogContext); onRetry(); },
          child: const Text('Retry'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Got it'),
        ),
      ],
    ),
  );
}

// When older screens provide an inline error, show it once as a dialog instead.
class ShiftErrorNotice extends StatefulWidget {
  const ShiftErrorNotice(this.error, {super.key, this.title = 'Could not complete request', this.onRetry});
  final String? error;
  final String title;
  final VoidCallback? onRetry;
  @override State<ShiftErrorNotice> createState() => _ShiftErrorNoticeState();
}
class _ShiftErrorNoticeState extends State<ShiftErrorNotice> {
  String? lastShown;
  @override void initState() { super.initState(); _schedule(); }
  @override void didUpdateWidget(covariant ShiftErrorNotice oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.error != oldWidget.error) _schedule();
  }
  void _schedule() {
    final error = widget.error;
    if (error == null || error.trim().isEmpty || error == lastShown) return;
    lastShown = error;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showShiftError(context, error, title: widget.title, onRetry: widget.onRetry);
    });
  }
  @override Widget build(BuildContext context) => const SizedBox.shrink();
}

bool _shiftLooksLikeError(String message) {
  final m = message.toLowerCase();
  return m.startsWith('sign in to') || m.startsWith('choose ') ||
      m.startsWith('enter ') || m.startsWith('select ') ||
      m.startsWith('approve this') ||
      m.contains('unavailable') ||
      m.contains('failed') || m.contains('could not') ||
      m.contains('unable to') || m.contains('error') ||
      m.contains('not configured') || m.contains('timed out') ||
      m.contains('rejected') || m.contains('cannot connect') ||
      m.contains('invalid response') || m.contains('request limit');
}

void toast(BuildContext context, String text) {
  if (!context.mounted) return;
  if (_shiftLooksLikeError(text)) {
    showShiftError(context, text);
    return;
  }
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

// A layout-shaped animated skeleton; respects the system's reduced-motion setting.
class ShiftSkeleton extends StatefulWidget {
  const ShiftSkeleton({super.key, this.rows = 3, this.showHeader = true});
  final int rows;
  final bool showHeader;
  @override State<ShiftSkeleton> createState() => _ShiftSkeletonState();
}
class _ShiftSkeletonState extends State<ShiftSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 1350),
  )..repeat(reverse: true);
  @override void dispose() { _animation.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reduced = MediaQuery.disableAnimationsOf(context);
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final strength = reduced ? .09 : .07 + _animation.value * .08;
        final shade = scheme.onSurface.withValues(alpha: strength);
        Widget bar(double width, double height) => FractionallySizedBox(
          widthFactor: width,
          alignment: Alignment.centerLeft,
          child: Container(height: height,
            decoration: BoxDecoration(color: shade,
              borderRadius: BorderRadius.circular(10))));
        return Panel(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.showHeader) ...[
              bar(.48, 18), const SizedBox(height: 20),
            ],
            for (var i = 0; i < widget.rows; i++) ...[
              bar(i.isEven ? .92 : .73, 13),
              const SizedBox(height: 13),
            ],
            const SizedBox(height: 4),
            Row(children: [
              Expanded(child: Container(height: 60,
                decoration: BoxDecoration(color: shade,
                  borderRadius: BorderRadius.circular(14)))),
              const SizedBox(width: 12),
              Expanded(child: Container(height: 60,
                decoration: BoxDecoration(color: shade,
                  borderRadius: BorderRadius.circular(14)))),
            ]),
          ],
        ));
      },
    );
  }
}

Future<void> unavailable(BuildContext context, String feature) => showModalBottomSheet<void>(context: context, showDragHandle: true, isScrollControlled: true, builder: (c) => SafeArea(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [Text('$feature is not connected', style: Theme.of(c).textTheme.headlineSmall), const SizedBox(height: 12), const Text('This feature is not currently available for this account. Other SHIFT Cloud features may still work. No post has been published by this action.'), const SizedBox(height: 20), FilledButton(onPressed: () => Navigator.pop(c), child: const Text('Understood'))]))));
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
