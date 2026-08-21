---
name: implement-feature
description: End-to-end implementation of a Clean-Architecture feature in this Flutter monorepo (Riverpod variant) — interviews for the feature's description, entities/DTOs, use cases, repository API, screens/pages, and new components, writes the baseline slice across all 3 layers (presentation/domain/data) and fills it in, declares providers in the feature's di/ folder, wires per-environment bindings into the app composition root, builds the UI from design mockups on top of the core design-system, wires go_router for every page, and runs the build. Use when someone wants to fully build out a feature (like features/authentication), not just scaffold a baseline slice. Not for creating a whole app or monorepo, or a single standalone component.
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - AskUserQuestion
---

# Implement a Clean-Architecture feature end-to-end (Riverpod)

This skill takes a feature from **idea to running screens**. It interviews you
for the feature's real shape, writes the baseline slice across all three
layers and fills it in, generates any **additional pages** and **new shared
components**, builds the presentation layer from your **design mockups** on top
of the `core` design-system, wires every page into `go_router`, and runs the
build.

Everything here is authored by you, in this workspace — no external tool is
invoked and nothing has to be on your `PATH`. The pattern to copy is already
checked in: **`features/onboarding/`** is the same three-layer slice, with the
same `di/` folder, in this app and in this state-management style. Read it
before you write.

> Not what you want?
> - A single reusable shared widget → **create-component**.
> - A whole new app package or monorepo → this monorepo's `README.md`.

This skill assumes an **existing monorepo of this shape with at least one app
package**. **All paths below are relative to the monorepo root.**

## The one rule that governs this architecture

> **`ref` may appear in exactly two places: inside a `@riverpod` provider
> function body, and inside a `Notifier.build()`. Nowhere else — not in a
> repository, not in a use case, not in a Notifier method, not in a widget
> callback.**

The vocabulary, because it is easy to get subtly wrong:

| Shape | Name | Verdict |
|---|---|---|
| `class Repo { Repo(this.ref); final Ref ref; ... ref.read(apiProvider) ... }` | Service Locator | **banned** — hides dependencies, untestable without a container |
| `Provider((ref) => Repo(api: ref.watch(apiProvider)))` | Dependency Injection | **the rule** |
| ...where the provider's *type* is the domain interface | Dependency Inversion | **the goal** |

Everything below the presentation layer is plain Dart with constructor
parameters, constructible in a test with zero Riverpod involved.

**Note this is deliberately one step stricter than Riverpod's own docs**, which
suggest `ref.read(p.notifier)` inside widget callbacks. Here, pages resolve the
notifier at *build* time and pass tear-offs:

```dart
@override
Widget build(BuildContext context, WidgetRef ref) {
  // Resolved at build time; callbacks close over it. The notifier instance is
  // stable across state changes, so watching it costs no extra rebuilds.
  final controller = ref.watch(ordersControllerProvider.notifier);
  final state = ref.watch(ordersControllerProvider);

  void load() => unawaited(controller.load(id));

  return ElevatedButton(onPressed: load, child: const Text('Load'));
}
```

No lint enforces this. `grep -rn "ref\.read(" packages/*/lib` returning zero
hits is the check — keep it that way.

## Interactive flow

Work through these prompts in order before generating anything. Use
`AskUserQuestion` where a preference is unknown; otherwise infer and confirm.

1. **Feature description.** Its primary user goal, the core flow, and key states
   (empty / error / success).
2. **Target app.** If unambiguous, use it. Otherwise list the monorepo's apps
   (`packages/*` excluding `core`) and ask.
3. **Design references (adaptive).** Figma link (use Figma MCP tools if
   available), images (`Read` them), or a text description. Extract: layout,
   per-screen states, and which elements map to **existing** core components vs
   **new** ones.
4. **Screens / pages.** Name, purpose, entity/state shown, how it's navigated
   to. The baseline slice is exactly one page.
5. **New components.** Reusable widgets not already in `core`. Check
   `MEMORY.md`'s **Component Index** first: eleven ship with the scaffold, and
   a form is usually `LabeledTextField` + `PasswordField` + `PillButton`
   already. Each genuinely new one is created via **create-component**.
6. **Model style: `extends` vs `freezed`.** `extends` is plain Dart with the
   model extending the entity; `freezed` gives generated `==`/`copyWith`/pattern
   matching via an `<Entity>IF` interface and `toEntity()`. Nothing records the
   answer for you — it decides how you spell every model file in Generate.
