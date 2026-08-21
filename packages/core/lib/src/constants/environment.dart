/// Environments the app can run in.
///
/// One enum for both flavors and dependency selection. Feature override files
/// switch over it exhaustively, so adding a value here surfaces as a compile
/// error everywhere it must be handled.
enum Environment {
  /// Local development against local services.
  local,

  /// Development flavor.
  development,

  /// Staging flavor.
  staging,

  /// Production flavor.
  production,

  /// Test environment: mock repositories, used by main_test.dart.
  test,
}
