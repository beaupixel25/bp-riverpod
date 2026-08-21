import 'dart:async';
import 'dart:developer';

import 'package:core/src/domain/exceptions/app_exception.dart';
import 'package:core/src/error/error_reporter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Logs provider lifecycle, reports unhandled provider failures to the crash
/// [ErrorReporter], and signals when a session has expired.
///
/// An error reaching [providerDidFail] is one no notifier captured as state, so
/// it is treated as a crash: normalized to an [AppException] and forwarded to
/// the [reporter] with the original cause + stack trace. An
/// [UnauthorizedException] additionally triggers [onUnauthorized] so the app
/// can route to sign-in. A failure a controller turned into `AsyncValue.error`
/// via `guardAppException` is handled state and never arrives here.
final class AppProviderObserver extends ProviderObserver {
  /// Creates the observer. [reporter] and [onUnauthorized] default to no-ops so
  /// a generated app runs without extra wiring.
  const AppProviderObserver({
    this.reporter = const NoopErrorReporter(),
    this.onUnauthorized,
  });

  /// Crash sink that unhandled provider errors are reported to.
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
    log('providerDidFail(${_name(context)}, $error, $stackTrace)');
    final normalized = error is AppException
        ? error
        : UnknownException(cause: error, stackTrace: stackTrace);
    if (normalized is UnauthorizedException) {
      onUnauthorized?.call();
    }
    unawaited(
      reporter.report(
        normalized.cause ?? error,
        normalized.stackTrace ?? stackTrace,
      ),
    );
    super.providerDidFail(context, error, stackTrace);
  }
}
