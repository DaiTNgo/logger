# Log Viewer Flutter UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the starter Flutter counter app with a responsive, interactive LogViewer screen that faithfully reproduces the supplied HTML layout and sample content.

**Architecture:** Keep this single-screen prototype in `lib/main.dart`, using small private widgets for the top app bar, search tokens, structured filters, log rows, and mobile navigation. `LogViewerPage` owns only the UI state required by the visible controls: keyword list, filter visibility, match-case/search-mode toggles, selected match, and active navigation destination.

**Tech Stack:** Flutter 3.44.8, Dart 3.12.2, Material 3, `flutter_test`, `google_fonts` for IBM Plex Sans and IBM Plex Mono.

## Global Constraints

- Reproduce the HTML reference in `stitch_modular_log_search_interface/code.html`; no product backend, persistence, or real log ingestion is in scope.
- Keep all user-facing labels and the ten supplied sample log messages exactly as shown in the HTML reference.
- Use the HTML color values: primary `#0F62FE`, primary container `#D0E2FF`, surface `#FFFFFF`, surface container `#F4F4F4`, border `#E0E0E0`, outline `#8D8D8D`, text `#161616`, secondary text `#525252`, success `#198038`, warning `#F1C21B`, warning background `#FCF4D6`, and error `#DA1E28`.
- Use IBM Plex Sans for regular UI and IBM Plex Mono for tokens, timestamps, levels, counters, and log messages through `google_fonts`; do not add local font files.
- Support narrow mobile layouts as in the reference: horizontally scrollable token/filter strips, vertically scrolling logs, and a 64 px bottom navigation bar. Do not hide the bottom navigation by platform or screen width.
- Keep the app dependency-light: add only `google_fonts: ^6.3.3`; use Flutter Material icons rather than image assets or icon packages.
- Preserve `flutter_lints` and make `flutter analyze` and `flutter test` pass before handoff.

---

## File Structure

- `pubspec.yaml` — declares the IBM Plex font provider package.
- `lib/main.dart` — contains the complete screen model, stateful page, reusable visual widgets, colors, and all sample data for this single-screen prototype.
- `test/widget_test.dart` — replaces counter smoke coverage with behavioral widget tests for the replicated UI.

### Task 1: Establish the app shell, visual tokens, and static log viewer

**Files:**
- Modify: `pubspec.yaml:31-35`
- Modify: `lib/main.dart:1-126` (replace starter app entirely)
- Modify: `test/widget_test.dart:1-37` (replace starter test entirely)

**Interfaces:**
- Consumes: Flutter Material widgets and `GoogleFonts.ibmPlexSans` / `GoogleFonts.ibmPlexMono`.
- Produces: `MyApp`, `LogViewerPage`, `LogEntry`, `LogLevel`, `sampleLogs`, `KeywordToken`, `StructuredFilter`, and `LogRow`; Task 2 adds callbacks to these widgets without changing their displayed copy.

- [ ] **Step 1: Write the failing app-shell test**

Replace `test/widget_test.dart` with this test before changing production code:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/main.dart';

