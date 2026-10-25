import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:haqly_mobile/app/router.dart';
import 'package:haqly_mobile/core/l10n/generated/app_localizations.dart';
import 'package:haqly_mobile/core/theme/theme_dark.dart';
import 'package:haqly_mobile/core/theme/theme_light.dart';

void main() {
  runApp(const HaqlyApp());
}

/// The root widget of the Haqly application.
class HaqlyApp extends StatefulWidget {
  const HaqlyApp({super.key, this.router});

  final GoRouter? router;

  @override
  State<HaqlyApp> createState() => _HaqlyAppState();
}

class _HaqlyAppState extends State<HaqlyApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = widget.router ?? createAppRouter();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Haqly',
      debugShowCheckedModeBanner: false,
      theme: createLightTheme(),
      darkTheme: createDarkTheme(),
      themeMode: ThemeMode.dark,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: _router,
    );
  }
}
