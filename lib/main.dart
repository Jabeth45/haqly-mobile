import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:haqly_mobile/app/router.dart';
import 'package:haqly_mobile/core/config/app_config.dart';
import 'package:haqly_mobile/core/l10n/generated/app_localizations.dart';
import 'package:haqly_mobile/core/theme/theme_dark.dart';
import 'package:haqly_mobile/core/theme/theme_light.dart';
import 'package:haqly_mobile/data/remote/supabase_client.dart';
import 'package:haqly_mobile/features/auth/providers/auth_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase if compile-time credentials are provided
  if (AppConfig.isConfigured) {
    await initializeSupabase();
  }

  runApp(const ProviderScope(child: HaqlyApp()));
}

/// The root widget of the Haqly application.
class HaqlyApp extends ConsumerStatefulWidget {
  const HaqlyApp({super.key, this.router});

  final GoRouter? router;

  @override
  ConsumerState<HaqlyApp> createState() => _HaqlyAppState();
}

class _HaqlyAppState extends ConsumerState<HaqlyApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router =
        widget.router ??
        createAppRouter(
          authStateProvider: () => ref.read(authStateProvider),
          refreshListenable: ref.read(authListenableProvider),
        );
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
