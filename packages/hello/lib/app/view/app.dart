import 'dart:async';
import 'package:core/core.dart'
    show App, AppThemeData, buildConfigurationProvider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hello/app/app_controller.dart';
import 'package:hello/l10n/l10n.dart' show AppLocalizations;
import 'package:hello/routing/routes.dart';

/// Root widget for the hello app, wiring its routes into core's [App].
class HelloApp extends ConsumerStatefulWidget {
  /// Creates the app.
  const HelloApp({super.key});

  @override
  ConsumerState<HelloApp> createState() => _HelloAppState();
}

class _HelloAppState extends ConsumerState<HelloApp> {
  late final GoRouter _router;
  late final GlobalKey<NavigatorState> _navigatorKey;

  @override
  void initState() {
    _navigatorKey = GlobalKey<NavigatorState>();
    _router = GoRouter(
      initialLocation: '/',
      routes: appRoutes,
      navigatorKey: _navigatorKey,
    );
    // Provider state cannot be mutated during initState, so the app-wide
    // startup load is kicked off once the first frame is scheduled.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => unawaited(ref.read(appControllerProvider.notifier).start()),
    );
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);

    // AppThemeData.fallback reads MediaQuery, which doesn't exist at the root
    // passed to runApp — provide one from the view before building the theme.
    return MediaQuery.fromView(
      view: View.of(context),
      child: Builder(
        builder: (context) => App(
          // Theme mode and locale come from the app-wide state holder, so a
          // settings screen can switch both live. Layer app branding on the
          // design-system defaults by passing `extensions:` here.
          theme: AppThemeData.fallback(
            context,
            themeMode: state.themeMode,
          ),
          locale: state.locale,
          router: _router,
          appTitle: ref.watch(buildConfigurationProvider).appTitle,
          appLocalizationDelegate: AppLocalizations.delegate,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
  }
}
