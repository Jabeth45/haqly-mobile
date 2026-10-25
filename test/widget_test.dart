import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haqly_mobile/core/l10n/generated/app_localizations.dart';
import 'package:haqly_mobile/core/theme/theme_dark.dart';
import 'package:haqly_mobile/core/theme/theme_light.dart';
import 'package:haqly_mobile/main.dart';

void main() {
  testWidgets('App renders shell and theme smoke test', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const HaqlyApp());
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Home Screen'), findsOneWidget);
  });

  testWidgets('Amharic locale renders Ge’ez strings correctly', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('am'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: createLightTheme(),
        darkTheme: createDarkTheme(),
        themeMode: ThemeMode.dark,
        home: Builder(
          builder: (context) {
            final l10n = AppLocalizations.of(context)!;
            return Scaffold(
              body: Column(
                children: [
                  Text(l10n.appName),
                  Text(l10n.tabLedger),
                  Text(l10n.save),
                ],
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Ge'ez script rendered without issue
    expect(find.text('ሀቅሊ'), findsOneWidget);
    expect(find.text('ብድርና እዳ'), findsOneWidget);
    expect(find.text('አስቀምጥ'), findsOneWidget);
  });
}
