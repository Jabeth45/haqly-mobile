import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:haqly_mobile/app/router.dart';
import 'package:haqly_mobile/core/l10n/generated/app_localizations.dart';
import 'package:haqly_mobile/core/theme/theme_dark.dart';

void main() {
  Widget buildTestableApp({GoRouter? router}) {
    return MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: createDarkTheme(),
      routerConfig: router ?? createAppRouter(),
    );
  }

  Finder navBarItem(String label) {
    return find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text(label),
    );
  }

  group('App Router & Shell Navigation', () {
    testWidgets(
      'renders 5 bottom navigation destinations and defaults to Home',
      (tester) async {
        await tester.pumpWidget(buildTestableApp());
        await tester.pumpAndSettle();

        // Verify default tab is Home
        expect(find.text('Home Screen'), findsOneWidget);

        // Verify all 5 navigation destinations exist in NavigationBar
        expect(navBarItem('Home'), findsOneWidget);
        expect(navBarItem('Add'), findsOneWidget);
        expect(navBarItem('Check'), findsOneWidget);
        expect(navBarItem('Ledger'), findsOneWidget);
        expect(navBarItem('History'), findsOneWidget);
      },
    );

    testWidgets('switches between tabs on navigation bar tap', (tester) async {
      await tester.pumpWidget(buildTestableApp());
      await tester.pumpAndSettle();

      // Tap 'Add' tab
      await tester.tap(navBarItem('Add'));
      await tester.pumpAndSettle();
      expect(find.text('Add Screen'), findsOneWidget);
      expect(find.text('Home Screen'), findsNothing);

      // Tap 'Check' tab
      await tester.tap(navBarItem('Check'));
      await tester.pumpAndSettle();
      expect(find.text('Check Screen'), findsOneWidget);

      // Tap 'Ledger' tab
      await tester.tap(navBarItem('Ledger'));
      await tester.pumpAndSettle();
      expect(find.text('Ledger Screen'), findsOneWidget);

      // Tap 'History' tab
      await tester.tap(navBarItem('History'));
      await tester.pumpAndSettle();
      expect(find.text('History Screen'), findsOneWidget);

      // Tap 'Home' tab
      await tester.tap(navBarItem('Home'));
      await tester.pumpAndSettle();
      expect(find.text('Home Screen'), findsOneWidget);
    });

    testWidgets('preserves tab state across switching (StatefulShellRoute)', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestableApp());
      await tester.pumpAndSettle();

      // Navigate to Add tab
      await tester.tap(navBarItem('Add'));
      await tester.pumpAndSettle();
      expect(find.text('Add Screen'), findsOneWidget);

      // Enter text into AddScreen's test input
      final inputFinder = find.byKey(const Key('add_screen_test_input'));
      expect(inputFinder, findsOneWidget);
      await tester.enterText(inputFinder, 'Preserved Test Input 123');
      await tester.pumpAndSettle();
      expect(find.text('Preserved Test Input 123'), findsOneWidget);

      // Switch to History tab
      await tester.tap(navBarItem('History'));
      await tester.pumpAndSettle();
      expect(find.text('History Screen'), findsOneWidget);

      // Switch back to Add tab
      await tester.tap(navBarItem('Add'));
      await tester.pumpAndSettle();
      expect(find.text('Add Screen'), findsOneWidget);

      // Verify entered text is still preserved
      expect(find.text('Preserved Test Input 123'), findsOneWidget);
    });

    testWidgets('navigates to Settings and back to Home', (tester) async {
      await tester.pumpWidget(buildTestableApp());
      await tester.pumpAndSettle();

      // On Home screen, tap the avatar
      final avatarFinder = find.byType(CircleAvatar);
      expect(avatarFinder, findsOneWidget);
      await tester.tap(avatarFinder);
      await tester.pumpAndSettle();

      // Verify Settings screen is displayed
      expect(find.text('Settings Screen'), findsOneWidget);

      // Tap Back button
      final backButton = find.byType(BackButton);
      expect(backButton, findsOneWidget);
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      // Verify returned to Home
      expect(find.text('Home Screen'), findsOneWidget);
    });
  });
}
