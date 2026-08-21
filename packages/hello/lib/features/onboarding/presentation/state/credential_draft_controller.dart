import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'credential_draft_controller.g.dart';

/// What the user has typed into the onboarding forms so far, plus any error
/// surfaced by the last submit attempt.
class CredentialDraft {
  /// Creates a draft. Both fields default to empty — a fresh install.
  const CredentialDraft({
    this.email = '',
    this.password = '',
    this.errorMessage,
  });

  /// The email as typed, untrimmed. Trimming happens at submit.
  final String email;

  /// The password as typed.
  final String password;

  /// The message from the last failed submit, or null between attempts.
  final String? errorMessage;

  /// Returns a copy with [email] or [password] replaced. Any existing
  /// [errorMessage] is preserved — use [CredentialDraftController.setError]
  /// or [CredentialDraftController.clearError] to change it.
  CredentialDraft copyWith({String? email, String? password}) =>
      CredentialDraft(
        email: email ?? this.email,
        password: password ?? this.password,
        errorMessage: errorMessage,
      );
}

/// {@template credential_draft_controller}
/// The email, password and error shared by the log-in and sign-up forms.
///
/// `keepAlive`, and shared between both pages, for two reasons that are
/// really the same reason:
///
/// * **Back must not throw away what was typed.** Going back to landing and
///   returning to a form has to find the fields as they were. The pages are
///   routes, so they are disposed on pop; the draft outliving them is what
///   makes that work.
/// * **Switching form must not either.** Someone who types their email on
///   log in and then realises they need an account should not retype it on
///   sign up.
///
/// The error lives here too, rather than in each page's own controller,
/// because a route pop does not reliably dispose that controller before the
/// next visit builds — a stale error would otherwise greet the user as a
/// fresh failure. [clearError] is how a page disowns it instead.
///
/// Nothing persists this. It is in memory for the life of the process, which
/// is the whole point: a password must not outlive the session that typed
/// it.
/// {@endtemplate}
@Riverpod(keepAlive: true)
class CredentialDraftController extends _$CredentialDraftController {
  /// {@macro credential_draft_controller}
  @override
  CredentialDraft build() => const CredentialDraft();

  /// Records the email as typed.
  void setEmail(String email) => state = state.copyWith(email: email);

  /// Records the password as typed.
  void setPassword(String password) =>
      state = state.copyWith(password: password);

  /// Records the message from a failed submit.
  void setError(String message) => state = CredentialDraft(
        email: state.email,
        password: state.password,
        errorMessage: message,
      );

  /// Drops the error without touching the draft. Call when a page that
  /// showed it is leaving, so the next visit starts clean.
  void clearError() => state = CredentialDraft(
        email: state.email,
        password: state.password,
      );

  /// Drops the email, password, and any error — the whole draft, not just
  /// the error [clearError] disowns.
  ///
  /// Call this from a successful submit, never from a route pop: the reason
  /// this controller is `keepAlive` is so back-navigation finds the draft as
  /// it was, but success routes forward, past the flow entirely, so nothing
  /// is lost by clearing here. A password must not outlive the session that
  /// typed it.
  void clearCredentials() => state = const CredentialDraft();
}
