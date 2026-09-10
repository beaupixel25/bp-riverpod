import 'dart:async';

import 'package:core/core.dart';
import 'package:hello/features/onboarding/di/onboarding_providers.dart';
import 'package:hello/features/onboarding/domain/dtos/auth_token.dart';
import 'package:hello/features/onboarding/domain/dtos/email_signup.dart';
import 'package:hello/features/onboarding/domain/use_cases/signup_uc.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'signup_controller.g.dart';

/// {@template signup_controller}
/// State holder for the sign-up page. See `LoginController` for the shape —
/// `AsyncValue<AuthToken?>`, dependencies resolved in [build], no `ref` in
/// methods.
/// {@endtemplate}
@riverpod
class SignupController extends _$SignupController {
  // `late`, never `late final` — see LoginController.
  late SignupUseCase _signupUseCase;

  /// {@macro signup_controller}
  @override
  FutureOr<AuthToken?> build() {
    _signupUseCase = ref.watch(signupUseCaseProvider);
    return null;
  }

  /// Runs [SignupUseCase] and publishes the outcome as state.
  Future<void> submit({
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    state = await ref.guardAppException(
      () => _signupUseCase.execute(
        input: EmailSignup(email: email, password: password),
      ),
    );
  }
}
