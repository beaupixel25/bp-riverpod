// The tests deliberately throw raw objects to exercise error mapping.
// ignore_for_file: only_throw_errors

// `show FutureOr`, not a bare import: dart:async's own `AsyncError` would
// shadow Riverpod's generic one and break every `isA<AsyncError<int>>()` here.
import 'dart:async' show FutureOr;
import 'dart:io';

import 'package:core/core.dart';
// AsyncValue and friends come from Riverpod.
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

    // `ConsoleErrorReporter.reportHandled` logs `handled: $error`, so the
    // breadcrumb is worth exactly as much as this string. Collapse it back to
    // the bare runtime type and every handled failure logs the same
    // unactionable `UnknownException` line.
    test('the mapped exception names its cause, for the breadcrumb', () {
      final mapped = repo.mapError(UnimplementedError());
      expect('$mapped', contains('UnknownException'));
      expect('$mapped', contains('UnimplementedError'));
    });
  });

  group('ConsoleErrorReporter.formatHandled', () {
    // Asserted on the string rather than on the log, because
    // `dart:developer`'s sink is not observable from a test — and the string
    // is the whole point of the breadcrumb.
    test('names the handling block, frame 0 and unfiltered', () {
      // `handled at:` is the code that handled the failure — the
      // `on AppException` block — so it is frame 0 of the trace the caller
      // captured there, kept whatever package it lives in. Filtering `core`
      // out of it would step past the handler and blame its caller.
      final line = const ConsoleErrorReporter().formatHandled(
        const ServerException(code: '500'),
        handledAt: StackTrace.fromString(
          '#0      AppProviderObserver.providerDidFail '
          '(package:core/src/app_provider_observer.dart:73:22)\n'
          '#1      ElementWithFuture.onError '
          '(package:riverpod/src/core/element.dart:114:19)',
        ),
      );

      expect(line, contains('handled at: AppProviderObserver.providerDidFail'));
      expect(line, isNot(contains('ElementWithFuture')));
    });

    test('names the throw site verbatim, even inside core', () {
      // The origin is frame 0 unfiltered: `ApiClient` throws from inside
      // `core`, and filtering that out would blame the caller instead.
      final line = const ConsoleErrorReporter().formatHandled(
        const ServerException(code: '500'),
        thrownAt: StackTrace.fromString(
          '#0      ApiClient._decode '
          '(package:core/src/data/services/api_client.dart:88:7)',
        ),
      );

      expect(line, contains('thrown at:  ApiClient._decode'));
    });

    test('reportHandled funnels into report as the handled lane', () async {
      // The contract an implementation depends on: it writes `report` only,
      // and `handled` is what tells the two lanes apart. Asserted on a
      // reporter that overrides nothing else, so a `reportHandled` that
      // stopped delegating would fail here rather than silently bypass
      // whatever a vendor subclass does in `report`.
      final reporter = _RecordingReporter();
      final thrown =
          StackTrace.fromString('#0      Repo.get (package:hello/r.dart:1:1)');
      final at =
          StackTrace.fromString('#0      Vm.load (package:hello/v.dart:2:2)');

      await reporter.reportHandled(
        ServerException(code: '500', stackTrace: thrown),
        handledAt: at,
      );

      expect(reporter.handled.single.code, '500');
      expect(reporter.crashes, isEmpty);
      expect(reporter.handledFrom.single, same(at));
      // The throw site rides through as `report`'s positional stack trace.
      expect(reporter.traces.single, same(thrown));
    });

    test('an exception with no trace funnels through as StackTrace.empty',
        () async {
      final reporter = _RecordingReporter();

      await reporter.reportHandled(const ServerException(code: '500'));

      expect(reporter.traces.single, same(StackTrace.empty));
    });

    test('invoked at names the caller, skipping the plumbing', () {
      // The one filtered frame. Whoever captured `invokedAt` is itself the
      // top of that trace, so frame 0 is always the helper — the caller sits
      // under it, and under the framework that called the helper.
      final line = const ConsoleErrorReporter().formatHandled(
        const ServerException(code: '500'),
        invokedAt: StackTrace.fromString(
          '#0      Command.run '
          '(package:core/src/presentation/listenable/command.dart:47:29)\n'
          '#1      Command0.execute '
          '(package:core/src/presentation/listenable/command.dart:96:29)\n'
          '#2      SignupViewModel.submit '
          '(package:hello/features/onboarding/signup_view_model.dart:29:14)',
        ),
      );

      expect(line, contains('invoked at: SignupViewModel.submit'));
      expect(line, isNot(contains('Command0.execute')));
    });

    test('the frame lines are a tree under the header', () {
      // Markers rather than an indent: `dart:developer` hands the console one
      // multi-line string, a console may strip leading whitespace, and
      // anything else logging concurrently interleaves the lines.
      final line = const ConsoleErrorReporter(colored: false).formatHandled(
        const ServerException(code: '500'),
        thrownAt:
            StackTrace.fromString('#0      A.b (package:hello/a.dart:1:1)'),
        handledAt:
            StackTrace.fromString('#0      C.d (package:hello/c.dart:2:2)'),
        invokedAt:
            StackTrace.fromString('#0      E.f (package:hello/e.dart:3:3)'),
      );
      final lines = line.split('\n');

      expect(lines.first, startsWith('handled: '));
      expect(lines[1], startsWith('\u251c\u2500 thrown at:'));
      expect(lines[2], startsWith('\u251c\u2500 handled at:'));
      // The last row closes the group, whichever row that turns out to be.
      expect(lines[3], startsWith('\u2514\u2500 invoked at:'));
    });

    test('colour is opt-out and leaves no escape codes behind', () {
      // Release logs go to a file or a crash service, and a debug build on a
      // device logs to logcat — escape codes are noise in both, so the
      // switch has to actually work.
      const failure = ServerException(code: '500');
      final at = StackTrace.fromString('#0      C.d (package:hello/c.dart:2)');

      final plain = const ConsoleErrorReporter(colored: false)
          .formatHandled(failure, handledAt: at);
      final painted = const ConsoleErrorReporter()
          .formatHandled(failure, handledAt: at);

      expect(plain, isNot(contains('\u001b')));
      expect(painted, contains('\u001b[37m'));
      // Every painted line closes its colour run, so a truncated log cannot
      // bleed into whatever prints next.
      expect(painted, endsWith('\u001b[0m'));
    });

    test('degrades to the error alone when neither trace is available', () {
      final line = const ConsoleErrorReporter()
          .formatHandled(const ServerException(code: '500'));

      expect(line, startsWith('handled: ServerException'));
      expect(line, isNot(contains('thrown at')));
      expect(line, isNot(contains('handled at')));
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
      final result = await runGuarded(
        () async => throw const UnauthorizedException(message: 'nope'),
      );

      expect(result, isA<AsyncError<int>>());
      expect(result.error, isA<UnauthorizedException>());
    });

    test('captures a value as AsyncData', () async {
      final result = await runGuarded(() async => 7);

      expect(result, isA<AsyncData<int>>());
      expect(result.value, 7);
    });

    // Anything that is not an AppException is deliberately NOT captured: it
    // escapes to PlatformDispatcher.onError / AppProviderObserver instead of
    // becoming quiet error state.
    test('rethrows a non-AppException', () async {
      await expectLater(
        runGuarded(() async => throw StateError('bad')),
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

  group('AppProviderObserver routes one failure down exactly one lane', () {
    test('a captured AppException is breadcrumbed, not reported', () async {
      // Handled is not the same as invisible: the UI showed a sentence, and
      // the crash sink still has to know it happened. But it is a breadcrumb,
      // not a crash — `reportHandled` logs no stack trace, and a validation
      // error the user read and dismissed must not open an issue.
      final probe = _probe();

      await runGuarded(
        () async => throw const ServerException(code: '500'),
        container: probe.container,
      );

      expect(probe.reporter.handled.single.code, '500');
      expect(probe.reporter.crashes, isEmpty);
      // The second half of the breadcrumb: where the failure was absorbed.
      // Without this the log says what broke but not what is already
      // catching it, which is the half that says whether to act.
      expect(
        '${probe.reporter.handledFrom.single}',
        contains('providerDidFail'),
      );
      // Frame 0 specifically: the observer's `providerDidFail` is the code
      // that handles the failure, so that is what `handled at:` names. The
      // notifier further down the trace started it, but did not handle it.
      expect(
        '${probe.reporter.handledFrom.single}'.split('\n').first,
        contains('providerDidFail'),
      );
      // And `invoked at:` digs past Riverpod's own frames to the notifier
      // that started the action — the other question the log has to answer.
      expect(
        '${probe.reporter.invokedFrom.single}',
        contains('_ProbeNotifier.run'),
      );
    });

    // The regression this group exists for. `guardAppException` used to report
    // the breadcrumb itself, and assigning the AsyncError to `state` fires
    // `providerDidFail` as well — so every handled failure was filed twice,
    // the second time as a crash carrying a stack trace. Only the observer
    // reports now.
    test('a captured AppException is reported exactly once', () async {
      final probe = _probe();

      await runGuarded(
        () async => throw const ServerException(code: '500'),
        container: probe.container,
      );

      expect(probe.reporter.handled, hasLength(1));
      expect(probe.reporter.crashes, isEmpty);
    });

    test('an untyped error reaching the observer is a crash', () async {
      // Not routed through guardAppException: it rethrows anything that is not
      // an AppException. A provider whose build throws one is the case that
      // still has to reach `report` with its stack trace.
      //
      // The rethrow is matched loosely on purpose: Riverpod 3 rewraps a failed
      // provider's error in a `ProviderException` at the read site. What this
      // test is about is the lane the observer chose, which the read does not
      // speak for.
      final probe = _probe();
      final boom = Provider<int>((ref) => throw StateError('bad'));

      expect(() => probe.container.read(boom), throwsA(anything));
      expect(probe.reporter.crashes.single, isA<StateError>());
      expect(probe.reporter.handled, isEmpty);
    });

    test('an UnauthorizedException still signals the session expiry', () async {
      var expired = 0;
      final probe = _probe(onUnauthorized: () => expired++);

      await runGuarded(
        () async => throw const UnauthorizedException(message: 'nope'),
        container: probe.container,
      );

      expect(expired, 1);
      expect(probe.reporter.handled.single, isA<UnauthorizedException>());
      expect(probe.reporter.crashes, isEmpty);
    });

    test('a bare scope reports nothing and still captures the failure',
        () async {
      // No reporter override and no observer — what a widget test builds.
      // Capturing must not depend on either being present.
      final result = await runGuarded(
        () async => throw const ServerException(code: '500'),
      );

      expect(result, isA<AsyncError<int>>());
    });
  });
}

/// A container wired the way `bootstrap` wires the app: the same reporter
/// overridden on `errorReporterProvider` *and* handed to an
/// [AppProviderObserver].
({ProviderContainer container, _RecordingReporter reporter}) _probe({
  void Function()? onUnauthorized,
}) {
  final reporter = _RecordingReporter();
  return (
    container: ProviderContainer.test(
      overrides: [errorReporterProvider.overrideWithValue(reporter)],
      observers: [
        AppProviderObserver(reporter: reporter, onUnauthorized: onUnauthorized),
      ],
    ),
    reporter: reporter,
  );
}

/// Runs [body] through `Ref.guardAppException` inside a real [AsyncNotifier],
/// and returns the state it left behind.
///
/// Deliberately a notifier and not a bare `Provider`: what these tests are
/// about is the assignment of the captured `AsyncError` to `state`, and only a
/// notifier does that. A `Provider` merely *holding* an `AsyncError` never
/// fails, so `providerDidFail` never runs — which is how the double-report
/// above survived a test that asserted `crashes, isEmpty`.
Future<AsyncValue<int>> runGuarded(
  Future<int> Function() body, {
  ProviderContainer? container,
}) async {
  final scope = container ?? ProviderContainer.test();
  await scope.read(_probeProvider.notifier).run(body);
  return scope.read(_probeProvider);
}

final _probeProvider =
    AsyncNotifierProvider<_ProbeNotifier, int>(_ProbeNotifier.new);

class _ProbeNotifier extends AsyncNotifier<int> {
  @override
  FutureOr<int> build() => 0;

  Future<void> run(Future<int> Function() body) async {
    state = await ref.guardAppException(body);
  }
}

/// Captures both lanes so a test can tell a breadcrumb from a crash.
class _RecordingReporter extends ErrorReporter {
  final List<Object> crashes = [];
  final List<AppException> handled = [];
  final List<StackTrace?> handledFrom = [];
  final List<StackTrace?> invokedFrom = [];
  final List<StackTrace> traces = [];

  // One override, which is the point: `reportHandled` funnels in here, so
  // this records the lane the funnel actually chose rather than asserting on
  // a second method that could drift from it.
  @override
  Future<void> report(
    Object error,
    StackTrace stackTrace, {
    bool handled = false,
    StackTrace? handledAt,
    StackTrace? invokedAt,
  }) async {
    traces.add(stackTrace);
    if (!handled) {
      crashes.add(error);
      return;
    }
    this.handled.add(error as AppException);
    handledFrom.add(handledAt);
    invokedFrom.add(invokedAt);
  }
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
