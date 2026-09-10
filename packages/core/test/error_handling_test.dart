// The tests deliberately throw raw objects to exercise error mapping.
// ignore_for_file: only_throw_errors

import 'dart:io';

import 'package:core/core.dart';
// AsyncValue and friends come from Riverpod. Note dart:async is deliberately
// NOT imported: its own `AsyncError` would shadow Riverpod's generic one.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _TestRepository extends BaseRepository {
  AppException mapError(Object error) =>
      handleException(error, StackTrace.current);

  Future<int> ok() => guard(() async => 1);

  Future<int> boom(Object error) => guard(() async => throw error);
}

class _TestUseCase extends UseCase<Object, int> {
  _TestUseCase(this._body);

  final Future<int> Function() _body;

  @override
  Future<int> call({Object? input}) => _body();
}

void main() {
  group('BaseRepository.guard (data layer)', () {
    final repo = _TestRepository();

    test('passes a value through untouched', () async {
      expect(await repo.ok(), 1);
    });

    test('maps a SocketException to NetworkException', () async {
      await expectLater(
        repo.boom(const SocketException('offline')),
        throwsA(isA<NetworkException>()),
      );
    });

    test('maps a FormatException to ServerException', () async {
      // Not ValidationException, deliberately. A FormatException reaching
      // `guard` came from decoding a payload, never from user input, so the
      // copy must be the generic sentence — see the toUserMessage assertion
      // below, which is the half that says why this mapping matters.
      await expectLater(
        repo.boom(const FormatException('bad')),
        throwsA(isA<ServerException>()),
      );
      expect(
        repo.mapError(const FormatException('bad')).toUserMessage(
              _FakeMessages(),
            ),
        'generic',
      );
    });

    test('passes a typed AppException through unchanged', () async {
      await expectLater(
        repo.boom(const UnauthorizedException(message: 'nope')),
        throwsA(isA<UnauthorizedException>()),
      );
    });

    test('maps an unknown error to UnknownException', () async {
      await expectLater(
        repo.boom(StateError('bad')),
        throwsA(isA<UnknownException>()),
      );
    });
  });

  group('UseCase.execute (domain layer)', () {
    test('passes a typed AppException through unchanged', () async {
      final useCase = _TestUseCase(
        () async => throw const NotFoundException(message: 'missing'),
      );
      await expectLater(
        useCase.execute(),
        throwsA(isA<NotFoundException>()),
      );
    });

    test('normalizes a raw error to UnknownException', () async {
      final useCase = _TestUseCase(() async => throw StateError('bad'));
      await expectLater(
        useCase.execute(),
        throwsA(isA<UnknownException>()),
      );
    });
  });

  group('Ref.guardAppException (presentation layer)', () {
    test('captures an AppException as AsyncError', () async {
      final result = await runGuarded<int>(
        () async => throw const UnauthorizedException(message: 'nope'),
      );

      expect(result, isA<AsyncError<int>>());
      expect(result.error, isA<UnauthorizedException>());
    });

    test('captures a value as AsyncData', () async {
      final result = await runGuarded<int>(() async => 7);

      expect(result, isA<AsyncData<int>>());
      expect(result.value, 7);
    });

    // Anything that is not an AppException is deliberately NOT captured: it
    // escapes to PlatformDispatcher.onError / AppProviderObserver instead of
    // becoming quiet error state.
    test('rethrows a non-AppException', () async {
      await expectLater(
        runGuarded<int>(() async => throw StateError('bad')),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('asAppException', () {
    test('passes an AppException through unchanged', () {
      const original = ForbiddenException(message: 'no');
      expect(asAppException(original), same(original));
    });

    test('wraps anything else as UnknownException', () {
      expect(asAppException(StateError('bad')), isA<UnknownException>());
    });
  });

  group('AppExceptionL10n.toUserMessage (presentation layer)', () {
    final messages = _FakeMessages();

    test('maps typed exceptions to their localized strings', () {
      expect(const NetworkException().toUserMessage(messages), 'network');
      expect(const UnauthorizedException().toUserMessage(messages), 'session');
      expect(const ForbiddenException().toUserMessage(messages), 'forbidden');
      expect(const NotFoundException().toUserMessage(messages), 'notFound');
      expect(const ValidationException().toUserMessage(messages), 'validation');
      expect(const ServerException().toUserMessage(messages), 'generic');
      expect(const UnknownException().toUserMessage(messages), 'generic');
    });

    test('shows a DisplayableException message directly', () {
      expect(
        const DisplayableException(message: 'hi').toUserMessage(messages),
        'hi',
      );
    });

    test('a recognised backend code beats the exception type', () {
      expect(
        const ValidationException(code: 'CODED').toUserMessage(messages),
        'coded',
      );
    });

    test('an unknown or absent code falls back to the type', () {
      expect(
        const ValidationException(code: 'NOPE').toUserMessage(messages),
        'validation',
      );
      expect(const ValidationException().toUserMessage(messages), 'validation');
    });
  });

  group('handled failures reach the sink as breadcrumbs', () {
    test('a captured AppException is breadcrumbed, not reported', () async {
      // Handled is not the same as invisible: the UI showed a sentence, and
      // the crash sink still has to know it happened.
      final reporter = _RecordingReporter();

      await runGuarded<int>(
        () async => throw const ServerException(code: '500'),
        reporter: reporter,
      );

      expect(reporter.handled.single.code, '500');
      expect(reporter.crashes, isEmpty);
    });

    test('the default reporter is a no-op, not a throw', () async {
      // Nothing overrides errorReporterProvider here. Resolving it must still
      // work: a bare scope is what a widget test builds, and a lookup that
      // threw would turn a handled failure into a crash inside the very code
      // path meant to prevent one.
      final result = await runGuarded<int>(
        () async => throw const ServerException(code: '500'),
      );

      expect(result, isA<AsyncError<int>>());
    });
  });
}

/// Runs [body] through `Ref.guardAppException` inside a throwaway container.
///
/// A `Provider` body is the smallest thing that owns a `Ref`, which is what
/// the extension needs. Passing [reporter] overrides `errorReporterProvider`
/// the same way `bootstrap` does at the root scope.
Future<AsyncValue<T>> runGuarded<T>(
  Future<T> Function() body, {
  ErrorReporter? reporter,
}) {
  final probe = Provider<Future<AsyncValue<T>>>(
    (ref) => ref.guardAppException<T>(body),
  );
  final container = ProviderContainer.test(
    overrides: [
      if (reporter != null) errorReporterProvider.overrideWithValue(reporter),
    ],
  );
  return container.read(probe);
}

/// Captures both lanes so a test can tell a breadcrumb from a crash.
class _RecordingReporter implements ErrorReporter {
  final List<Object> crashes = [];
  final List<AppException> handled = [];

  @override
  Future<void> report(Object error, StackTrace stackTrace) async =>
      crashes.add(error);

  @override
  Future<void> reportHandled(AppException error) async => handled.add(error);
}

class _FakeMessages implements ErrorMessages {
  @override
  String get errorGeneric => 'generic';
  @override
  String get errorNetwork => 'network';
  @override
  String get errorSessionExpired => 'session';
  @override
  String get errorForbidden => 'forbidden';
  @override
  String get errorNotFound => 'notFound';
  @override
  String get errorValidation => 'validation';
  // Declared, not inherited: `implements` takes the interface, never the
  // implementation, even when the interface supplies a body.
  @override
  String? forCode(String code) => switch (code) {
        'CODED' => 'coded',
        _ => null,
      };
}