void main() {
  testWidgets('renders the LogViewer reference content', (tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('LogViewer'), findsOneWidget);
    expect(find.text('5 KEYWORDS'), findsOneWidget);
    expect(find.text('ECU_MAIN'), findsOneWidget);
    expect(find.textContaining("Failed to resolve host 'db-replica-sec.internal'."), findsOneWidget);
    expect(find.text('Explorer'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the widget test to verify it fails**

Run: `flutter test test/widget_test.dart`

Expected: FAIL because the counter starter app does not render `LogViewer`.

- [ ] **Step 3: Add the font dependency and replace the starter screen with the static reference layout**

Add this dependency under `dependencies` in `pubspec.yaml`:

```yaml
google_fonts: ^6.3.3
```

Replace `lib/main.dart` with one Material 3 application that sets its title to `LogViewer`, disables the debug banner, uses a white `ColorScheme`, and routes home to `LogViewerPage`. Define this data contract and reference data in the file:

```dart
enum LogLevel { info, warning, error }

class LogEntry {
  const LogEntry({
    required this.time,
    required this.level,
    required this.message,
    this.highlightedWord,
    this.isActive = false,
  });

  final String time;
  final LogLevel level;
  final String message;
  final String? highlightedWord;
  final bool isActive;
}

const sampleLogs = <LogEntry>[
  LogEntry(time: '10:42:01', level: LogLevel.info, message: 'System initialization complete. Module [core] started successfully in 142ms.'),
  LogEntry(time: '10:42:05', level: LogLevel.info, message: 'Network listener bound to 0.0.0.0:8080. Awaiting connections.'),
  LogEntry(time: '10:45:12', level: LogLevel.warning, message: 'High memory usage detected in worker pool. Current utilization: 85%. Consider scaling.'),
  LogEntry(time: '10:48:33', level: LogLevel.error, message: 'Connection timeout while attempting to reach database replica at 192.168.1.5:5432. Retrying in 5s...', highlightedWord: 'timeout'),
  LogEntry(time: '10:48:38', level: LogLevel.info, message: 'Retry 1/3: Attempting connection to secondary replica.'),
  LogEntry(time: '10:48:43', level: LogLevel.error, message: "Failed to resolve host 'db-replica-sec.internal'. DNS query timeout after 5000ms.", highlightedWord: 'timeout', isActive: true),
  LogEntry(time: '10:49:01', level: LogLevel.info, message: 'User session terminated gracefully. [UID: 9482-A]'),
  LogEntry(time: '10:50:15', level: LogLevel.info, message: "Scheduled task 'LogRotation' completed. 4 files compressed."),
  LogEntry(time: '10:52:05', level: LogLevel.warning, message: 'Deprecation warning: API endpoint /v1/users/list will be removed in next release.'),
  LogEntry(time: '10:55:00', level: LogLevel.info, message: 'Heartbeat sent to orchestrator. Status: HEALTHY.'),
];
```

Build the visual hierarchy as `Scaffold(body: SafeArea(child: Column(...)))`: a 48 px white header with menu, `LogViewer`, and search icons; a `#F4F4F4` search panel; a horizontally scrolling filter strip; an `Expanded` `ListView` of `LogRow`s; and a 64 px bottom navigation. Give the search field `Key('keyword_input')`, the keyword count `Key('keyword_count')`, the selected error row `Key('active_log_row')`, and the filter strip `Key('filter_strip')` so the tests can target them. Use `GoogleFonts.ibmPlexSans` and `GoogleFonts.ibmPlexMono`, square corners, 1 px dividers, and the color constants in the Global Constraints.

- [ ] **Step 4: Run formatting, static analysis, and the app-shell test**

Run: `dart format lib/main.dart test/widget_test.dart && flutter analyze && flutter test test/widget_test.dart`

Expected: formatter completes, analyzer reports no issues, and `renders the LogViewer reference content` passes.

- [ ] **Step 5: Commit the independently working static screen**

```bash
git add pubspec.yaml pubspec.lock lib/main.dart test/widget_test.dart
git commit -m "feat: build log viewer reference layout"
```

### Task 2: Implement the reference controls and deterministic UI state

**Files:**
- Modify: `lib/main.dart` (add state and callbacks inside `LogViewerPage` plus interactive parameters to `KeywordToken`, `StructuredFilter`, `LogRow`, and the bottom-navigation widget)
- Modify: `test/widget_test.dart` (add interaction tests after the rendering test)

**Interfaces:**
- Consumes: `LogViewerPage`, `LogEntry`, `sampleLogs`, and the widget keys created in Task 1.
- Produces: `LogViewerPage` behavior: `addKeyword(String)`, `removeKeyword(String)`, `clearFilters()`, `toggleAdvancedFilters()`, `setActiveMatch(int)`, and `setActiveDestination(int)`; all update screen state with `setState`.

- [ ] **Step 1: Write the failing interaction tests**

Append these tests to `test/widget_test.dart`:

```dart
testWidgets('removing a keyword updates the count', (tester) async {
  await tester.pumpWidget(const MyApp());

  await tester.tap(find.byKey(const Key('remove_timeout')));
  await tester.pump();

  expect(find.text('timeout'), findsNothing);
  expect(find.byKey(const Key('keyword_count')), findsOneWidget);
  expect(find.text('4 KEYWORDS'), findsOneWidget);
});

testWidgets('submitting a keyword adds a search token', (tester) async {
  await tester.pumpWidget(const MyApp());

  await tester.enterText(find.byKey(const Key('keyword_input')), 'latency');
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump();

  expect(find.text('latency'), findsOneWidget);
  expect(find.text('6 KEYWORDS'), findsOneWidget);
});

testWidgets('clear all removes structured filters', (tester) async {
  await tester.pumpWidget(const MyApp());

  await tester.tap(find.text('Clear all'));
  await tester.pump();

  expect(find.text('ECU_MAIN'), findsNothing);
  expect(find.text('Add filter'), findsOneWidget);
});

testWidgets('bottom navigation reflects the selected destination', (tester) async {
  await tester.pumpWidget(const MyApp());

  await tester.tap(find.text('Filters'));
  await tester.pump();

  final selected = tester.widget<Icon>(find.byKey(const Key('nav_icon_2')));
  expect(selected.color, const Color(0xFF0F62FE));
});
```

- [ ] **Step 2: Run the new tests to verify they fail**

Run: `flutter test test/widget_test.dart`

Expected: FAIL because Task 1 has no removal, submission, clear-all, or navigation state changes.

- [ ] **Step 3: Implement all visible control behavior with stable semantic keys**

Make `LogViewerPage` stateful and initialize it with the exact values from the HTML:

```dart
final _keywords = <String>['timeout', 'error', 'connection', 'retry', 'database'];
final _filters = <MapEntry<String, String>>[
  const MapEntry('ECU ID', 'ECU_MAIN'),
  const MapEntry('APID', 'TELE'),
  const MapEntry('CTID', 'NetworkComm'),
  const MapEntry('Log Level', 'Error, Fatal'),
  const MapEntry('Msg Type', 'Log'),
];
var _advancedFiltersVisible = true;
var _matchCase = false;
var _searchMode = false;
var _activeMatch = 1;
var _activeDestination = 0;
```

Define the page-state methods with these signatures and bodies:

```dart
void addKeyword(String value) {
  final keyword = value.trim();
  if (keyword.isEmpty || _keywords.contains(keyword)) return;
  setState(() => _keywords.add(keyword));
}

void removeKeyword(String keyword) {
  setState(() => _keywords.remove(keyword));
}

void clearFilters() {
  setState(_filters.clear);
}

void toggleAdvancedFilters() {
  setState(() => _advancedFiltersVisible = !_advancedFiltersVisible);
}

void setActiveMatch(int value) {
  setState(() => _activeMatch = value.clamp(0, 14));
}

void setActiveDestination(int value) {
  setState(() => _activeDestination = value);
}
```

Use these exact state transitions: input submission trims text, ignores empty/duplicate strings, then appends a token and clears the controller; each token close button has `Key('remove_<keyword>')` and removes that token; each logic button toggles its own label between `AND` and `OR`; `Clear all` empties `_filters`; each structured filter close button removes only its corresponding entry; the tune button toggles the structured-filter strip; match-case and search-mode buttons toggle their selected blue color; up/down arrows decrement/increment `_activeMatch` within `0..14` and render the counter as `${_activeMatch + 1}/15`; close in the search-action group clears only the search input; tapping a log row selects it and gives it the blue left rail and blue-tinted background; tapping a navigation item sets `_activeDestination`, with only its icon color equal to primary and keys `nav_icon_0` through `nav_icon_3`.

Keep the original static content when state has not been changed, including all keyword tokens, the `2/15` counter, filters, and the active timeout row. Preserve horizontal scrolling in the token and filter strips so the UI remains usable on 320 px-wide devices.

- [ ] **Step 4: Run the complete interaction suite**

Run: `dart format lib/main.dart test/widget_test.dart && flutter analyze && flutter test test/widget_test.dart`

Expected: formatter completes, analyzer reports no issues, and all five widget tests pass.

- [ ] **Step 5: Commit the interactive UI behavior**

```bash
git add lib/main.dart test/widget_test.dart
git commit -m "feat: add log search and filter interactions"
```

### Task 3: Verify responsive composition and clean project documentation

**Files:**
- Modify: `test/widget_test.dart` (add narrow-viewport composition test)
- Modify: `README.md:1-14` (replace starter text with run/test instructions and reference-source note)
- Modify: `lib/main.dart` only if verification exposes a width overflow or clipped fixed element.

**Interfaces:**
- Consumes: the fully interactive `MyApp` and its stable widget keys from Tasks 1–2.
- Produces: a tested narrow mobile composition and project instructions that identify the HTML source of truth.

- [ ] **Step 1: Write the failing narrow-viewport test**

Append this test to `test/widget_test.dart`:

```dart
testWidgets('keeps search, filters, logs, and navigation available on a narrow viewport', (tester) async {
  await tester.binding.setSurfaceSize(const Size(320, 700));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(const MyApp());
  await tester.pumpAndSettle();

  expect(tester.takeException(), isNull);
  expect(find.byKey(const Key('keyword_input')), findsOneWidget);
  expect(find.byKey(const Key('filter_strip')), findsOneWidget);
  expect(find.byKey(const Key('active_log_row')), findsOneWidget);
  expect(find.text('Explorer'), findsOneWidget);
  expect(find.text('Settings'), findsOneWidget);
});
```

- [ ] **Step 2: Run the narrow-viewport test to verify the current layout**

Run: `flutter test test/widget_test.dart --plain-name "keeps search, filters, logs, and navigation available on a narrow viewport"`

Expected: PASS if the scrollable rows and flexible search field from Tasks 1–2 are correctly composed; otherwise FAIL with a `RenderFlex overflow` that must be corrected in Step 3.

- [ ] **Step 3: Correct only verified layout overflow and document the screen**

If the test reports an overflow, make the fixed search action group horizontally scrollable or hide only its nonessential match counter at widths below 360 px, while retaining the input, tune button, and close action. Do not alter desktop/reference copy or colors. Replace `README.md` with:

````markdown
# LogViewer

A Flutter implementation of the responsive log-search interface in `stitch_modular_log_search_interface/code.html`.

## Run

```bash
flutter pub get
flutter run
```

## Verify

```bash
flutter analyze
flutter test
```
````

- [ ] **Step 4: Run final verification**

Run: `dart format lib/main.dart test/widget_test.dart && flutter pub get && flutter analyze && flutter test`

Expected: all commands exit successfully with no analyzer diagnostics or failing tests.

- [ ] **Step 5: Commit responsive verification and documentation**

```bash
git add README.md lib/main.dart test/widget_test.dart
git commit -m "docs: document log viewer app"
```

## Self-Review

- Spec coverage: Task 1 covers every HTML region and supplied visual content; Task 2 covers the user-operable buttons/tokens represented in the markup; Task 3 validates the reference mobile composition and documents how to run it.
- Placeholder scan: no implementation item delegates unspecified work; the only conditional layout correction is tied to a concrete test failure and gives the permitted corrective choices.
- Type consistency: `LogEntry`, `LogLevel`, `sampleLogs`, `MyApp`, and `LogViewerPage` are introduced in Task 1 and consumed unchanged by Tasks 2–3. The keys referenced by tests are defined in Task 1 or Task 2 with identical names.
