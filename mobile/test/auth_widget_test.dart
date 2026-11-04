import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shift_mobile/features/auth/auth_screen.dart';

void main() {
  Widget app(String mode) => ProviderScope(
    child: MaterialApp(home: AuthScreen(mode: mode)),
  );

  testWidgets('registration requires an email and a sufficiently long password',
      (tester) async {
    await tester.pumpWidget(app('register'));
    expect(find.text('Display name'), findsWidgets);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);

    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Register'));
    await tester.tap(find.widgetWithText(FilledButton, 'Register'));
    await tester.pump();
    expect(find.text('Enter a valid email'), findsOneWidget);
    expect(find.text('Use at least 8 characters'), findsOneWidget);
  });

  testWidgets('password reset does not require a password', (tester) async {
    await tester.pumpWidget(app('reset'));
    expect(find.text('Send reset link'), findsOneWidget);
    expect(find.text('Password'), findsNothing);
    expect(find.text('Email'), findsOneWidget);
  });

  testWidgets('email verification form uses resend action', (tester) async {
    await tester.pumpWidget(app('verify'));
    expect(find.text('Resend verification email'), findsOneWidget);
    expect(find.text('Email verification help'), findsOneWidget);
  });
}
