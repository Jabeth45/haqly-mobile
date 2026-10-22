import 'package:flutter/material.dart';
import 'package:haqly_mobile/core/l10n/generated/app_localizations.dart';
import 'package:haqly_mobile/core/theme/theme_dark.dart';
import 'package:haqly_mobile/core/theme/theme_light.dart';
import 'package:haqly_mobile/core/theme/tokens.dart';

void main() {
  runApp(const HaqlyApp());
}

class HaqlyApp extends StatelessWidget {
  const HaqlyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Haqly',
      debugShowCheckedModeBanner: false,
      theme: createLightTheme(),
      darkTheme: createDarkTheme(),
      themeMode: ThemeMode.dark,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: Center(child: _AppPlaceholder())),
    );
  }
}

class _AppPlaceholder extends StatelessWidget {
  const _AppPlaceholder();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = context.tokens;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          l10n.appName,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: tokens.accent,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.appTagline,
          style: TextStyle(fontSize: 14, color: tokens.ink2),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
