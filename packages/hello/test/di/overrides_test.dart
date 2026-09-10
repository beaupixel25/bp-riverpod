import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hello/di/overrides.dart';
import 'package:hello/features/onboarding/di/onboarding_providers.dart';
import 'package:hello/features/onboarding/domain/use_cases/login_uc.dart';
import 'package:hello/features/onboarding/domain/use_cases/signup_uc.dart';

void main() {
  // Every placeholder provider must be overridden by buildOverrides for every
  // environment, and every binding must actually construct. Add a feature's
  // providers here when you add it to buildOverrides — a forgotten override is
  // otherwise silent, and the feature just uses the real repository.
  for (final environment in Environment.values) {
    test('the DI graph resolves for $environment', () async {
      final container = ProviderContainer.test(
        overrides: await buildOverrides(environment),
      );

      expect(
        container.read(buildConfigurationProvider),
        isA<BuildConfiguration>(),
      );
      expect(container.read(loginUseCaseProvider), isA<LoginUseCase>());
      expect(container.read(signupUseCaseProvider), isA<SignupUseCase>());

      // Not overridden by buildOverrides — `bootstrap` binds it at the root
      // scope instead. What matters here is that the default resolves rather
      // than throwing: a widget test builds a bare scope, and a throwing
      // lookup inside `ref.guardAppException` would turn a handled failure
      // into a crash.
      expect(container.read(errorReporterProvider), isA<NoopErrorReporter>());
    });
  }
}
