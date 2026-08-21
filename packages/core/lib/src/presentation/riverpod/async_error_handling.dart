// `show unawaited`, not a bare import: dart:async exports its own AsyncError,
// which would shadow Riverpod's and make the pattern match below ambiguous.
import 'dart:async' show unawaited;

import 'package:core/src/domain/exceptions/app_exception.dart';
import 'package:core/src/error/error_reporter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Runs [body] and captures an expected [AppException] into an [AsyncValue].
///
/// The Riverpod counterpart of the BLoC variant's `handleBlocAction`: only
/// [AppException]s become error state. Anything else is rethrown so it reaches
/// `PlatformDispatcher.onError` / `AppProviderObserver` instead of being
/// swallowed.
///
/// A captured failure is also breadcrumbed to `appErrorReporter`: the UI
/// renders a sentence, and the crash sink sees that it happened.
///
/// ```dart
/// state = const AsyncValue.loading();
/// state = await guardAppException(() => _loginUseCase.execute(input: email));
/// ```
Future<AsyncValue<T>> guardAppException<T>(Future<T> Function() body) async {
  final result = await AsyncValue.guard(body, (error) => error is AppException);
  if (result case AsyncError(:final error) when error is AppException) {
    unawaited(appErrorReporter.reportHandled(error));
  }
  return result;
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
