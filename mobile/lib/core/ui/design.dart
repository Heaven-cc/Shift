import 'dart:ui';
import '../cloud/shift_cloud.dart';
import 'package:flutter/material.dart';

ThemeData shiftTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  const accent = Color(0xFF7777FF);
  final ink = dark ? const Color(0xFFF4F4F7) : const Color(0xFF17171C);
  final base = dark ? const Color(0xFF09090C) : const Color(0xFFF6F6F8);
  final surface = dark ? const Color(0xFF15151A) : Colors.white;
  final muted = dark ? const Color(0xFF9999A5) : const Color(0xFF777783);
  final outline = ink.withValues(alpha: dark ? .10 : .075);
  final scheme = ColorScheme.fromSeed(seedColor: accent, brightness: brightness).copyWith(
    primary: dark ? const Color(0xFFB5B5FF) : const Color(0xFF5555D9),
    onPrimary: Colors.white, secondary: accent, surface: surface, onSurface: ink,
    surfaceContainerHighest: dark ? const Color(0xFF202027) : const Color(0xFFECECF1),
    outline: outline, outlineVariant: outline);
  final radius = BorderRadius.circular(16);
  return ThemeData(useMaterial3: true, brightness: brightness, colorScheme: scheme,
    scaffoldBackgroundColor: base,
    appBarTheme: AppBarTheme(backgroundColor: base, foregroundColor: ink, elevation: 0,
      scrolledUnderElevation: 0, centerTitle: false,
      titleTextStyle: TextStyle(color: ink, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -.4)),
    cardTheme: CardThemeData(color: surface, elevation: 0, margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: radius, side: BorderSide(color: outline))),
    inputDecorationTheme: InputDecorationTheme(filled: true,
      fillColor: dark ? const Color(0xFF17171D) : const Color(0xFFF0F0F4),
      hintStyle: TextStyle(color: muted), labelStyle: TextStyle(color: muted),
      border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: outline)),
      focusedBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: scheme.primary, width: 1.4)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15)),
    filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(minimumSize: const Size(48, 48),
      elevation: 0, backgroundColor: scheme.primary, foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: const TextStyle(fontWeight: FontWeight.w700))),
    outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(minimumSize: const Size(46, 46),
      foregroundColor: ink, side: BorderSide(color: outline),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)))),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: scheme.primary,
      textStyle: const TextStyle(fontWeight: FontWeight.w700))),
    chipTheme: ChipThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
      side: BorderSide(color: outline), labelStyle: TextStyle(color: ink)),
    dividerTheme: DividerThemeData(color: outline, thickness: 1, space: 1),
    snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
    dialogTheme: DialogThemeData(backgroundColor: surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22))),
    textTheme: TextTheme(
      displayLarge: TextStyle(fontSize: 38, height: 1.05, fontWeight: FontWeight.w800, letterSpacing: -1.8, color: ink),
      headlineLarge: TextStyle(fontSize: 30, height: 1.12, fontWeight: FontWeight.w800, letterSpacing: -1.15, color: ink),
      headlineMedium: TextStyle(fontSize: 25, height: 1.15, fontWeight: FontWeight.w700, letterSpacing: -.7, color: ink),
      headlineSmall: TextStyle(fontSize: 21, fontWeight: FontWeight.w700, letterSpacing: -.5, color: ink),
      titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: ink),
      titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ink),
      bodyLarge: TextStyle(fontSize: 14, height: 1.5, color: ink),
      bodyMedium: TextStyle(fontSize: 13, height: 1.45, color: muted),
      bodySmall: TextStyle(fontSize: 11, height: 1.4, color: muted),
      labelLarge: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ink)));
}
class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.glass = false, this.padding = const EdgeInsets.all(16)});
  final Widget child; final bool glass; final EdgeInsets padding;
  @override Widget build(BuildContext context) {
    final theme = Theme.of(context); final dark = theme.brightness == Brightness.dark;
    final radius = BorderRadius.circular(17);
    final box = Container(width: double.infinity, padding: padding,
      decoration: BoxDecoration(color: theme.colorScheme.surface.withValues(alpha: glass ? (dark ? .78 : .84) : 1),
        borderRadius: radius, border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: .8)),
        boxShadow: glass ? [BoxShadow(color: Colors.black.withValues(alpha: dark ? .12 : .025), blurRadius: 24, offset: const Offset(0, 8))] : null),
      child: child);
    if (!glass) return box;
    return ClipRRect(borderRadius: radius, child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14), child: box));
  }
}
class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children});
  final List<Widget> children;
  @override Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;
    return Stack(clipBehavior: Clip.hardEdge, children: [
      Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: dark
            ? [const Color(0xFF09090D), const Color(0xFF10101A), const Color(0xFF09090D)]
            : [const Color(0xFFF8F8FC), const Color(0xFFF0F0FA), const Color(0xFFF8F8FC)],
        ),
      ))),
      Positioned(top: -118, right: -92, child: Container(
        width: 270, height: 270,
        decoration: BoxDecoration(shape: BoxShape.circle,
          gradient: RadialGradient(colors: [
            accent.withValues(alpha: dark ? .22 : .13),
            accent.withValues(alpha: 0),
          ]),
        ),
      )),
      Positioned(top: 185, left: -118, child: Transform.rotate(
        angle: .42,
        child: Container(width: 190, height: 190,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(38),
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [
                const Color(0xFF38C8E8).withValues(alpha: dark ? .075 : .09),
                const Color(0xFF7777FF).withValues(alpha: dark ? .045 : .06),
              ]),
            border: Border.all(color: accent.withValues(alpha: .07)),
          ),
        ),
      )),
      Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 32),
          children: children,
        ),
      )),
    ]);
  }
}
class Heading extends StatelessWidget {
  const Heading(this.title, this.subtitle, {super.key});
  final String title, subtitle;
  @override Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: GradientHero(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 8),
        Text(subtitle, style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.5)),
      ],
    )),
  );
}
class GradientHero extends StatelessWidget {
  const GradientHero({super.key, required this.child, this.padding = const EdgeInsets.all(18)});
  final Widget child;
  final EdgeInsets padding;
  @override Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Stack(children: [
        Container(
          width: double.infinity,
          padding: padding,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: dark
                ? [const Color(0xFF202044), const Color(0xFF17172B), const Color(0xFF17171D)]
                : [const Color(0xFFE9E9FF), const Color(0xFFF3F1FF), const Color(0xFFE9F8FC)],
            ),
            border: Border.all(color: primary.withValues(alpha: .16)),
            borderRadius: BorderRadius.circular(22),
          ),
          child: child,
        ),
        Positioned(right: -28, top: -38, child: Transform.rotate(
          angle: .48,
          child: Container(width: 128, height: 128,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(colors: [
                const Color(0xFF39C8E8).withValues(alpha: .24),
                primary.withValues(alpha: .14),
              ]),
              border: Border.all(color: Colors.white.withValues(alpha: .18)),
            ),
          ),
        )),
        Positioned(right: 42, bottom: -62, child: Container(
          width: 118, height: 118,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFFFA45E).withValues(alpha: dark ? .08 : .12),
          ),
        )),
      ]),
    );
  }
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
