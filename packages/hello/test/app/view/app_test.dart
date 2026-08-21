import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hello/app/view/app.dart';
import 'package:hello/di/overrides.dart';

void main() {
  group('HelloApp', () {
    testWidgets('boots and resolves the initial route', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: await buildOverrides(Environment.test),
          child: const HelloApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // Every page in the app renders a Scaffold, so this reaches inside the
      // router's Navigator without naming the page that landed there.
      final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
      expect(
        router.routerDelegate.currentConfiguration.uri.toString(),
        '/landing',
      );
    });

    // Regression: an earlier task left `/` unrouted while `initialLocation`
    // pointed elsewhere, so a cold start never noticed. A web reload at the
    // root, a deep link, or a restored saved state pointed at `/` would have
    // hit go_router's own "page not found" screen instead of the app. This
    // has already settled once above, so the `go('/')` below is a genuine
    // second visit, not a reading of the initial location.
    testWidgets('/ resolves instead of hitting page-not-found', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: await buildOverrides(Environment.test),
          child: const HelloApp(),
        ),
      );
      await tester.pumpAndSettle();

      final router = GoRouter.of(tester.element(find.byType(Scaffold).first))
        ..go('/');
      await tester.pumpAndSettle();

      expect(
        router.routerDelegate.currentConfiguration.uri.toString(),
        '/landing',
      );
    });
  });
}
