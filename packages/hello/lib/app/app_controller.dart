import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_controller.freezed.dart';
part 'app_controller.g.dart';

/// {@template app_state}
/// Global app state: the outcome of the startup load, plus the app-wide UI
/// preferences the app root feeds into core's `App`.
/// {@endtemplate}
@freezed
sealed class AppState with _$AppState {
  /// {@macro app_state}
  const factory AppState({
    /// Lifecycle of the startup load. A field rather than the notifier's whole
    /// state, so [themeMode] and [locale] stay readable while it is loading or
    /// has failed.
    @Default(AsyncValue<void>.data(null)) AsyncValue<void> startup,

    /// The active theme mode. Follows the device until a settings screen
    /// overrides it.
    @Default(ThemeMode.system) ThemeMode themeMode,

    /// The active locale override, or `null` to follow the device.
    Locale? locale,

    /// Whether a previous session can be restored. Set once by `start()`;
    /// the cold-start launch reads it to choose where to land.
    @Default(false) bool isSignedIn,
  }) = _AppState;

  const AppState._();
}

/// {@template app_controller}
/// Global state holder owning app-wide state.
///
/// `keepAlive: true` is what makes it app-wide: the notifier is never disposed
/// between routes. Page-level state belongs in that page's own controller —
/// put something here only when more than one screen reads it.
/// {@endtemplate}
@Riverpod(keepAlive: true)
class AppController extends _$AppController {
  /// {@macro app_controller}
  @override
  AppState build() => const AppState();

  /// Runs the app-wide startup load. Called once by the app root.
  Future<void> start() async {
    state = state.copyWith(startup: const AsyncValue<void>.loading());

    // App-wide startup work goes here: resolve the use cases this app needs
    // before its first frame (feature flags, session restore, remote config)
    // with `ref.read`, await them, and widen [AppState] with what they return.
    // Only an AppException becomes error state; anything else escapes to the
    // AppProviderObserver.
    var isSignedIn = false;
    // Restoring the session runs inside the guard — not beside it — so a
    // throwing token-store check becomes this AsyncError instead of escaping
    // to PlatformDispatcher.onError. Leaving isSignedIn false on failure is
    // correct: an unreadable session lands on /landing, not /main.
    final startup = await guardAppException(() async {
      isSignedIn = await _restoreSession();
    });
    state = state.copyWith(startup: startup, isSignedIn: isSignedIn);
  }

  /// Whether a previous session can be restored.
  ///
  /// Always false today: the generated account store is in memory and does not
  /// survive a restart, so there is nothing to read. Replace this with your
  /// token store's check — the launch already branches on the result, and
  /// `test/app/view/launch_page_test.dart` covers both destinations.
  Future<bool> _restoreSession() async => false;

  /// Switches the app theme (called from a settings screen).
  void setThemeMode(ThemeMode mode) => state = state.copyWith(themeMode: mode);

  /// Switches the app locale (called from a settings screen).
  void setLocale(Locale locale) => state = state.copyWith(locale: locale);

  /// Reverts the locale override so the app follows the device's own
  /// locale (the settings page's "follow the device" option).
  ///
  /// [setLocale]'s parameter is deliberately non-nullable, so it cannot
  /// express "no override" — this method exists to cover that case.
  void useDeviceLocale() => state = state.copyWith(locale: null);
}
