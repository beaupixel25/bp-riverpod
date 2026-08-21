// Composition root for the onboarding feature.
//
// This is the ONLY file in the feature allowed to touch `Ref`. Every provider
// is typed as its *domain* contract, so presentation code depends on
// IOnboardingRepository and never on OnboardingRepository — the
// provider function is where dependency inversion actually happens.
//
// Repositories and use cases stay plain Dart with constructor parameters, so a
// test can build them directly with no Riverpod involved.
//
// These are the DEFAULT bindings. Per-environment deviations live in
// onboarding_overrides.dart and are applied at the root ProviderScope.

import 'package:core/core.dart';
import 'package:hello/features/onboarding/data/repositories/onboarding_repository.dart';
import 'package:hello/features/onboarding/domain/repositories/onboarding_repository.dart';
import 'package:hello/features/onboarding/domain/use_cases/login_uc.dart';
import 'package:hello/features/onboarding/domain/use_cases/signup_uc.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'onboarding_providers.g.dart';

/// The onboarding repository, exposed as its domain contract.
///
/// `keepAlive: true` is the counterpart of `@LazySingleton`: one instance for
/// the life of the container. Drop it for factory-ish semantics (cached while
/// listened, disposed when the last listener goes).
///
/// This is also where the network enters the feature: `apiClientProvider`
/// (in `core`, beside `buildConfigurationProvider`) already carries the
/// running flavor's endpoint, and it is passed down as a plain constructor
/// argument so the repository itself never sees a `Ref`.
@Riverpod(keepAlive: true)
IOnboardingRepository onboardingRepository(Ref ref) =>
    OnboardingRepository(ref.watch(apiClientProvider));

/// Resolves [LoginUseCase] with its repository already bound.
@Riverpod(keepAlive: true)
LoginUseCase loginUseCase(Ref ref) =>
    LoginUseCase(ref.watch(onboardingRepositoryProvider));

/// Resolves [SignupUseCase] with its repository already bound.
@Riverpod(keepAlive: true)
SignupUseCase signupUseCase(Ref ref) =>
    SignupUseCase(ref.watch(onboardingRepositoryProvider));
