import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hello/common/error/app_error_messages.dart';
import 'package:hello/features/onboarding/domain/dtos/auth_token.dart';
import 'package:hello/features/onboarding/domain/validation/credential_validator.dart';
import 'package:hello/features/onboarding/presentation/routing/onboarding_routes.dart';
import 'package:hello/features/onboarding/presentation/state/credential_draft_controller.dart';
import 'package:hello/features/onboarding/presentation/view/pages/login/login_controller.dart';
import 'package:hello/features/onboarding/presentation/view/widgets/onboarding_scaffold.dart';
import 'package:hello/l10n/l10n.dart';
import 'package:hello/routing/routes.dart';

/// {@template login_page}
/// Email and password, built from `core`'s form components: a
/// [LabeledTextField], a [PasswordField], and a "Log in" [PillButton]
/// pinned under them, with a [PromptLink] to sign up instead.
///
/// Two pieces of state, with deliberately different lifetimes: the
/// *outcome* of submitting is [LoginController]'s and is transient, while
/// what the user *typed* — plus the last error shown — lives in
/// [CredentialDraftController] and survives this page's disposal, so going
/// back and returning costs nothing, and neither does switching to sign up.
/// {@endtemplate}
class LoginPage extends ConsumerStatefulWidget {
  /// {@macro login_page}
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  // Seeded from the draft on the first build, not in `initState`: `ref` is
  // only safe to read from build, and the seed comes from a provider.
  TextEditingController? _emailController;
  TextEditingController? _passwordController;

  @override
  void dispose() {
    _emailController?.dispose();
    _passwordController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final draft = ref.watch(credentialDraftControllerProvider);
    final draftController =
        ref.watch(credentialDraftControllerProvider.notifier);
    final controller = ref.watch(loginControllerProvider.notifier);
    final isBusy = ref.watch(loginControllerProvider).isLoading;

    // Registered after `draftController` is resolved so the callback can
    // close over it without a `ref` read of its own.
    ref.listen<AsyncValue<AuthToken?>>(loginControllerProvider, (_, next) {
      switch (next) {
        case AsyncError(:final error):
          draftController.setError(
            asAppException(error)
                .toUserMessage(AppErrorMessages(context.l10n)),
          );
        case AsyncData(:final value) when value != null:
          // A password must not outlive the session that typed it — see
          // CredentialDraftController.clearCredentials.
          draftController.clearCredentials();
          // Sign-up and login both authenticate, so both land on /main.
          const HomeRoute().go(context);
        case _:
          break;
      }
    });

    _emailController ??= TextEditingController(text: draft.email);
    _passwordController ??= TextEditingController(text: draft.password);

    final emailError = CredentialValidator.email(draft.email);
    final passwordError = CredentialValidator.password(draft.password);
    final canSubmit = emailError == null && passwordError == null;

    // The single choke point for submitting: also reached from the
    // password field's keyboard action, so the busy guard has to live here
    // rather than at each call site — `PasswordField` has no `enabled`
    // parameter to lock it during a submit the way the email field does.
    void onSubmit() {
      if (isBusy) return;
      final formError = emailError ?? passwordError;
      if (formError != null) {
        draftController.setError(formError);
        return;
      }
      unawaited(
        controller.submit(email: draft.email.trim(), password: draft.password),
      );
    }

    // The error clears on the next keystroke in either field — the fix is
    // often the other one — and on the way out, because the draft (and its
    // error) is shared with sign up: leaving without clearing it would greet
    // that form with a stale login failure.
    void onEmailChanged(String value) {
      draftController
        ..clearError()
        ..setEmail(value);
    }

    void onPasswordChanged(String value) {
      draftController
        ..clearError()
        ..setPassword(value);
    }

    void goToSignup() {
      draftController.clearError();
      unawaited(const SignupRoute().push<void>(context));
    }

    // The reset flow is a seam, like `_restoreSession` and the real
    // repository: the affordance is here because a login screen without one
    // is a redesign, but nothing is behind it yet. Point it at a route when
    // you build one; until then it says so in the form's own voice rather
    // than failing silently.
    void onForgotPassword() =>
        draftController.setError('Password reset is not available yet.');

    return OnboardingScaffold(
      title: 'Welcome back.',
      subtitle: 'Pick up wherever you left off. Everything you had open is '
          'still there.',
      onBack: () {
        draftController.clearError();
        Navigator.of(context).pop();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LabeledTextField(
            controller: _emailController,
            labelText: 'Email',
            hintText: 'name@example.com',
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            enabled: !isBusy,
            onChanged: onEmailChanged,
          ),
          const SizedBox(height: 16),
          PasswordField(
            controller: _passwordController!,
            labelText: 'Password',
            showPasswordLabel: l10n.onboardingShowPassword,
            hidePasswordLabel: l10n.onboardingHidePassword,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onChanged: onPasswordChanged,
            onSubmitted: (_) => onSubmit(),
          ),
          const SizedBox(height: 12),
          PromptLink(
            prompt: 'Forgot your password?',
            action: 'Reset it',
            onPressed: onForgotPassword,
          ),
          if (draft.errorMessage != null) ...[
            const SizedBox(height: 16),
            FormMessage(message: draft.errorMessage!),
          ],
          const SizedBox(height: 24),
          PillButton(
            label: 'Log in',
            isBusy: isBusy,
            // Dimmed, not disabled: tapping it still validates, so a person
            // is told what is missing rather than tapping a dead control.
            isDimmed: !canSubmit,
            onPressed: onSubmit,
          ),
          const SizedBox(height: 12),
          PromptLink(
            prompt: "Don't have an account?",
            action: 'Sign up',
            onPressed: goToSignup,
          ),
        ],
      ),
    );
  }
}
