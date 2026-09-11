# Project memory — bp-riverpod

The current state of this workspace, auto-loaded into every session through the
`@MEMORY.md` import in `CLAUDE.md`. `CLAUDE.md` holds the **rules**; this file
holds the **facts**. Keeping it accurate is part of finishing a task.

<!-- ids: R=requirement D=decision G=gotcha S=slice · monotonic · never reused -->

## How to maintain this file

**When.** At the end of every task that changed a file under `packages/`, and
whenever the user states a requirement, you make a design decision, or you lose
time to a trap.

**Stable ids.** `R-<n>` requirement · `D-<n>` decision · `G-<n>` gotcha ·
`S-<n>` prototype slice. Monotonic, never reused, never renumbered — that is
what turns "was this preserved?" into a `grep`.

**Append or edit — one test.**

- The fact describes *how the project is now* → **edit the existing line**.
  Gate: run `grep -in "<subject>" MEMORY.md` first; a hit means edit, not append.
- The fact describes *a change that happened* → **append** one Session Log line.
- A change that contradicts an existing line does **both**: edit the line, then
  append `old -> new` to the Session Log.

**Write mode per section.**

| Section | Mode | May be trimmed? |
|---|---|---|
| Current State | replace in place | yes — it is only ever "now" |
| Feature Map | one row per feature, edit in place | only once the files are gone from disk |
| Component Index | one row per component, edit in place | only once the files are gone from disk |
| Design System | replace in place | yes |
| Prototype Slices | one `###` per slice, edit in place on re-implementation | body only, after a verbatim archive |
| Requirements (`R-`) | append only | **never** |
| Decisions (`D-`) | append only; supersede with a stub | **never** |
| Gotchas (`G-`) | append only; mark "no longer applies" | **never** |
| Session Log | append, newest first | yes — archived, never deleted |

**Trim triggers.** Run both before you finish a memory update:

```bash
wc -l MEMORY.md                                                          # > 400 -> compact
awk '/^## Session Log/{f=1;next} /^## /{f=0} f&&/^- /' MEMORY.md | wc -l  # > 20  -> compact
```

**Compaction pass** — in this order, no shortcuts:

1. Select the Session Log entries older than the newest **10**.
2. **Promote first.** Every durable fact in a selected entry must already exist
   somewhere permanent: a requirement under `## Requirements`, a decision under
   `## Decisions`, a trap under `## Gotchas`, a created file / route / provider /
   component as a row in `## Feature Map` or `## Component Index`. If it is not
   there, put it there now. **Never archive an entry whose durable content has
   not been promoted** — this single rule is what stops trimming from losing
   requirements.
3. Move the selected entries **verbatim and unedited** to the top of
   `.claude/memory/CHANGELOG.md`, under a new
   `## <YYYY-MM-DD> archived from MEMORY.md` heading.
4. Re-run `wc -l MEMORY.md`. Still over 400? Run the reorganize pass.

**Reorganize pass** — only when the curated sections themselves overflow:

- Collapse prose that restates a table row into the row. One row, one line.
- Prototype slices beyond the newest **3**: move the whole `###` section
  verbatim to the changelog and leave a one-line row under
  `### Archived slices` (name · feature path · routes · archive date).
- A superseded decision keeps a one-line stub —
  `- **D-3** — <title> (superseded by D-9; full text in CHANGELOG)` — and only
  its body moves.
- Never merge two gotchas. Never reword a requirement. Never renumber an id.

**Never.**

- Delete an `R-`, `D-` or `G-` entry, or reuse its number.
- Delete a Feature Map or Component Index row while those files exist on disk.
- Edit text while moving it into `.claude/memory/CHANGELOG.md`.
- Let this file pass 400 lines without running the compaction pass.

## Current State
<!-- format: replace in place · keep under 15 lines -->