7. **Entity name + fields**, as `name: type, nullable?, default?`.
8. **DTO(s) and their fields** — at minimum the `<Entity>Draft`.
9. **Which models need JSON, and casing** (baseline `FieldRename.snake`).
10. **Repository API** beyond the generated `fetch<Entity>` / `create<Entity>`.
11. **Use cases.** One per repository method the controller needs.
12. **Controller state per page.** The baseline is `AsyncValue<Entity?>`. Confirm
    whether a page needs a richer state object (a freezed class holding a list
    plus filters, say) rather than a bare entity.

## Generate

1. **Baseline slice.** Write these files yourself. **Read
   `packages/<app>/lib/features/onboarding/` first** — it is this same
   three-layer slice, already in this app and already in this
   state-management style, so copy its file shapes, imports and naming rather
   than inventing them. Under `packages/<app>/lib/features/<feature>/`:
   - `domain/entities/<entity>.dart`, `domain/dtos/<entity>_draft.dart`
   - `domain/repositories/<feature>_repository.dart` (`I<Feature>Repository`)
   - `domain/use_cases/fetch_<entity>_uc.dart`, `create_<entity>_uc.dart`
   - `data/repositories/<feature>_repository.dart` (impl, throws `UnimplementedError`)
   - `data/repositories/mock/<feature>_repository.dart`
   - `data/models/<entity>_model.dart`, `data/models/<entity>_draft_model.dart`
   - **`di/<feature>_providers.dart`** — the feature's composition root
   - **`di/<feature>_overrides.dart`** — its per-environment bindings
   - `presentation/view/pages/<feature>/<feature>_controller.dart`, `<feature>_page.dart`
   - freezed only: `common/data/utils/date_time_converter.dart` — one per app,
     so create it only if it isn't there already

   Then add whatever the app's `pubspec.yaml` is still missing:
   `json_annotation` under `dependencies`; `build_runner` and
   `json_serializable` under `dev_dependencies`; for freezed style also
   `freezed_annotation` (dependency) and `freezed` (dev dependency).

2. **Fill in the slice** to match what the user described — real fields on
   the entity, DTO(s) and models; extra repository methods on the interface and
   both implementations; matching use cases.

   **Do not hand-write `.g.dart`, `.freezed.dart`, or `routes.g.dart`** — these
   are build_runner outputs.

3. **Declare a provider for every new class.** This is the step with no
   injectable equivalent: `riverpod_generator` does not scan for annotated
   classes, so each new repository or use case needs ~3 lines in
   `di/<feature>_providers.dart`, typed as its *domain* contract:

   ```dart
   @Riverpod(keepAlive: true)
   UpdateOrderUseCase updateOrderUseCase(Ref ref) =>
       UpdateOrderUseCase(ref.watch(ordersRepositoryProvider));
   ```

   `@Riverpod(keepAlive: true)` is the `@LazySingleton` equivalent. Bare
   `@riverpod` is autoDispose — it caches while listened and disposes when the
   last listener goes, which is **not** the same as an `@injectable` factory.

4. **Wire per-environment bindings.** In `lib/di/overrides.dart`, import the
   feature's overrides and spread them:

   ```dart
   import 'package:<pkg>/features/<feature>/di/<feature>_overrides.dart';
   // ...inside the returned list:
   ...<feature>Overrides(environment),
   ```

   **Skipping this is silent** — the feature simply uses the real repository in
   every environment, including the `test` flavor. Add the feature's providers
   to `test/di/overrides_test.dart` so a missing override fails the build
   instead.

5. **Additional pages.** For each extra screen, hand-author under
   `presentation/view/pages/<page>/`:
   - `<page>_controller.dart` — an `@riverpod` Notifier (mirror the one from step 1).
   - `<page>_page.dart` — a `ConsumerWidget` / `ConsumerStatefulWidget`.

6. **New components** via the **create-component** skill. Prefer existing core
   components before creating new ones.

7. **Build the presentation UI** from the design references, using the ambient
   theme (`Theme.of(context)`).

## Writing a controller

```dart
@riverpod
class OrdersController extends _$OrdersController {
  // `late`, NEVER `late final`. The notifier INSTANCE outlives a rebuild while
  // build() re-runs, so a second assignment to a `late final` throws
  // LateInitializationError. Constructor injection is impossible: `ref` and
  // `state` are unusable in a Notifier constructor.
  late FetchOrderUseCase _fetchOrder;

  @override
  FutureOr<Order?> build() {
    _fetchOrder = ref.watch(fetchOrderUseCaseProvider);
    return null;
  }

  Future<void> load(String id) async {
    state = const AsyncValue.loading();
    state = await guardAppException(() => _fetchOrder.execute(input: id));
  }

  Future<void> refresh(String id) async {
    // Keeps the current value on screen through the reload.
    state = const AsyncValue<Order?>.loading().copyWithPrevious(state);
    state = await guardAppException(() => _fetchOrder.execute(input: id));
  }
}
```

