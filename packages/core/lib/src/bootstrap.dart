import 'dart:async';
import 'dart:developer';
import 'dart:ui' show PlatformDispatcher;

import 'package:core/src/app_provider_observer.dart';
import 'package:core/src/constants/environment.dart';
import 'package:core/src/error/error_reporter.dart';
import 'package:core/src/presentation/riverpod/async_error_handling.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
// `Override` is exported by riverpod_annotation, not flutter_riverpod.
import 'package:riverpod_annotation/riverpod_annotation.dart' show Override;

/// Bootstraps the app: installs the global error net, builds the root
/// `ProviderScope` overrides for [environment], and runs the app.
///
/// [overridesBuilder] is the composition root — typically the app's
/// `buildOverrides`. It is async so a dependency that must be resolved before
/// the first frame (the `@preResolve` equivalent) can be awaited here and
/// supplied via `overrideWithValue`.
///
/// [reporter] is the crash sink, and this function owns it: pass one to
/// forward crashes to Sentry/Crashlytics/etc., or pass nothing and get a
/// `ConsoleErrorReporter`. Whichever it is, the same instance is installed in
/// the global error net, handed to the observer, and bound to
/// `errorReporterProvider` at the root scope — so the crash lane and the
/// handled lane report to one object and no `main_<flavor>.dart` has to wire
/// anything.
///
/// [onUnauthorized] is invoked when an `UnauthorizedException` reaches the
/// observer.
Future<void> bootstrap(
  FutureOr<Widget> Function() builder, {
  required Environment environment,
  required Future<List<Override>> Function(Environment) overridesBuilder,
  ErrorReporter? reporter,
  void Function()? onUnauthorized,
}) async {
  final sink = reporter ?? const ConsoleErrorReporter();

  FlutterError.onError = (details) {
    log(details.exceptionAsString(), stackTrace: details.stack);
    unawaited(
      sink.report(details.exception, details.stack ?? StackTrace.current),
    );
  };

  // The async catch-all: uncaught futures, platform channels, anything that
  // escapes `main`. Deliberately NOT paired with a `runZonedGuarded` — a custom
  // zone handles in-zone errors itself, so they never reach the root zone and
  // this handler would be dead for everything except errors raised outside the
  // zone. Flutter has recommended this over zones since 3.3, which also avoids
  // the start-up cost a zone imposes on Dart's core libraries.
  PlatformDispatcher.instance.onError = (error, stackTrace) {
    log(error.toString(), stackTrace: stackTrace);
    unawaited(sink.report(error, stackTrace));
    return true;
  };

  ErrorWidget.builder = (details) => const Material(
        child: Center(child: Text('Something went wrong.')),
      );

  try {
    // Before overridesBuilder: it may await plugin-backed dependencies.
    WidgetsFlutterBinding.ensureInitialized();
    usePathUrlStrategy();

    final overrides = await overridesBuilder(environment);

    runApp(
      ProviderScope(
        // The reporter override goes first so an app's own `buildOverrides`
        // can still replace it: a later entry for the same provider wins.
        overrides: [
          errorReporterProvider.overrideWithValue(sink),
          ...overrides,
        ],
        observers: [
          AppProviderObserver(
            reporter: sink,
            onUnauthorized: onUnauthorized,
          ),
        ],
        child: await builder(),
      ),
    );
    // Composition is the one place a bare catch is right: anything at all
    // going wrong here means there is no app, and the alternative is a hang.
    // ignore: avoid_catches_without_on_clauses
  } catch (error, stackTrace) {
    // Composition failed, so nothing called `runApp`. `ErrorWidget.builder`
    // cannot cover this — it replaces a widget that threw during build, and
    // there is no tree yet — so render the surface here.
    //
    // A `runZonedGuarded` cannot do this job at all: given an async body that
    // throws, it routes the error to its handler and then abandons the future
    // it returned, so `await` on it never returns and `main()` hangs.
    log(error.toString(), stackTrace: stackTrace);
    unawaited(sink.report(error, stackTrace));
    runApp(const _BootstrapFailure());
  }
}

/// Shown when composition itself failed, so there is no app to render.
///
/// Self-contained on purpose: this is a `runApp` root, so nothing above it
/// supplies the `Directionality` that [ErrorWidget.builder]'s bare [Material]
/// gets from the tree it is spliced into.
class _BootstrapFailure extends StatelessWidget {
  const _BootstrapFailure();

  @override
  Widget build(BuildContext context) => const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(child: Text('Something went wrong.')),
        ),
      );
}
