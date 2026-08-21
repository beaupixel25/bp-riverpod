// `Override` is exported by riverpod_annotation, not flutter_riverpod.
import 'package:core/core.dart';
import 'package:hello/features/onboarding/di/onboarding_overrides.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';


/// Builds the root `ProviderScope` overrides for [environment].
///
/// Async from the start: this is where a dependency that must be resolved
/// before the first frame (the injectable `@preResolve` equivalent) is awaited
/// and supplied with `overrideWithValue`.
///
/// Each feature adds one `...<feature>Overrides(environment)` line here.
Future<List<Override>> buildOverrides(Environment environment) async {
  return [
    buildConfigurationProvider.overrideWithValue(
      switch (environment) {
        Environment.production => const BuildConfiguration(
            appTitle: 'hello',
            baseEndpointUrl: 'https://api.example.com',
          ),
        Environment.staging => const BuildConfiguration(
            appTitle: 'hello Staging',
            baseEndpointUrl: 'https://staging-api.example.com',
          ),
        Environment.local ||
        Environment.development ||
        Environment.test =>
          const BuildConfiguration(
            appTitle: 'hello Dev',
            baseEndpointUrl: 'https://dev-api.example.com',
          ),
      },
    ),
    ...onboardingOverrides(environment),
  ];
}
