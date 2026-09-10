// `show unawaited`, not a bare import: dart:async exports its own AsyncError,
// which would shadow Riverpod's and make the pattern match below ambiguous.
import 'dart:async' show unawaited;

import 'package:core/src/domain/exceptions/app_exception.dart';
import 'package:core/src/error/error_reporter.dart';
// riverpod_annotation re-exports AsyncValue, Ref and Provider, so importing
// flutter_riverpod as well would trip `unnecessary_import`.
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'async_error_handling.g.dart';

/// The app's crash sink.
///
/// Overridden at the root `ProviderScope` by `bootstrap`, which owns the
/// instance and hands the same one to the global error net and to
/// `AppProviderObserver`. The default is a no-op rather than an
/// `UnimplementedError` — unlike `buildConfigurationProvider`, this one has a
/// sensible answer for a widget test that builds a bare scope.
@Riverpod(keepAlive: true)
ErrorReporter errorReporter(Ref ref) => const NoopErrorReporter();

/// Typed error capture for a Notifier.
extension AsyncErrorHandling on Ref {
  /// Runs [body] and captures an expected [AppException] into an [AsyncValue].
  ///
  /// The Riverpod counterpart of the BLoC variant's `handleBlocAction`: only
  /// [AppException]s become error state. Anything else is rethrown so it
  /// reaches `PlatformDispatcher.onError` / `AppProviderObserver` instead of
  /// being swallowed.
  ///
  /// A captured failure is also breadcrumbed to [errorReporterProvider]: the
  /// UI renders a sentence, and the crash sink sees that it happened.
  ///
  /// An extension on [Ref] rather than a free function so it can reach the
  /// reporter without every Notifier threading one through. A Notifier's own
  /// `ref` is the receiver, so the call reads the same from any method:
  ///
  /// ```dart
  /// state = const AsyncValue.loading();
  /// state = await ref.guardAppException(
  ///   () => _loginUseCase.execute(input: email),
  /// );
  /// ```
  Future<AsyncValue<T>> guardAppException<T>(Future<T> Function() body) async {
    final result =
        await AsyncValue.guard(body, (error) => error is AppException);
    if (result case AsyncError(:final error) when error is AppException) {
      unawaited(read(errorReporterProvider).reportHandled(error));
    }
    return result;
  }
}

/// Normalizes an error taken off an [AsyncValue] to an [AppException].
///
/// UI code pattern matches on the app's own exception taxonomy, so anything
/// that is not already an [AppException] becomes an [UnknownException] rather
/// than leaking a raw error into a user-facing message.
AppException asAppException(Object error, [StackTrace? stackTrace]) {
  if (error is AppException) return error;
  return UnknownException(cause: error, stackTrace: stackTrace);
}