- **Apps:** `packages/hello`
- **Shared:** `packages/core`
- **State management:** Riverpod 3 — one `@riverpod` controller per page, state as `AsyncValue`
- **`core` exports:** `full` — a single `core.dart` barrel
- **Design system:** a design-system bundle applied at create time
- **Features:** `onboarding` (baseline slice shipped at create time)
- **Error reporting:** `errorReporterProvider` in `core`, defaulting to a
  no-op. `bootstrap` owns the instance: it builds a `ConsoleErrorReporter` when
  a `main_<flavor>.dart` passes none, installs it in the crash net, hands it to
  `AppProviderObserver`, and splices `overrideWithValue` into the root scope.
  `ref.guardAppException` reads it. See D-4.
- **Last verified:** never — run `melos bs && melos build && melos analyze`

## Feature Map
<!-- format: | feature | app | entity | pages -> routes | use cases | notes | -->

| Feature | App | Entity | Pages → routes | Use cases | Notes |
|---|---|---|---|---|---|
| `onboarding` | `hello` | `User` | landing → `/landing`, login → `/login`, signup → `/signup` | Login, Signup | baseline slice from the scaffold; declares its own routes, aggregated by `appRoutes` — `/` and `/main` are app-level, not part of it |

## Component Index
<!-- format: | component | folder under core/lib/src/presentation/components/ | ViewModel? | key ThemeData fields | -->

| Component | Folder | ViewModel | Key `ThemeData` fields |
|---|---|---|---|
| `AmbientBackdrop` | `ambient_backdrop/` | no | ground colour, `List<AmbientWash>` (colour, centre, radius, alpha) |
| `FormMessage` | `form_message/` | no | background, foreground, message style, **icon** (required), radius, padding |
| `FormTextInput<T>` | `form_text_input/` | yes — `FormTextInputViewModel<T>` | decoration, content padding, text style |
| `IconActionButton` | `icon_action_button/` | no | background, icon/disabled icon colour, hover, highlight, size (44), icon size |
| `LabelChip` | `label_chip/` | no | container decoration, label style |
| `LabeledTextField` | `labeled_text_field/` | no | fill, outline, focus ring, cursor, label/text/hint styles, height, radius, `isLabelUppercased` |
| `NavBar` | `nav_bar/` | no | background, active/inactive colour, selected fill, shadow, radius, three paddings, icon size |
| `PasswordField` | `password_field/` | no | none — composes `LabeledTextField`, `IconActionButton` and `PasswordStrengthMeter` |
| `PasswordStrengthMeter` | `password_strength/` | yes — `PasswordStrengthMeterViewModel` | track colour, four ramp colours, label style, track height, label width |
| `PillButton` | `pill_button/` | no | background, foreground, label style, height, radius, padding, border, disabled opacity, pressed scale |
| `PromptLink` | `prompt_link/` | no | prompt style, action style, padding, text align |

Notes an agent needs before editing any of these:

- Every component resolves its colours through its own `<Name>ThemeData`, and
  every `ThemeData` has a `.fallback(context)` deriving from `ColorScheme`,
  `ColorExtension`, `DimensionExtension` and `textTheme`. A literal colour in a
  component is unreachable from a design-system bundle — it survives a rebrand
  and is then the one wrong colour on the screen.
- Each also has a `<Name>Theme` `InheritedWidget` with a
  `static <Name>ThemeData of(BuildContext)`, so a subtree can restyle every
  instance without touching a call site.
- `PasswordStrengthMeter`'s files are `password_strength/meter.dart` and
  `meter_view_model.dart`, not `<name>/<name>.dart` like the others: spelled
  out fully, the export line exceeds 80 characters and trips
  `lines_longer_than_80_chars`.
- Icons come from `AppIcons` and render through `AppIcon`. There is no Material
  glyph fallback and no unicode arrow, chevron or check anywhere in `core`.

## Design System
<!-- format: replace in place -->