- **`guardAppException`** (from `package:core/core.dart`) captures an expected
  `AppException` into `AsyncValue.error`. Anything else is rethrown so it
  reaches `PlatformDispatcher.onError` / `AppProviderObserver` instead of
  becoming quiet error state. There is no `BlocStatus` here: `AsyncValue` plus
  `copyWithPrevious` already covers initial/loading/success/failure *and* keeps
  the last good value across a failure.
- **`ref.mounted`** must guard any `state =` that follows an `await` in a
  hand-written multi-step method — the notifier can be disposed mid-flight.
- **Read your own current state with `await future`**, a notifier property, not
  a `ref` call: `state = AsyncData([...await future, newItem]);`
- **autoDispose is the default**, so a controller dies with its page. There is
  nothing to close in `dispose()`.
- **Family arguments go on `build()`**, not the constructor.

## Wire routing

Routing is not part of the baseline slice — this skill wires it, **for every
page**:

1. **`lib/features/<feature>/presentation/routing/<feature>_routes.dart`** —
   create it once per feature; add the import and a `@TypedGoRoute` class for
   each page, then collect them into `<feature>Routes`:

   ```dart
   import 'package:flutter/material.dart';
   import 'package:go_router/go_router.dart';
   import 'package:<pkg>/features/<feature>/presentation/view/pages/<page>/<page>_page.dart';

   part '<feature>_routes.g.dart';

   @TypedGoRoute<<Page>Route>(path: '/<page>')
   class <Page>Route extends GoRouteData with $<Page>Route {
     const <Page>Route();
     @override
     Widget build(BuildContext context, GoRouterState state) =>
         const <Page>Page();
   }

   final List<RouteBase> <feature>Routes = [$<page>Route];
   ```

2. **`lib/routing/routes.dart`** — import `<feature>Routes` and spread it into
   `appRoutes`. `lib/app/view/app.dart` is never touched: it reads the single
   `appRoutes` list and never names an individual route.

## Build

```bash
melos build
```

Regenerates `*.g.dart` (including the `<feature>_providers.g.dart` and
`<feature>_controller.g.dart` that define `<name>Provider`), `*.freezed.dart`,
and `routes.g.dart`. A missing provider shows up as an **undefined-name compile
error**, not a runtime lookup failure — which is the main ergonomic gain over
the injectable variant.

Report next steps: `melos <app>` to launch, and where to navigate.

## Test the feature

Providers are the test seam: **override one leaf and let the real graph build
everything else.** Do not hand-assemble the chain — that proves the classes
compose but nothing about the wiring.

Write `test/features/<feature>/<feature>_controller_test.dart`, modelled on the
generated `login_controller_test.dart`:

```dart
class _MockOrdersRepository extends Mock implements IOrdersRepository {}

// Only the repository is overridden. The use cases are still built by their
// real providers, exactly as in the running app.
ProviderContainer container() => ProviderContainer.test(
      overrides: [
        ordersRepositoryProvider.overrideWithValue(repository),
      ],
    );

test('surfaces a typed AppException as AsyncError', () async {
  when(() => repository.fetchOrder(any()))
      .thenThrow(const NotFoundException(message: 'gone'));

  // `listen` — not a bare `read` — keeps an autoDispose provider alive.
  final c = container()..listen(ordersControllerProvider, (_, _) {});
  await c.read(ordersControllerProvider.notifier).load('id');

  expect(
    c.read(ordersControllerProvider),
    isA<AsyncError<Order?>>()
        .having((s) => s.error, 'error', isA<NotFoundException>()),
  );
});
```

- **`ProviderContainer.test`** auto-disposes at the end of the test, so state
  never leaks between tests. This is what replaces the injectable variant's
  global `test` environment.
- **Widget tests** use the `pumpApp` helper's `overrides:` parameter, which
  wraps the widget in a `ProviderScope`.
- **`data/repositories/mock/` is not for unit tests.** It exists so the `test`
  flavor (`main_test.dart`) can run the whole app on deterministic data. Unit
  tests fake the domain interface per test, as above.
- Add the feature's providers to `test/di/overrides_test.dart` so a forgotten
  override fails the suite instead of silently using the real repository.

Run with `melos test:unit-widget`.

