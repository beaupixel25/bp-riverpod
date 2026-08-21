import 'package:core/src/build_configuration.dart';
import 'package:core/src/data/services/api_client.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'build_configuration_provider.g.dart';

/// The running flavor's build configuration.
///
/// Overridden at the root `ProviderScope` by the app's `buildOverrides`.
@Riverpod(keepAlive: true)
BuildConfiguration buildConfiguration(Ref ref) => throw UnimplementedError(
      'buildConfigurationProvider must be overridden in buildOverrides()',
    );

/// The app's HTTP client, pointed at the running flavor's endpoint.
///
/// `keepAlive`, because the client owns a connection pool: rebuilding it per
/// listener would drop warm connections.
///
/// Pass `onUnauthorized:` here to route an expired session to sign-in from one
/// place instead of from every caller.
@Riverpod(keepAlive: true)
ApiClient apiClient(Ref ref) => ApiClient(
      baseUrl: ref.watch(buildConfigurationProvider).baseEndpointUrl,
    );
