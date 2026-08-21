import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hello/features/onboarding/di/onboarding_providers.dart';
import 'package:hello/features/onboarding/domain/dtos/auth_token.dart';
import 'package:hello/features/onboarding/domain/dtos/credentials.dart';
import 'package:hello/features/onboarding/domain/entities/user.dart';
import 'package:hello/features/onboarding/domain/repositories/onboarding_repository.dart';
import 'package:hello/features/onboarding/presentation/view/pages/login/login_controller.dart';
import 'package:mocktail/mocktail.dart';

class _MockOnboardingRepository extends Mock
    implements IOnboardingRepository {}

void main() {
  group('LoginController', () {
    late _MockOnboardingRepository repository;

    // mocktail's `any()` needs a registered fallback for non-built-in
    // parameter types — Credentials is one, so `login(any())` below would
    // throw at runtime without this.
    setUpAll(() {
      registerFallbackValue(const Credentials(email: '', password: ''));
    });

    setUp(() => repository = _MockOnboardingRepository());

    // Only the repository is overridden. LoginUseCase is still built by
    // loginUseCaseProvider exactly as it is in the running app, so this covers
    // the wiring, not just the controller.
    ProviderContainer container() => ProviderContainer.test(
          overrides: [
            onboardingRepositoryProvider.overrideWithValue(repository),
          ],
        );

    test('publishes the token returned by the repository', () async {
      final token = AuthToken(
        user: User(id: '1', firstName: 'Ada', lastName: 'Lovelace'),
        expiresAt: 0,
      );
      when(() => repository.login(any())).thenAnswer((_) async => token);

      final c = container()..listen(loginControllerProvider, (_, _) {});
      await c
          .read(loginControllerProvider.notifier)
          .submit(email: 'a@b.com', password: 'secret');

      expect(c.read(loginControllerProvider).value, token);
    });

    // Proves the full flow: the repository throws a typed AppException (data),
    // UseCase.execute rethrows it unchanged (domain), and guardAppException
    // turns it into AsyncError (presentation).
    test('surfaces a typed AppException as AsyncError', () async {
      when(() => repository.login(any())).thenThrow(
        const UnauthorizedException(
          message: 'Check the email and password, then try again.',
        ),
      );

      final c = container()..listen(loginControllerProvider, (_, _) {});
      await c
          .read(loginControllerProvider.notifier)
          .submit(email: 'a@b.com', password: 'secret');

      expect(
        c.read(loginControllerProvider),
        isA<AsyncError<AuthToken?>>()
            .having((s) => s.error, 'error', isA<UnauthorizedException>()),
      );
    });
  });
}
