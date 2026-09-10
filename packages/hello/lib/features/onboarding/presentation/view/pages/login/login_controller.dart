import 'dart:async';

import 'package:core/core.dart';
import 'package:hello/features/onboarding/di/onboarding_providers.dart';
import 'package:hello/features/onboarding/domain/dtos/auth_token.dart';
import 'package:hello/features/onboarding/domain/dtos/credentials.dart';
import 'package:hello/features/onboarding/domain/use_cases/login_uc.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'login_controller.g.dart';

/// {@template login_controller}
/// State holder for the login page.
///
/// State is `AsyncValue<AuthToken?>`: `data(null)` is idle, `loading` while the
/// request is in flight, `data(token)` on success, and `error` carrying a typed
/// [AppException] on failure. There is no separate status enum — `AsyncValue`
/// already encodes all four, and keeps the previous value across a failure.
///
/// Dependencies are resolved once, in [build], onto fields — a method must not
/// reach for `ref.watch` to fetch one. See the ref rule in
/// `.claude/skills/implement-feature/SKILL.md`.
/// {@endtemplate}
@riverpod
class LoginController extends _$LoginController {
  // Deliberately `late` and NOT `late final`. The notifier INSTANCE outlives a
  // rebuild while `build()` runs again, so a `late final` field would throw
  // LateInitializationError on the second run. Constructor injection is not an
  // option either: `ref` and `state` are unusable in a Notifier constructor.
  late LoginUseCase _loginUseCase;

  /// {@macro login_controller}
  @override
  FutureOr<AuthToken?> build() {
    _loginUseCase = ref.watch(loginUseCaseProvider);
    return null;
  }

  /// Runs [LoginUseCase] and publishes the outcome as state.
  Future<void> submit({
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    state = await ref.guardAppException(
      () => _loginUseCase.execute(
        input: Credentials(email: email, password: password),
      ),
    );
  }
}
