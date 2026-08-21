import 'package:core/core.dart';
import 'package:hello/app/view/app.dart';
import 'package:hello/di/overrides.dart';

Future<void> main() async {
  await bootstrap(
    () => const HelloApp(),
    environment: Environment.test,
    overridesBuilder: buildOverrides,
  );
}
