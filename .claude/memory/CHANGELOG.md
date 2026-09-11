- **D-9** (2026-09-11) — **`report` is the only method an implementation
  writes.** `reportHandled` is concrete on `ErrorReporter` and funnels into
  `report(error, error.stackTrace ?? StackTrace.empty, handled: true,
  handledAt: ...)`; `handled` is what tells the two lanes apart. One decision
  point for formatting and destination instead of two overrides that drift —
  the drift being exactly how the riverpod variant ended up reporting a
  handled failure down both lanes (D-6). `NoopErrorReporter` and
  `ConsoleErrorReporter` therefore **`extends`** rather than `implements`:
  `implements` takes the interface and not the implementation, which would
  put the funnel back on every subclass to reproduce. `ErrorReporter` gained
  a `const` constructor so both stay `const`. The README's vendor sample
  changed with it. Pinned by *"reportHandled funnels into report as the
  handled lane"* in `packages/core/test/error_handling_test.dart`, and by the
  `_RecordingReporter`s, which now override `report` alone and so record the
  lane the funnel actually chose.


- **D-7** (2026-09-11) — `ConsoleErrorReporter.reportHandled` logs
  `handled: $error`, not `handled: <Type>(code: <code>)`. The direct
  consequence of D-6: once the crash lane stopped firing for handled
  failures, the breadcrumb was the only line left, and
  `handled: UnknownException(code: null)` identifies nothing —
  `OnboardingRepository.login`'s `UnimplementedError` had vanished from the
  output entirely. `AppException.toString()` already carries `message`, `code`
  **and** `cause`, so the fix is one interpolation. Applied identically to all
  three variants and to `bp-cli`'s shared `errorReporter()` template. Pinned
  by *"the mapped exception names its cause, for the breadcrumb"* in
  `packages/core/test/error_handling_test.dart`.


## 2026-09-11 archived from MEMORY.md

- **D-8** (2026-09-11) — A handled-failure breadcrumb carries **both ends**:
  `reportHandled` took a `{StackTrace? handledAt}` and `AppProviderObserver.providerDidFail` passes
  `StackTrace.current`. `ConsoleErrorReporter` prints `thrown at:` (frame 0 of
  `AppException.stackTrace`, verbatim — `guard` rethrows with
  `Error.throwWithStackTrace`, so frame 0 *is* the throw site, including when
  that site is `ApiClient` inside `core`) and `handled at:` (the first frame
  that is not plumbing). Counting breadcrumbs says how often something breaks;
  the pair says what is already absorbing it, which is what decides whether to
  act. The formatting is a public `ConsoleErrorReporter.formatHandled`
  precisely so a test can assert it — `dart:developer`'s sink is not
  observable from a test. See G-9.


# Memory archive — bp-riverpod

Append-only history trimmed out of `MEMORY.md`. Newest block first.

This file is **deliberately not imported** into `CLAUDE.md`, so it may grow
without bound and costs nothing per session. `grep -n` it when you need history
that `MEMORY.md` no longer carries.

Rules: content arrives here **verbatim** — never edit an archived entry, never
delete from this file, and never archive something whose durable content has
not first been promoted into `MEMORY.md`'s Requirements, Decisions, Gotchas,
Feature Map or Component Index.

<!-- archived blocks below, newest first -->
