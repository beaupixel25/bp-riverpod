import 'package:core/src/domain/exceptions/app_exception.dart';
import 'package:core/src/error/error_reporter.dart';
// riverpod_annotation re-exports AsyncValue, Ref and Provider, so importing
// flutter_riverpod as well would trip `unnecessary_import`.
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'async_error_handling.g.dart';

/// The app's crash sink, reachable from provider code.
///
/// Overridden at the root `ProviderScope` by `bootstrap`, which owns the
/// instance and hands the same one to the global error net and to
/// `AppProviderObserver`. Reporting a provider failure is the observer's job,
/// so nothing in `core` reads this — it is here for app code that wants to
/// report something no provider ever failed on, and it is what makes "the
/// observer and the container hold the same object" assertable.
///
/// The default is a no-op rather than an `UnimplementedError` — unlike
/// `buildConfigurationProvider`, this one has a sensible answer for a widget
/// test that builds a bare scope.
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
  /// A captured failure is still breadcrumbed to the crash sink — but by
  /// `AppProviderObserver`, not here. Assigning the returned [AsyncError] to a
  /// Notifier's `state` fires `ProviderObserver.providerDidFail`, so the
  /// observer already sees every failure this captures. Reporting from both
  /// places filed each handled failure twice, once as a breadcrumb and once as
  /// a crash complete with a stack trace.
  ///
  /// An extension on [Ref] rather than a free function so a Notifier's own
  /// `ref` is the receiver and the call reads the same from any method:
  ///
  /// ```dart
  /// state = const AsyncValue.loading();
  /// state = await ref.guardAppException(
  ///   () => _loginUseCase.execute(input: email),
  /// );
  /// ```
  Future<AsyncValue<T>> guardAppException<T>(Future<T> Function() body) =>
      AsyncValue.guard(body, (error) => error is AppException);
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
