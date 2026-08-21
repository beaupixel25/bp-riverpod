import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hello/common/error/app_error_messages.dart';
import 'package:hello/features/onboarding/domain/dtos/auth_token.dart';
import 'package:hello/features/onboarding/domain/validation/credential_validator.dart';
import 'package:hello/features/onboarding/presentation/routing/onboarding_routes.dart';
import 'package:hello/features/onboarding/presentation/state/credential_draft_controller.dart';
import 'package:hello/features/onboarding/presentation/view/pages/signup/signup_controller.dart';
import 'package:hello/features/onboarding/presentation/view/widgets/onboarding_scaffold.dart';
import 'package:hello/l10n/l10n.dart';
import 'package:hello/routing/routes.dart';

/// {@template signup_page}
/// Email and password, built from `core`'s form components: a
/// [LabeledTextField], a [PasswordField] with its strength meter switched
/// on, and a "Create account" [PillButton] pinned under them, with a
/// [PromptLink] to log in instead.
///
/// See `LoginPage` for why the typed values and the last error live in
/// [CredentialDraftController] rather than in [SignupController]'s own
/// state.
/// {@endtemplate}
class SignupPage extends ConsumerStatefulWidget {
  /// {@macro signup_page}
  const SignupPage({super.key});

  @override
  ConsumerState<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends ConsumerState<SignupPage> {
  // Seeded from the draft on the first build — see LoginPage.
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final draft = ref.watch(credentialDraftControllerProvider);
    final draftController =
        ref.watch(credentialDraftControllerProvider.notifier);
    final controller = ref.watch(signupControllerProvider.notifier);
    final isBusy = ref.watch(signupControllerProvider).isLoading;

    ref.listen<AsyncValue<AuthToken?>>(signupControllerProvider, (_, next) {
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
          // Sign-up authenticates too, so it lands on /main directly.
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

    // The single choke point for submitting — see LoginPage for why the
    // busy guard lives here rather than at each call site.
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

    // See LoginPage for why the error clears on every keystroke and on the
    // way out: the draft is shared, so an uncleared error would otherwise
    // greet whichever form the user opens next.
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

    void goToLogin() {
      draftController.clearError();
      unawaited(const LoginRoute().push<void>(context));
    }

    return OnboardingScaffold(
      title: "Let's get started.",
      subtitle: "Two fields and you're in. You can fill in the rest later — "
          'or not at all.',
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
            labelText: 'Create a password',
            hintText: 'At least 8 characters',
            showPasswordLabel: l10n.onboardingShowPassword,
            hidePasswordLabel: l10n.onboardingHidePassword,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.newPassword],
            // Scoring a password someone already has is pointless advice —
            // only sign-up shows the meter.
            showStrength: true,
            onChanged: onPasswordChanged,
            onSubmitted: (_) => onSubmit(),
          ),
          if (draft.errorMessage != null) ...[
            const SizedBox(height: 16),
            FormMessage(message: draft.errorMessage!),
          ],
          const SizedBox(height: 24),
          // Plain text, not links: a scaffold has no Terms page to point at,
          // and a tappable link that goes nowhere is worse than a sentence.
          // Make these tappable when the documents exist.
          Text(
            'By creating an account you agree to our Terms and Privacy '
            'Policy.',
            textAlign: TextAlign.center,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          PillButton(
            label: 'Create account',
            isBusy: isBusy,
            // Dimmed, not disabled — see LoginPage.
            isDimmed: !canSubmit,
            onPressed: onSubmit,
          ),
          const SizedBox(height: 12),
          PromptLink(
            prompt: 'Already have an account?',
            action: 'Log in',
            onPressed: goToLogin,
          ),
        ],
      ),
    );
  }
}
