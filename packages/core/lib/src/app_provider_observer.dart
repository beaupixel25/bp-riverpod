import 'dart:async';
import 'dart:developer';

import 'package:core/src/domain/exceptions/app_exception.dart';
import 'package:core/src/error/error_reporter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Logs provider lifecycle, routes provider failures to the [ErrorReporter],
/// and signals when a session has expired.
///
/// **This is the only place a provider failure is reported.** Riverpod calls
/// [providerDidFail] for *every* error that lands in provider state, including
/// one a controller captured deliberately via `guardAppException` — assigning
/// an `AsyncError` to a Notifier's `state` fires it just as a throwing `build`
/// does. So `guardAppException` reports nothing itself; if it did, every
/// handled failure would be filed twice, once as a breadcrumb and once as a
/// crash.
///
/// The two lanes are told apart by type, which is what the taxonomy is for:
///
/// - an [AppException] is expected and renderable — the UI turned it into a
///   sentence, so it is breadcrumbed with [ErrorReporter.reportHandled];
/// - anything else escaped typing on its way out of the data layer, so it is a
///   crash and goes to [ErrorReporter.report] with its stack trace.
///
/// An [UnauthorizedException] additionally triggers [onUnauthorized] so the app
/// can route to sign-in. Errors that never reach a provider at all are still
/// covered by `FlutterError.onError` / `PlatformDispatcher.onError`, which
/// `bootstrap` points at the same sink.
final class AppProviderObserver extends ProviderObserver {
  /// Creates the observer. [reporter] and [onUnauthorized] default to no-ops so
  /// a generated app runs without extra wiring.
  const AppProviderObserver({
    this.reporter = const NoopErrorReporter(),
    this.onUnauthorized,
  });

  /// Sink both lanes report to: crashes and handled-failure breadcrumbs.
  final ErrorReporter reporter;

  /// Called when an [UnauthorizedException] reaches [providerDidFail].
  final void Function()? onUnauthorized;

  String _name(ProviderObserverContext context) =>
      context.provider.name ?? context.provider.runtimeType.toString();

  @override
  void didUpdateProvider(
    ProviderObserverContext context,
    Object? previousValue,
    Object? newValue,
  ) {
    super.didUpdateProvider(context, previousValue, newValue);
    log('didUpdateProvider(${_name(context)}, $previousValue -> $newValue)');
  }

  @override
  void providerDidFail(
    ProviderObserverContext context,
    Object error,
    StackTrace stackTrace,
  ) {
    // No `$stackTrace` in the message: a handled failure must not print a
    // trace, and this line runs whatever the reporter is — so interpolating it
    // here is the half of the output that swapping in a NoopErrorReporter
    // cannot turn off.
    log('providerDidFail(${_name(context)}, $error)');
    if (error is UnauthorizedException) {
      onUnauthorized?.call();
    }
    // One capture serves both ends here, unlike the injectable variants.
    // Riverpod calls this synchronously from `state =`, so the trace holds
    // the handler at frame 0 *and*, below its own frames, the controller
    // that started the action — which is what `invoked at:` digs out.
    final here = StackTrace.current;
    unawaited(
      error is AppException
          ? reporter.reportHandled(error, handledAt: here, invokedAt: here)
          : reporter.report(error, stackTrace),
    );
    super.providerDidFail(context, error, stackTrace);
  }
}
