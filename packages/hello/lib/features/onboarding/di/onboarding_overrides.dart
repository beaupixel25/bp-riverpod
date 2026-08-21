// Environment-specific bindings for the onboarding feature — the Riverpod
// equivalent of `@LazySingleton(env: [...])`.
//
// Only deviations from the defaults in onboarding_providers.dart are listed
// here. Because the switch is exhaustive over `Environment`, adding a new
// environment is a compile error in this file rather than a runtime "no
// registration found".
//
// Overrides are applied at the root ProviderScope (see lib/di/overrides.dart)
// rather than switched inside the provider, so a release build tree-shakes away
// the mock implementation it never names.

import 'package:core/core.dart';
import 'package:hello/features/onboarding/data/repositories/mock/onboarding_repository.dart';
import 'package:hello/features/onboarding/di/onboarding_providers.dart';
// `Override` is exported by riverpod_annotation, not flutter_riverpod.
import 'package:riverpod_annotation/riverpod_annotation.dart';

/// Overrides applied to the root scope for [environment].
List<Override> onboardingOverrides(Environment environment) =>
    switch (environment) {
      Environment.test => [
          onboardingRepositoryProvider
              .overrideWith((ref) => MockOnboardingRepository()),
        ],
      Environment.local ||
      Environment.development ||
      Environment.staging ||
      Environment.production =>
        const <Override>[],
    };