A design-system bundle was applied at create time from
`.design-system/bundle.json` — colours, dimensions and typography are already
rendered into `packages/core/lib/src/presentation/theme/`. The bundle's
`components[]` may still be unimplemented; run **import-design-system** to
finish or re-apply it.

## Prototype Slices
<!-- format: newest first · one ### per slice · edit in place on re-implementation -->

_None yet._

<details><summary>Slice entry template — the single source of truth for the format</summary>

```markdown
### S-<n> <Slice name>

- **Source:** <prototype URL> — file `<path/to/File.html>`
- **Type:** page | flow | feature · **Status:** created | updated
- **App / feature:** `packages/<app>/lib/features/<feature>/`
- **File map:** <prototype element> → `<path>`
- **Components:** reused <names>; created <names> (via create-component)
- **Routes added:** `/<page>` (`<Page>Route`)
- **Integration points:** consumes <...>; entered from <...>; shared state <...>
- **Gotchas:** promoted to `## Gotchas` as G-<n>
```

</details>

## Requirements
<!-- append only · NEVER trimmed · id R-<n> -->

- **R-1** — This workspace uses one state-management architecture; every app
  package must match it. It was chosen at create time and is baked into
  `packages/core`.

## Decisions
<!-- append only · NEVER deleted · supersede with a one-line stub · id D-<n> -->

- **D-1** (create time) — Scaffolded with the state-management
  and `core`-export variants recorded above. Changing either afterwards means
  regenerating, not editing.
- **D-2** (create time) — Error envelope: `ApiClient` reads a non-2xx body
  tolerantly and the backend's code beats the status in `AppException.code`.
  Messages are log-only; copy comes from `forCode`, with the type as fallback.
- **D-3** (2026-08-21) — Generated Dart (`*.freezed.dart`, `*.g.dart`) and every
  `build/` directory are gitignored at the workspace root. Codegen output is a
  pure function of the sources plus `melos build`, so committing it only adds
  merge conflicts and unreviewable diff noise.
- **D-4** (2026-09-10) — `ErrorReporter` reaches its consumers through a
  Riverpod provider, not through the `appErrorReporter` global (deleted), and
  **`bootstrap` owns the instance end to end**. It is a nullable parameter:
  pass one to forward crashes to Sentry/Crashlytics, or pass nothing and
  `bootstrap` builds a `ConsoleErrorReporter` (which lives in `core`, beside
  `NoopErrorReporter`, precisely so `core` can construct the default without
  naming an app class). That one object is installed in `FlutterError.onError`
  / `PlatformDispatcher.onError`, handed to `AppProviderObserver`, and bound to
  `errorReporterProvider` by an override `bootstrap` prepends to the list
  `overridesBuilder` returns — first in the list, so an app's own
  `buildOverrides` can still replace it. One door, so the crash lane and the
  handled lane cannot drift apart, and all four `main_<flavor>.dart` stay free
  of reporter wiring.
- **D-5** (2026-09-10) — The ref rule relaxed: `ref.read` is no longer banned
  outright, it is confined to Notifier **methods** while `ref.watch` stays
  confined to `build()`. `guardAppException` became an extension on `Ref`
  (`ref.guardAppException(…)`) because a free function cannot reach a provider,
  and threading the reporter through every call site instead would have put a
  cross-cutting service into three constructors. Riverpod's own docs place
  `ref.read` in methods, so this moves the rule onto their guidance rather than
  one step stricter than it. Dependencies are still resolved once in `build()`
  onto `late` fields — `ref.read` fetching a use case from a method is still
  wrong.
- **D-6** (2026-09-10) — **`AppProviderObserver` is the only place a provider
  failure is reported.** Riverpod calls `providerDidFail` for every error that
  lands in provider state, captured or not (G-7), so the observer already sees
  everything `guardAppException` catches; `guardAppException` therefore reports
  nothing and is a plain `AsyncValue.guard` again. The observer tells the two
  lanes apart by type, which is what the taxonomy is for: an `AppException` is
  expected and renderable, so `reportHandled` (a breadcrumb, no stack trace);
  anything else escaped typing on its way out of the data layer, so `report`
  (a crash, with the stack trace). Its `log` line no longer interpolates
  `$stackTrace` either — that ran whatever the reporter was, so it was the half
  of the output swapping in a `NoopErrorReporter` could not turn off.
  Rejected: marking the exception instance in `guardAppException` for the
  observer to skip. Const `AppException` literals are canonicalized — the mock
  repository throws `const UnauthorizedException(…)` — so an `Expando` or
  identity set would mark every structurally identical instance. This aligns
  the variant with `bp-mvvm` and `bp-bloc`, where a handled failure has always
  produced exactly one breadcrumb and no stack trace.
- **D-7** — the breadcrumb names the wrapped cause (absorbed into D-11; full text in CHANGELOG)
- **D-8** — handled breadcrumbs carry both ends (superseded by D-11; full text in CHANGELOG)
- **D-9** — `report` is the only method an implementation writes; `reportHandled` funnels into it with `handled: true`, and the shipped reporters `extends` rather than `implements` (full text in CHANGELOG)
- **D-10** (2026-09-11) — **`handled at:` is the `on AppException` catch**,
  not the code that started the action. Frame 0 of a `StackTrace.current`
  captured inside the catch — `AppProviderObserver.providerDidFail` — with no filtering, mirroring
  `thrown at:`, which is frame 0 of the origin trace. The question the field
  answers is "what code handled this", and the handler is the answer; the
  caller is a different question. This removed the frame filter entirely
  (G-9), the entry-time capture (G-10), and the per-variant fork of
  `errorReporter()` that the filter had forced — the template is one body for
  all three variants again. Pinned by *"handledAt points at the catch block,
  not the caller"* and *"names the handling block, frame 0 and unfiltered"*.

- **D-11** (2026-09-11) — A handled breadcrumb carries **three** frames, not
  two: `thrown at:` (frame 0 of `AppException.stackTrace`), `handled at:`
  (frame 0 of a capture inside the `on AppException` catch, D-10) and
  `invoked at:` — what *started* the action, e.g. the `signup.execute()` in a
  view model. `invokedAt` needs its own capture, taken **before** the await,
  because an async trace keeps only awaiting frames and a method that returns
  the command's future without awaiting is gone by the catch (G-10, which
  therefore applies again — to this field only). It is also the **one**
  filtered frame: whoever captured it is the top of its own trace, so `core`
  and the state-management package are stepped over to reach app code (G-9,
  likewise back, scoped to `_callSiteFrame`). Riverpod passes one trace for
  both — its observer runs synchronously from `state =`, so the controller is
  under the framework's frames in the same capture — which is why
  `errorReporter()` forks on state management: only that variant's skip list
  needs `package:riverpod/`. The three render as a tree under the
  `handled:` header — `├─`/`└─`, not an indent, because `dart:developer`
  hands the console one multi-line string and a console may strip leading
  whitespace or interleave other output between the lines — and share one
  colour, since what they need to say is that they belong to the header, not
  that they differ from each other. `ConsoleErrorReporter.colored` defaults to
  `kDebugMode`: escape codes are noise in a log file, a CI job, or logcat, so
  a debug build on a device wants `const ConsoleErrorReporter(colored:
  false)`. Terminal detection was not an option — `dart:io` is not web-safe
  and `core` builds for web.

## Gotchas
<!-- append only · NEVER deleted · id G-<n> -->

- **G-1** — Generated files (`*.g.dart`, `*.freezed.dart`, `routes.g.dart`) are
  build_runner outputs. Hand-editing one is silently reverted by the next
  `melos build`.
- **G-2** — Registering a feature's providers but forgetting
  `...<feature>Overrides(environment)` in `packages/<app>/lib/di/overrides.dart`
  fails **silently**: every flavor, including `test`, keeps the real repository.
  `test/di/overrides_test.dart` is what catches it.
- **G-3** — Parsing a non-2xx body must stay in a `try`/`catch`: a bare
  `jsonDecode` on an HTML error page throws, losing the status and the `code`
  that tells one outage from another in the crash reporter.
- **G-4** — Because of D-3, a fresh clone does not analyze or run until
  `melos bs && melos build` has generated the freezed / json_serializable /
  go_router / riverpod outputs. Hundreds of "undefined class `_$Foo`" errors
  from `melos analyze` on a clean checkout mean codegen has not run, not that
  the tree is broken.
- **G-5** — `errorReporterProvider` defaults to `NoopErrorReporter`, **not** an
  `UnimplementedError` like `buildConfigurationProvider`. A widget test builds a
  bare `ProviderScope` with no root override, and a throwing default would fire
  from inside `ref.guardAppException`'s catch — turning a handled failure into
  a crash in the code path meant to prevent one. Pinned in
  `packages/hello/test/di/overrides_test.dart`. **Rationale superseded by D-6**
  — `guardAppException` no longer reads the provider — but the default still
  stands: `AppProviderObserver` resolves nothing, and app code may read it.
- **G-6** — `bootstrap` binds the reporter by prepending an override to the
  list `overridesBuilder` returns, so the binding does not exist until that
  future completes. A failure captured *during* `overridesBuilder()`
  breadcrumbs to the default no-op, which is why `bootstrap`'s own `try`/`catch`
  reports composition failures directly instead of relying on the handled lane.
- **G-7** — Assigning an `AsyncError` to a Notifier's `state` fires
  `ProviderObserver.providerDidFail`, exactly as a throwing `build()` does.
  Riverpod 3.4.2 `element.dart:106-121`: for an async provider the `AsyncError`
  is stored as *data*, so the `result is! $ResultError<StateT>` guard does not
  exclude it. So a deliberately captured failure is **not** invisible to the
  observer, and any `guard`-style helper that also reports files every handled
  failure twice — the second time as a crash with a stack trace. See D-6.
- **G-8** — A test that exercises `guardAppException` through a bare `Provider`
  proves nothing about the observer: a `Provider` merely *holding* an
  `AsyncError` never fails, so `providerDidFail` never runs and an
  `expect(crashes, isEmpty)` passes vacuously. That is how the G-7 double-report
  shipped under a green test. Use an `AsyncNotifier` and pass
  `observers: [AppProviderObserver(...)]` to `ProviderContainer.test`, as
  `runGuarded` / `_probe` in `packages/core/test/error_handling_test.dart` now
  do.

- **G-9** — The breadcrumb's plumbing filter matches **`'(package:core/'`
  and `'(dart:'` with the opening paren**, never the bare scheme. A frame reads
  `Member (<uri>:<line>:<col>)`, so a bare `'dart:'` matches the `.dart:` that
  ends *every* file path — every frame then looks like plumbing, the `orElse`
  fallback becomes the only branch that runs, and `handled at:` prints
  `providerDidFail` for every failure instead of the code that absorbed it. It fails
  silently and looks plausible. Pinned by *"names the app frame, not the
  plumbing that caught it"* in `packages/core/test/error_handling_test.dart`.

  **Scope narrowed (D-11):** `handled at:` is frame 0 and
  unfiltered; the filter survives for `invoked at:` alone.
- **G-10** — `handledAt` is captured **where the action is invoked**, not in
  the catch. A Dart async stack trace records only the frames that are
  *awaiting*: a presentation method written
  `Future<void> login() => _cmd.execute();` never awaits, so by the time the
  failure comes back it is gone from the trace and the breadcrumb names
  whichever widget happened to await — or, if nothing did, falls back to
  the observer itself. Measured, not assumed: catch-capture lost both the view
  model and the page; entry-capture keeps the whole synchronous chain. Pinned
  by *"handledAt reaches a caller that never awaited"* in
  `packages/core/test/error_handling_test.dart`.
  Riverpod is the exception and needs no entry capture: its observer is
  called synchronously from `state =`, so the controller is still on the
  stack when `providerDidFail` runs.
  **Scope narrowed (D-11):** the catch is the answer for
  `handled at:`; entry capture is what `invoked at:` uses.

## Session Log
- _2026-09-11_ — Handled-failure breadcrumbs rebuilt, and the generator with
  them (D-7…D-10, G-9, G-10). `handled: UnknownException(code: null)` — which
  names nothing — became the exception's full `toString()` plus `thrown at:`
  and `handled at:`, both frame 0 and unfiltered; `reportHandled` now funnels
  into `report` with `handled: true`, so an implementation writes one method
  and `extends`. Two detours on the way, both reverted and both recorded: a
  frame filter (G-9) and an entry-time capture (G-10), dropped once
  `handled at:` was settled as the `on AppException` catch itself. `bp-cli`
  carries the final shape; the three variants were regenerated from it and
  verified byte-identical.
- _2026-09-10_ — Fixed handled failures being reported twice (D-6, G-7, G-8).
  Symptom: a `LoginRepository` throwing `UnimplementedError` printed a full
  stack trace here but not in `bp-mvvm` / `bp-bloc`, whose
  `ConsoleErrorReporter` is byte-identical — the failure was travelling two
  lanes, not one. `guardAppException` dropped its
  `reportHandled` call and is now a one-line `AsyncValue.guard` (its
  `dart:async show unawaited` import went with it);
  `AppProviderObserver.providerDidFail` dropped the `UnknownException`
  normalization that only existed to unwrap `.cause` again, dropped
  `$stackTrace` from its `log` line, and now branches
  `reportHandled` / `report` on `error is AppException`. `errorReporterProvider`
  stays — `bootstrap` still overrides it and `overrides_test` still pins it.
  `error_handling_test.dart`'s `runGuarded` harness rebuilt on a real
  `AsyncNotifier` inside a container carrying the observer; three of its cases
  fail against the pre-fix source, the old vacuous one included. No app or
  controller file changed.
- _2026-09-10_ — `ErrorReporter` moved off the mutable `appErrorReporter`
  global and onto a Riverpod provider (D-4, D-5, G-5, G-6). Deleted the global
  from `core/src/error/error_reporter.dart` and added `ConsoleErrorReporter`
  beside it; added `errorReporterProvider` to
  `core/src/presentation/riverpod/async_error_handling.dart`; `bootstrap`'s
  `reporter` is now nullable, it builds that default itself and prepends
  `errorReporterProvider.overrideWithValue(sink)` to the root scope.
  `guardAppException` free function -> `Ref.guardAppException` extension, so the
  three controllers (`app_controller`, `login_controller`, `signup_controller`)
  gained a `ref.` prefix and nothing else. `CLAUDE.md` rules 9 and 11 relaxed
  accordingly. No `main_<flavor>.dart` changed. Every changed file under
  `packages/` is a byte-for-byte copy of
  `bp create --state-management riverpod` output.
<!-- format: `- <YYYY-MM-DD> <what changed> (skill|manual) -> <where it landed>` -->
<!-- newest first · keep the newest 10 · older entries move verbatim to .claude/memory/CHANGELOG.md -->

- _2026-08-21_ — root `.gitignore`: `/build/` -> unanchored `build/` (the old
  anchored rule missed `packages/core/build/`), plus `*.freezed.dart` and
  `*.g.dart`. Recorded as D-3 / G-4. Three build artifacts committed in the
  initial commit (`packages/core/build/5f4da827.../{.filecache,
  gen_localizations.stamp,outputs.json}`) are still tracked and need
  `git rm -r --cached` to drop.
- _create time_ — workspace scaffolded: `packages/core` plus
  `packages/hello`, baseline `onboarding` feature, eleven `core` components (manual)
  → whole tree