## Update MEMORY.md

Required, before you report done. In `MEMORY.md` at the monorepo root:

- **`## Feature Map`** — add or update one row:
  `| feature | app | entity | pages -> routes | use cases | notes |`. Say in
  `notes` whether `...<feature>Overrides(environment)` was added to
  `lib/di/overrides.dart` and whether the feature's providers were added to
  `test/di/overrides_test.dart` — a missing override is invisible at runtime,
  so the next agent needs to know.
- **`## Current State`** — add the feature to the features line.
- **`## Component Index`** — one row for any component you delegated to
  create-component (that skill adds its own, so check before duplicating).
- **`## Requirements`** — one `R-<n>` for each constraint the user stated
  during the interview. These are what a later agent cannot re-derive from the
  code.
- **`## Decisions`** / **`## Gotchas`** — anything durable you decided or hit.
- **`## Session Log`** — one line.

Follow `## How to maintain this file` at the top of `MEMORY.md` for the
append-vs-edit test, the id scheme, and the trim triggers. Do not restate that
protocol here, and do not copy rules out of `CLAUDE.md` into `MEMORY.md`.

## Prerequisites

- **Dart SDK ≥ 3.2.3** on `PATH`.
- **`melos`** for the Build step.
- An **existing monorepo of this shape with at least one app package**.
- **Figma MCP** is optional.

## Design-system reference

- **Existing components** (`packages/core/lib/src/presentation/components/`),
  all exported from `package:core/core.dart`: `AmbientBackdrop`, `FormMessage`,
  `FormTextInput<T>`, `IconActionButton`, `LabelChip`, `LabeledTextField`,
  `NavBar`, `PasswordField`, `PasswordStrengthMeter`, `PillButton`,
  `PromptLink`. `MEMORY.md`'s **Component Index** is the live list, with each
  one's folder and `ThemeData` fields.
- **Theme / tokens** (`packages/core/lib/src/presentation/theme/`): read fields
  off `Theme.of(context).colorScheme` / `.textTheme` rather than hard-coding.
- **New components** via **create-component**.

## Gotchas

- **`ref.read` anywhere is a bug in this codebase.** See the rule at the top.
  Riverpod's own docs disagree about widget callbacks; this scaffold does not.
- **`late final` on a controller dependency throws on rebuild.** Use `late`.
- **A forgotten `...<feature>Overrides(environment)` is silent.** The feature
  works — it just never uses the mock, in any environment.
- **`AsyncValue.valueOrNull` was removed in Riverpod 3.** Use `.value`, which
  returns null on error.
- **Codegen providers are autoDispose by default.** `@Riverpod(keepAlive: true)`
  is the singleton form.
- **Automatic retry with backoff is on by default**, so a provider that throws
  on construction is silently re-run — a wiring bug can look like a slow start.
- **`Override` is exported by `riverpod_annotation`, not `flutter_riverpod`.**
  Files that name the type need that import.
- **riverpod_lint is an analysis-server plugin** (>= 3.1), declared under
  `plugins:` in the *workspace-root* `analysis_options.yaml`. It is ignored in a
  package-level options file. There is no `custom_lint` runner; `dart analyze`
  surfaces the rules.
- **Feature naming is pluralized, entity naming is singularized** (feature
  `orders` → entity `Order`).
- **Never write over an existing feature.** If `features/<feature>/` is already
  there, stop and confirm first — running this skill again over a customized
  slice loses the customizations.
- **Route every page**; a page without a route is unreachable.
- **`melos build` is required**, not optional.
- **No git commit.**

## Troubleshooting

| Symptom | Fix |
|---|---|
| `<name>Provider` undefined | The provider file's `.g.dart` isn't generated — run `melos build`. If it persists, check the file has `part '<file>.g.dart';` and an `@riverpod` annotation. |
| `Type 'Override' not found` | Add `import 'package:riverpod_annotation/riverpod_annotation.dart';` — `flutter_riverpod` does not export it. |
| `LateInitializationError` in a controller | A dependency field is `late final`; make it `late`. |
| The `test` flavor hits the real repository | `...<feature>Overrides(environment)` is missing from `lib/di/overrides.dart`. |
| `Tried to use a notifier in an uninitialized state` | `ref` or `state` used in a Notifier constructor — move it into `build()`. |
| Build fails after routing edit (`$<Page>Route` undefined) | Expected until `melos build` generates `routes.g.dart`. |
| `The class '_$<Name>ThemeData' isn't defined` | Run `melos build:core`. |
| `melos: command not found` | `dart pub global activate melos`. |
