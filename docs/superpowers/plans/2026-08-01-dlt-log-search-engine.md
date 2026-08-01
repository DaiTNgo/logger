# DLT Log Search Engine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build payload-only DLT log search with per-keyword AND/OR and case sensitivity, dynamic highlights, row navigation, and All logs/Matches only display modes.

**Architecture:** A pure Dart `LogSearchEngine` evaluates immutable keyword models and returns ordered row matches with merged character ranges. `LogViewerPage` owns query and navigation state, while `SearchPanel`, `LogTable`, and `LogPayloadCell` receive explicit display data and callbacks. Search begins with zero keywords and does not implement structured DLT filtering.

**Tech Stack:** Dart 3.12.2, Flutter Material, `flutter_test`, existing IBM Plex styles from `google_fonts`.

## Global Constraints

- Search only `LogEntry.message`, which represents the DLT payload/message.
- Keyword text is literal; regular-expression syntax has no special behavior.
- When AND keywords exist, every AND keyword is required and OR keywords are optional.
- When only OR keywords exist, at least one OR keyword is required.
- Case sensitivity is configured per keyword.
- Count and navigate matching rows, not individual occurrences.
- Default display mode is `All logs`; initial keyword list is empty.
- Do not add packages or implement indexing, isolates, fuzzy matching, NOT, parentheses, or operator precedence.
- Preserve unrelated working-tree changes and use `rtk` for repository commands.

---

## File Map

- Create `lib/features/log_viewer/models/log_search.dart`: immutable search keyword, range, match, and display-mode types.
- Create `lib/features/log_viewer/services/log_search_engine.dart`: pure payload matching and range merging.
- Create `test/log_search_engine_test.dart`: unit-level search semantics and range tests.
- Modify `lib/models/log_entry.dart`: remove mock-only `highlightedWord`.
- Modify `lib/data/sample_logs.dart`: remove static highlight values.
- Modify `lib/features/log_viewer/widgets/log_row.dart`: render dynamic search ranges and distinguish selected rows from the current search row.
- Create `test/log_row_search_highlight_test.dart`: focused payload-highlight widget tests.
- Modify `lib/features/log_viewer/widgets/search_panel.dart`: consume `SearchKeyword` objects and expose real result/mode controls.
- Create `test/search_panel_test.dart`: focused counter, disabled-state, mode, and chip tests.
- Modify `lib/features/log_viewer/widgets/log_table.dart`: map visible source indexes to rows, ranges, and search navigation state.
- Modify `lib/features/log_viewer/log_viewer_page.dart`: own query evaluation, navigation, display-mode, and scrolling state.
- Modify `test/widget_test.dart`: replace mock search expectations with end-to-end behavior.

---

### Task 1: Pure Dart search model and engine

**Files:**
- Create: `lib/features/log_viewer/models/log_search.dart`
- Create: `lib/features/log_viewer/services/log_search_engine.dart`
- Create: `test/log_search_engine_test.dart`

**Interfaces:**
- Consumes: `LogEntry.message` from `lib/models/log_entry.dart`.
- Produces: `SearchKeyword`, `SearchKeywordMode`, `SearchDisplayMode`, `SearchRange`, `LogSearchMatch`, and `LogSearchEngine.search(List<LogEntry>, List<SearchKeyword>)`.

- [ ] **Step 1: Write failing tests for AND, OR, mixed, and empty queries**

Create `test/log_search_engine_test.dart` with these concrete cases:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/features/log_viewer/models/log_search.dart';
import 'package:logger/features/log_viewer/services/log_search_engine.dart';
import 'package:logger/models/log_entry.dart';

const logs = <LogEntry>[
  LogEntry(time: '1', level: LogLevel.info, message: 'timeout database'),
  LogEntry(time: '2', level: LogLevel.info, message: 'timeout retry'),
  LogEntry(time: '3', level: LogLevel.info, message: 'database ERROR'),
  LogEntry(time: '4', level: LogLevel.info, message: 'healthy'),
];

void main() {
  const engine = LogSearchEngine();

  test('no keywords means search is inactive', () {
    expect(engine.search(logs, const []), isEmpty);
  });

  test('all AND keywords are required', () {
    final matches = engine.search(logs, const [
      SearchKeyword(text: 'timeout'),
      SearchKeyword(text: 'database'),
    ]);
    expect(matches.map((match) => match.entryIndex), [0]);
  });

  test('OR-only query accepts a row containing any OR keyword', () {
    final matches = engine.search(logs, const [
      SearchKeyword(text: 'timeout', mode: SearchKeywordMode.or),
      SearchKeyword(text: 'database', mode: SearchKeywordMode.or),
    ]);
    expect(matches.map((match) => match.entryIndex), [0, 1, 2]);
  });

  test('OR keywords are optional when an AND keyword exists', () {
    final matches = engine.search(logs, const [
      SearchKeyword(text: 'timeout'),
      SearchKeyword(text: 'database', mode: SearchKeywordMode.or),
    ]);
    expect(matches.map((match) => match.entryIndex), [0, 1]);
  });

  test('case sensitivity applies to one keyword only', () {
    final insensitive = engine.search(logs, const [
      SearchKeyword(text: 'error', mode: SearchKeywordMode.or),
    ]);
    final sensitive = engine.search(logs, const [
      SearchKeyword(
        text: 'error',
        mode: SearchKeywordMode.or,
        caseSensitive: true,
      ),
    ]);
    expect(insensitive.map((match) => match.entryIndex), [2]);
    expect(sensitive, isEmpty);
  });
}
```

- [ ] **Step 2: Run the new tests and confirm missing-type failures**

Run:

```bash
rtk flutter test test/log_search_engine_test.dart
```

Expected: FAIL because the search model and engine files do not exist.

- [ ] **Step 3: Add immutable search models**

Create `lib/features/log_viewer/models/log_search.dart`:

```dart
enum SearchKeywordMode { and, or }

enum SearchDisplayMode { allLogs, matchesOnly }

class SearchKeyword {
  const SearchKeyword({
    required this.text,
    this.mode = SearchKeywordMode.and,
    this.caseSensitive = false,
  });

  final String text;
  final SearchKeywordMode mode;
  final bool caseSensitive;

  SearchKeyword copyWith({
    SearchKeywordMode? mode,
    bool? caseSensitive,
  }) => SearchKeyword(
    text: text,
    mode: mode ?? this.mode,
    caseSensitive: caseSensitive ?? this.caseSensitive,
  );
}

class SearchRange {
  const SearchRange(this.start, this.end);

  final int start;
  final int end;

  @override
  bool operator ==(Object other) =>
      other is SearchRange && start == other.start && end == other.end;

  @override
  int get hashCode => Object.hash(start, end);
}

class LogSearchMatch {
  const LogSearchMatch({required this.entryIndex, required this.ranges});

  final int entryIndex;
  final List<SearchRange> ranges;
}
```

- [ ] **Step 4: Implement the minimal pure Dart engine**

Create `lib/features/log_viewer/services/log_search_engine.dart`:

```dart
import 'package:logger/features/log_viewer/models/log_search.dart';
import 'package:logger/models/log_entry.dart';

class LogSearchEngine {
  const LogSearchEngine();

  List<LogSearchMatch> search(
    List<LogEntry> entries,
    List<SearchKeyword> keywords,
  ) {
    if (keywords.isEmpty) return const [];
    final requiredKeywords = keywords
        .where((keyword) => keyword.mode == SearchKeywordMode.and)
        .toList(growable: false);
    final matches = <LogSearchMatch>[];

    for (var entryIndex = 0; entryIndex < entries.length; entryIndex++) {
      final rangesByKeyword = <SearchKeyword, List<SearchRange>>{
        for (final keyword in keywords)
          keyword: _findRanges(entries[entryIndex].message, keyword),
      };
      final accepted = requiredKeywords.isNotEmpty
          ? requiredKeywords.every(
              (keyword) => rangesByKeyword[keyword]!.isNotEmpty,
            )
          : keywords.any((keyword) => rangesByKeyword[keyword]!.isNotEmpty);
      if (!accepted) continue;

      matches.add(
        LogSearchMatch(
          entryIndex: entryIndex,
          ranges: _mergeRanges(rangesByKeyword.values.expand((value) => value)),
        ),
      );
    }
    return List.unmodifiable(matches);
  }

  List<SearchRange> _findRanges(String payload, SearchKeyword keyword) {
    final expression = RegExp(
      RegExp.escape(keyword.text),
      caseSensitive: keyword.caseSensitive,
    );
    return [
      for (final match in expression.allMatches(payload))
        SearchRange(match.start, match.end),
    ];
  }

  List<SearchRange> _mergeRanges(Iterable<SearchRange> input) {
    final sorted = input.toList()
      ..sort((left, right) => left.start.compareTo(right.start));
    if (sorted.isEmpty) return const [];
    final merged = <SearchRange>[sorted.first];
    for (final next in sorted.skip(1)) {
      final current = merged.last;
      if (next.start <= current.end) {
        merged[merged.length - 1] = SearchRange(
          current.start,
          next.end > current.end ? next.end : current.end,
        );
      } else {
        merged.add(next);
      }
    }
    return List.unmodifiable(merged);
  }
}
```

- [ ] **Step 5: Run the semantic tests and confirm they pass**

Run:

```bash
rtk flutter test test/log_search_engine_test.dart
```

Expected: all five tests PASS.

- [ ] **Step 6: Add failing tests for occurrences, overlap, literals, and order**

Add these tests inside the existing `main()`:

```dart
test('returns every repeated occurrence in one matched row', () {
  final matches = engine.search(const [
    LogEntry(time: '1', level: LogLevel.info, message: 'error error'),
  ], const [SearchKeyword(text: 'error')]);
  expect(matches.single.ranges, const [SearchRange(0, 5), SearchRange(6, 11)]);
});

test('merges overlapping and adjacent keyword ranges', () {
  final matches = engine.search(const [
    LogEntry(time: '1', level: LogLevel.info, message: 'database'),
  ], const [
    SearchKeyword(text: 'data'),
    SearchKeyword(text: 'database', mode: SearchKeywordMode.or),
  ]);
  expect(matches.single.ranges, const [SearchRange(0, 8)]);
});

test('treats regex characters as literal text', () {
  final matches = engine.search(const [
    LogEntry(time: '1', level: LogLevel.info, message: 'retry [1/3]'),
  ], const [SearchKeyword(text: '[1/3]')]);
  expect(matches.single.ranges, const [SearchRange(6, 11)]);
});

test('preserves source entry order', () {
  final matches = engine.search(logs.reversed.toList(), const [
    SearchKeyword(text: 'timeout', mode: SearchKeywordMode.or),
    SearchKeyword(text: 'database', mode: SearchKeywordMode.or),
  ]);
  expect(matches.map((match) => match.entryIndex), [1, 2, 3]);
});
```

- [ ] **Step 7: Run all engine tests**

Run:

```bash
rtk flutter test test/log_search_engine_test.dart
```

Expected: all nine tests PASS without changing the public interfaces.

- [ ] **Step 8: Commit the engine**

```bash
rtk git add lib/features/log_viewer/models/log_search.dart lib/features/log_viewer/services/log_search_engine.dart test/log_search_engine_test.dart
rtk git commit -m "feat: add DLT payload search engine"
```

---

### Task 2: Dynamic payload highlights and search-row styling

**Files:**
- Modify: `lib/models/log_entry.dart`
- Modify: `lib/data/sample_logs.dart`
- Modify: `lib/features/log_viewer/widgets/log_row.dart`
- Create: `test/log_row_search_highlight_test.dart`

**Interfaces:**
- Consumes: `SearchRange` from Task 1.
- Produces: `LogPayloadCell(matchRanges:, isCurrentSearchMatch:)` and `LogRowShell(isCurrentSearchMatch:)` for `LogTable` in Task 4.

- [ ] **Step 1: Write failing focused widget tests for dynamic ranges**

Create `test/log_row_search_highlight_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/features/log_viewer/models/log_search.dart';
import 'package:logger/features/log_viewer/widgets/log_row.dart';
import 'package:logger/models/log_entry.dart';

const entry = LogEntry(
  time: '10:00:00',
  level: LogLevel.info,
  message: 'timeout then retry',
);

void main() {
  testWidgets('renders every supplied payload range as highlighted text', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: LogPayloadCell(
          entry: entry,
          isCurrentSearchMatch: true,
          matchRanges: [SearchRange(0, 7), SearchRange(13, 18)],
        ),
      ),
    ));

    final richText = tester.widget<RichText>(
      find.byKey(const Key('payload_search_highlights_10_00_00')),
    );
    final root = richText.text as TextSpan;
    final highlighted = root.children!
        .whereType<TextSpan>()
        .where((span) => span.style?.backgroundColor != null)
        .toList();
    expect(highlighted.map((span) => span.text), ['timeout', 'retry']);
  });

  testWidgets('keeps manual selection separate from current search match', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LogRowShell(
          entry: entry,
          isActive: false,
          isCurrentSearchMatch: true,
          onTap: () {},
          child: const Text('row'),
        ),
      ),
    ));
    expect(
      find.byKey(const Key('current_search_match_row_10_00_00')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('active_log_row')), findsNothing);
  });
}
```

- [ ] **Step 2: Run the focused tests and confirm constructor failures**

Run:

```bash
rtk flutter test test/log_row_search_highlight_test.dart
```

Expected: FAIL because `matchRanges` and `isCurrentSearchMatch` do not exist.

- [ ] **Step 3: Remove static mock highlight data**

In `lib/models/log_entry.dart`, remove the optional constructor parameter and field:

```dart
class LogEntry {
  const LogEntry({
    required this.time,
    required this.level,
    required this.message,
    this.dltValues = const {},
  });

  final String time;
  final LogLevel level;
  final String message;
  final Map<String, String> dltValues;
}
```

Remove both `highlightedWord: 'timeout'` arguments from `lib/data/sample_logs.dart`.

- [ ] **Step 4: Render normalized ranges as text spans**

Update `LogPayloadCell` and replace `_LogMessage` with explicit ranges:

```dart
class LogPayloadCell extends StatelessWidget {
  const LogPayloadCell({
    super.key,
    required this.entry,
    this.isCurrentSearchMatch = false,
    this.matchRanges = const [],
  });

  final LogEntry entry;
  final bool isCurrentSearchMatch;
  final List<SearchRange> matchRanges;

  @override
  Widget build(BuildContext context) => _LogMessage(
    entry: entry,
    isCurrentSearchMatch: isCurrentSearchMatch,
    matchRanges: matchRanges,
  );
}

class _LogMessage extends StatelessWidget {
  const _LogMessage({
    required this.entry,
    required this.isCurrentSearchMatch,
    required this.matchRanges,
  });

  final LogEntry entry;
  final bool isCurrentSearchMatch;
  final List<SearchRange> matchRanges;

  @override
  Widget build(BuildContext context) {
    final baseStyle = GoogleFonts.ibmPlexMono(
      color: AppColors.text,
      fontSize: 12,
    );
    if (matchRanges.isEmpty) return Text(entry.message, style: baseStyle);
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final range in matchRanges) {
      if (cursor < range.start) {
        spans.add(TextSpan(text: entry.message.substring(cursor, range.start)));
      }
      spans.add(TextSpan(
        text: entry.message.substring(range.start, range.end),
        style: baseStyle.copyWith(
          backgroundColor: isCurrentSearchMatch
              ? AppColors.primary
              : const Color(0x66D0E2FF),
          color: isCurrentSearchMatch ? AppColors.surface : AppColors.text,
          fontWeight: FontWeight.w600,
        ),
      ));
      cursor = range.end;
    }
    if (cursor < entry.message.length) {
      spans.add(TextSpan(text: entry.message.substring(cursor)));
    }
    return Text.rich(
      TextSpan(style: baseStyle, children: spans),
      key: Key('payload_search_highlights_${entry.time.replaceAll(':', '_')}'),
    );
  }
}
```

Import `log_search.dart` into `log_row.dart`.

- [ ] **Step 5: Add a separate current-search-row state**

Add `isCurrentSearchMatch` with a default of `false` to `LogRow` and `LogRowShell`, and forward it to `LogPayloadCell`. Preserve the existing `isActive` keys and left rail for manual selection. Add this keyed subtree inside `LogRowShell`:

```dart
final rowContent = KeyedSubtree(
  key: isActive
      ? Key('active_log_row_${entry.time.replaceAll(':', '_')}')
      : null,
  child: child,
);

child: KeyedSubtree(
  key: isCurrentSearchMatch
      ? Key('current_search_match_row_${entry.time.replaceAll(':', '_')}')
      : null,
  child: rowContent,
),
```

Use the current search match for the stronger background and bottom border while keeping the manual-selection left rail:

```dart
final background = isCurrentSearchMatch
    ? const Color(0x33D0E2FF)
    : isActive
    ? const Color(0x1AD0E2FF)
    : isWarning
    ? const Color(0x4DFCF4D6)
    : isError
    ? const Color(0x14DA1E28)
    : AppColors.surface;

final border = Border(
  bottom: BorderSide(
    color: isCurrentSearchMatch ? AppColors.primary : AppColors.border,
  ),
  left: BorderSide(
    color: isActive ? AppColors.primary : Colors.transparent,
    width: 4,
  ),
);
```

- [ ] **Step 6: Run focused tests and the existing row tests**

Run:

```bash
rtk flutter test test/log_row_search_highlight_test.dart
rtk flutter test test/widget_test.dart --plain-name "tapping a log row moves the active rail to that row"
```

Expected: both commands PASS. The old static timeout-highlight test in `test/widget_test.dart` may still fail in the full suite and will be replaced in Task 4.

- [ ] **Step 7: Commit dynamic highlighting**

```bash
rtk git add lib/models/log_entry.dart lib/data/sample_logs.dart lib/features/log_viewer/widgets/log_row.dart test/log_row_search_highlight_test.dart
rtk git commit -m "feat: render dynamic payload search highlights"
```

---

### Task 3: Real search controls and display-mode selector

**Files:**
- Modify: `lib/features/log_viewer/widgets/search_panel.dart`
- Create: `test/search_panel_test.dart`

**Interfaces:**
- Consumes: `List<SearchKeyword>`, `SearchDisplayMode`, active match index, and match count.
- Produces: `onToggleKeywordMode`, `onToggleMatchCase`, nullable previous/next callbacks, and `onDisplayModeChanged` callbacks for `LogViewerPage`.

- [ ] **Step 1: Write failing tests for empty, populated, and mode states**

Create `test/search_panel_test.dart` with a local builder that disposes its controller:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/features/log_viewer/models/log_search.dart';
import 'package:logger/features/log_viewer/widgets/search_panel.dart';

void main() {
  late TextEditingController controller;

  setUp(() => controller = TextEditingController());
  tearDown(() => controller.dispose());

  Widget panel({
    List<SearchKeyword> keywords = const [],
    int activeMatchIndex = 0,
    int matchCount = 0,
    SearchDisplayMode displayMode = SearchDisplayMode.allLogs,
    VoidCallback? onPrevious,
    VoidCallback? onNext,
    ValueChanged<SearchDisplayMode>? onModeChanged,
  }) => MaterialApp(
    home: Scaffold(
      body: SearchPanel(
        keywords: keywords,
        controller: controller,
        activeMatchIndex: activeMatchIndex,
        matchCount: matchCount,
        displayMode: displayMode,
        onSubmitted: (_) {},
        onRemoveKeyword: (_) {},
        onToggleKeywordMode: (_) {},
        onToggleMatchCase: (_) {},
        onPreviousMatch: onPrevious,
        onNextMatch: onNext,
        onDisplayModeChanged: onModeChanged ?? (_) {},
        onClearSearch: controller.clear,
      ),
    ),
  );

  testWidgets('empty search displays 0/0 and disables navigation', (tester) async {
    await tester.pumpWidget(panel());
    expect(find.text('0/0'), findsOneWidget);
    expect(tester.widget<IconButton>(find.byKey(const Key('previous_match'))).onPressed, isNull);
    expect(tester.widget<IconButton>(find.byKey(const Key('next_match'))).onPressed, isNull);
  });

  testWidgets('populated search displays row counter and keyword options', (tester) async {
    await tester.pumpWidget(panel(
      keywords: const [SearchKeyword(text: 'Timeout', caseSensitive: true)],
      activeMatchIndex: 1,
      matchCount: 3,
      onPrevious: () {},
      onNext: () {},
    ));
    expect(find.text('2/3'), findsOneWidget);
    expect(find.text('AND'), findsOneWidget);
    expect(find.byKey(const Key('keyword_match_case_Timeout')), findsOneWidget);
  });

  testWidgets('mode menu emits Matches only', (tester) async {
    SearchDisplayMode? selected;
    await tester.pumpWidget(panel(
      keywords: const [SearchKeyword(text: 'timeout')],
      onModeChanged: (value) => selected = value,
    ));
    await tester.tap(find.byKey(const Key('search_mode_control')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Matches only').last);
    expect(selected, SearchDisplayMode.matchesOnly);
  });
}
```

- [ ] **Step 2: Run the focused tests and verify API failures**

Run:

```bash
rtk flutter test test/search_panel_test.dart
```

Expected: FAIL because `SearchPanel` still accepts parallel keyword collections and a hard-coded counter.

- [ ] **Step 3: Refactor the SearchPanel contract**

Change its fields to this exact contract:

```dart
final List<SearchKeyword> keywords;
final TextEditingController controller;
final int activeMatchIndex;
final int matchCount;
final SearchDisplayMode displayMode;
final ValueChanged<String> onSubmitted;
final ValueChanged<String> onRemoveKeyword;
final ValueChanged<String> onToggleKeywordMode;
final ValueChanged<String> onToggleMatchCase;
final VoidCallback? onPreviousMatch;
final VoidCallback? onNextMatch;
final ValueChanged<SearchDisplayMode> onDisplayModeChanged;
final VoidCallback onClearSearch;
```

Build each chip directly from its model:

```dart
...keywords.map(
  (keyword) => _KeywordChip(
    value: keyword.text,
    logic: keyword.mode == SearchKeywordMode.and ? 'AND' : 'OR',
    matchCase: keyword.caseSensitive,
    onToggleLogic: () => onToggleKeywordMode(keyword.text),
    onToggleMatchCase: () => onToggleMatchCase(keyword.text),
    onRemove: () => onRemoveKeyword(keyword.text),
  ),
),
```

- [ ] **Step 4: Replace the hard-coded counter and navigation callbacks**

Pass the nullable callbacks into `_SearchActions` and render:

```dart
final counter = matchCount == 0
    ? '0/0'
    : '${activeMatchIndex + 1}/$matchCount';
```

Assign `onPressed: onPreviousMatch` and `onPressed: onNextMatch` directly so Flutter applies disabled button behavior at the boundaries.

- [ ] **Step 5: Add the compact display-mode menu beside the counter**

Add this control before the counter in `_SearchActions`:

```dart
PopupMenuButton<SearchDisplayMode>(
  key: const Key('search_mode_control'),
  enabled: keywords.isNotEmpty,
  initialValue: displayMode,
  onSelected: onDisplayModeChanged,
  itemBuilder: (context) => const [
    PopupMenuItem(
      value: SearchDisplayMode.allLogs,
      child: Text('All logs'),
    ),
    PopupMenuItem(
      value: SearchDisplayMode.matchesOnly,
      child: Text('Matches only'),
    ),
  ],
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        displayMode == SearchDisplayMode.allLogs
            ? 'All logs'
            : 'Matches only',
        style: GoogleFonts.ibmPlexSans(fontSize: 12),
      ),
      const Icon(Icons.arrow_drop_down, size: 18),
    ],
  ),
),
```

Extend `_SearchActions` with `keywords`, `displayMode`, and `onDisplayModeChanged` so the control can disable itself when the search is inactive.

- [ ] **Step 6: Run and format the focused component**

Run:

```bash
rtk dart format lib/features/log_viewer/widgets/search_panel.dart test/search_panel_test.dart
rtk flutter test test/search_panel_test.dart
```

Expected: formatting succeeds and all three focused tests PASS.

- [ ] **Step 7: Commit the search controls**

```bash
rtk git add lib/features/log_viewer/widgets/search_panel.dart test/search_panel_test.dart
rtk git commit -m "feat: show real search result controls"
```

---

### Task 4: Integrate search, filtering mode, navigation, and scrolling

**Files:**
- Modify: `lib/features/log_viewer/log_viewer_page.dart`
- Modify: `lib/features/log_viewer/widgets/log_table.dart`
- Modify: `test/widget_test.dart`

**Interfaces:**
- Consumes: all Task 1 models and engine results, Task 2 row parameters, and Task 3 callbacks.
- Produces: working end-to-end search state, source-index-aware table rendering, empty state, and active-result scrolling.

- [ ] **Step 1: Replace mock search tests with failing end-to-end expectations**

In `test/widget_test.dart`, remove the tests named:

- `renders padded timeout highlights for inactive and active rows`
- `renders the static search controls and Aa chip actions`
- `match navigation clamps the counter between one and fifteen`
- `narrow search controls scroll to and operate an action`

Replace them with:

```dart
testWidgets('search starts empty and inactive', (tester) async {
  await tester.pumpWidget(const MyApp());
  expect(find.text('Aa'), findsNothing);
  expect(find.text('0/0'), findsOneWidget);
  expect(find.byKey(const Key('payload_search_highlights_10_48_33')), findsNothing);
});

testWidgets('submitted payload keyword produces dynamic row matches', (tester) async {
  await tester.pumpWidget(const MyApp());
  await tester.enterText(find.byKey(const Key('keyword_input')), 'timeout');
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
  expect(find.text('1/2'), findsOneWidget);
  expect(find.byKey(const Key('payload_search_highlights_10_48_33')), findsOneWidget);
  expect(find.byKey(const Key('current_search_match_row_10_48_33')), findsOneWidget);
});

testWidgets('next match moves the active search row without moving selection', (tester) async {
  await tester.pumpWidget(const MyApp());
  await tester.tap(find.byKey(const Key('log_row_10_42_01')));
  await tester.pump();
  await tester.enterText(find.byKey(const Key('keyword_input')), 'timeout');
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('active_log_row_10_42_01')), findsOneWidget);

  await tester.tap(find.byKey(const Key('next_match')));
  await tester.pumpAndSettle();
  expect(find.text('2/2'), findsOneWidget);
  expect(find.byKey(const Key('current_search_match_row_10_48_43')), findsOneWidget);
  expect(find.byKey(const Key('active_log_row_10_42_01')), findsOneWidget);
});

testWidgets('Matches only hides nonmatching rows', (tester) async {
  await tester.pumpWidget(const MyApp());
  await tester.enterText(find.byKey(const Key('keyword_input')), 'timeout');
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('search_mode_control')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Matches only').last);
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('log_row_10_48_33')), findsOneWidget);
  expect(find.byKey(const Key('log_row_10_48_43')), findsOneWidget);
  expect(find.byKey(const Key('log_row_10_42_01')), findsNothing);
});

testWidgets('Matches only shows an empty state for zero results', (tester) async {
  await tester.pumpWidget(const MyApp());
  await tester.enterText(find.byKey(const Key('keyword_input')), 'not-present');
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('search_mode_control')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Matches only').last);
  await tester.pumpAndSettle();
  expect(find.text('No logs match the current search'), findsOneWidget);
  expect(find.text('0/0'), findsOneWidget);
});
```

- [ ] **Step 2: Run the end-to-end tests and confirm failure**

Run:

```bash
rtk flutter test test/widget_test.dart --plain-name "search starts empty and inactive"
rtk flutter test test/widget_test.dart --plain-name "submitted payload keyword produces dynamic row matches"
```

Expected: FAIL because the page still seeds five keywords and does not invoke the engine.

- [ ] **Step 3: Replace parallel page state with search models**

In `LogViewerPage`, add the Task 1 imports and replace the existing mock state with:

```dart
final _searchEngine = const LogSearchEngine();
final _keywords = <SearchKeyword>[];
final _keywordController = TextEditingController();
final _logScrollController = ScrollController();
final _rowKeys = <int, GlobalKey>{
  for (var index = 0; index < sampleLogs.length; index++) index: GlobalKey(),
};
var _matches = <LogSearchMatch>[];
var _activeMatchIndex = 0;
var _displayMode = SearchDisplayMode.allLogs;
```

Dispose `_logScrollController` alongside `_keywordController`.

- [ ] **Step 4: Add one mutation path that always recomputes results**

Add these page methods:

```dart
void _mutateSearch(VoidCallback mutation) {
  setState(() {
    mutation();
    _matches = _searchEngine.search(sampleLogs, _keywords);
    _activeMatchIndex = 0;
    if (_keywords.isEmpty) {
      _displayMode = SearchDisplayMode.allLogs;
    }
  });
  _scrollToActiveMatch();
}

void _addKeyword(String value) {
  final text = value.trim();
  if (text.isEmpty || _keywords.any((keyword) => keyword.text == text)) return;
  _mutateSearch(() => _keywords.add(SearchKeyword(text: text)));
}

void _removeKeyword(String text) => _mutateSearch(
  () => _keywords.removeWhere((keyword) => keyword.text == text),
);

void _toggleKeywordMode(String text) => _mutateSearch(() {
  final index = _keywords.indexWhere((keyword) => keyword.text == text);
  final keyword = _keywords[index];
  _keywords[index] = keyword.copyWith(
    mode: keyword.mode == SearchKeywordMode.and
        ? SearchKeywordMode.or
        : SearchKeywordMode.and,
  );
});

void _toggleMatchCase(String text) => _mutateSearch(() {
  final index = _keywords.indexWhere((keyword) => keyword.text == text);
  final keyword = _keywords[index];
  _keywords[index] = keyword.copyWith(caseSensitive: !keyword.caseSensitive);
});
```

- [ ] **Step 5: Wire real counter boundaries and display mode into SearchPanel**

Construct `SearchPanel` using:

```dart
SearchPanel(
  keywords: _keywords,
  controller: _keywordController,
  activeMatchIndex: _activeMatchIndex,
  matchCount: _matches.length,
  displayMode: _displayMode,
  onSubmitted: (value) {
    _addKeyword(value);
    _keywordController.clear();
  },
  onRemoveKeyword: _removeKeyword,
  onToggleKeywordMode: _toggleKeywordMode,
  onToggleMatchCase: _toggleMatchCase,
  onPreviousMatch: _activeMatchIndex > 0
      ? () => _selectMatch(_activeMatchIndex - 1)
      : null,
  onNextMatch: _activeMatchIndex + 1 < _matches.length
      ? () => _selectMatch(_activeMatchIndex + 1)
      : null,
  onDisplayModeChanged: _setDisplayMode,
  onClearSearch: _keywordController.clear,
),
```

Implement navigation without wrapping:

```dart
void _selectMatch(int index) {
  setState(() => _activeMatchIndex = index);
  _scrollToActiveMatch();
}

void _setDisplayMode(SearchDisplayMode mode) {
  setState(() => _displayMode = mode);
  _scrollToActiveMatch();
}
```

- [ ] **Step 6: Make LogTable source-index aware**

Extend `LogTable` with:

```dart
final List<int> visibleEntryIndexes;
final Map<int, List<SearchRange>> matchRangesByEntryIndex;
final int? currentSearchEntryIndex;
final ScrollController verticalController;
final Map<int, GlobalKey> rowKeys;
```

Use source indexes inside `ListView.builder`:

```dart
controller: verticalController,
itemCount: visibleEntryIndexes.length,
itemBuilder: (context, visibleIndex) {
  final sourceIndex = visibleEntryIndexes[visibleIndex];
  return KeyedSubtree(
    key: rowKeys[sourceIndex],
    child: _LogTableRow(
      entry: entries[sourceIndex],
      columns: columns,
      payloadWidth: payloadWidth,
      isActive: sourceIndex == activeIndex,
      isCurrentSearchMatch: sourceIndex == currentSearchEntryIndex,
      matchRanges: matchRangesByEntryIndex[sourceIndex] ?? const [],
      onTap: () => onRowTap(sourceIndex),
    ),
  );
},
```

Add `isCurrentSearchMatch` and `matchRanges` to `_LogTableRow`. Pass `isCurrentSearchMatch` to both `LogRowShell` and `LogPayloadCell`, and pass `matchRanges` to `LogPayloadCell`.

- [ ] **Step 7: Build visible rows and the no-results state in LogViewerPage**

At the start of `build`, derive:

```dart
final matchRangesByEntryIndex = {
  for (final match in _matches) match.entryIndex: match.ranges,
};
final visibleEntryIndexes = _displayMode == SearchDisplayMode.matchesOnly
    ? _matches.map((match) => match.entryIndex).toList(growable: false)
    : List<int>.generate(sampleLogs.length, (index) => index);
final currentSearchEntryIndex = _matches.isEmpty
    ? null
    : _matches[_activeMatchIndex].entryIndex;
```

Replace the table area with an empty-state branch:

```dart
Expanded(
  child: visibleEntryIndexes.isEmpty &&
          _displayMode == SearchDisplayMode.matchesOnly
      ? const Center(
          child: Text(
            'No logs match the current search',
            key: Key('search_empty_state'),
          ),
        )
      : LogTable(
          entries: sampleLogs,
          visibleEntryIndexes: visibleEntryIndexes,
          matchRangesByEntryIndex: matchRangesByEntryIndex,
          currentSearchEntryIndex: currentSearchEntryIndex,
          verticalController: _logScrollController,
          rowKeys: _rowKeys,
          filters: _filters,
          activeIndex: _activeLogIndex,
          onRowTap: (index) => setState(() => _activeLogIndex = index),
        ),
),
```

- [ ] **Step 8: Scroll the active search row into view**

Add a two-phase scroll so an off-screen builder row is first brought near the viewport and then aligned precisely:

```dart
void _scrollToActiveMatch() {
  if (_matches.isEmpty) return;
  final sourceIndex = _matches[_activeMatchIndex].entryIndex;
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    if (!mounted) return;
    var rowContext = _rowKeys[sourceIndex]?.currentContext;
    if (rowContext == null && _logScrollController.hasClients) {
      final visibleIndexes = _displayMode == SearchDisplayMode.matchesOnly
          ? _matches.map((match) => match.entryIndex).toList(growable: false)
          : List<int>.generate(sampleLogs.length, (index) => index);
      final visibleIndex = visibleIndexes.indexOf(sourceIndex);
      final fraction = visibleIndexes.length <= 1
          ? 0.0
          : visibleIndex / (visibleIndexes.length - 1);
      await _logScrollController.animateTo(
        _logScrollController.position.maxScrollExtent * fraction,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
      );
      if (!mounted) return;
      rowContext = _rowKeys[sourceIndex]?.currentContext;
    }
    if (rowContext != null) {
      await Scrollable.ensureVisible(
        rowContext,
        duration: const Duration(milliseconds: 150),
        alignment: 0.5,
      );
    }
  });
}
```

- [ ] **Step 9: Add behavior tests for case mode, mixed modes, reset, and boundaries**

Append these tests to `test/widget_test.dart`:

```dart
testWidgets('match case is evaluated per submitted keyword', (tester) async {
  await tester.pumpWidget(const MyApp());
  await tester.enterText(find.byKey(const Key('keyword_input')), 'Timeout');
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
  expect(find.text('1/2'), findsOneWidget);
  await tester.tap(find.byKey(const Key('keyword_match_case_Timeout')));
  await tester.pumpAndSettle();
  expect(find.text('0/0'), findsOneWidget);
});

testWidgets('OR becomes optional when another keyword remains AND', (tester) async {
  await tester.pumpWidget(const MyApp());
  for (final keyword in ['timeout', 'database']) {
    await tester.enterText(find.byKey(const Key('keyword_input')), keyword);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
  }
  expect(find.text('1/1'), findsOneWidget);
  await tester.tap(find.byKey(const Key('keyword_logic_database')));
  await tester.pumpAndSettle();
  expect(find.text('1/2'), findsOneWidget);
});

testWidgets('removing the final keyword restores All logs', (tester) async {
  await tester.pumpWidget(const MyApp());
  await tester.enterText(find.byKey(const Key('keyword_input')), 'timeout');
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('search_mode_control')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Matches only').last);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('remove_timeout')));
  await tester.pumpAndSettle();
  expect(find.text('All logs'), findsOneWidget);
  expect(find.text('0/0'), findsOneWidget);
  expect(find.byKey(const Key('log_row_10_42_01')), findsOneWidget);
});

testWidgets('navigation buttons disable at the first and last match', (tester) async {
  await tester.pumpWidget(const MyApp());
  await tester.enterText(find.byKey(const Key('keyword_input')), 'timeout');
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
  expect(tester.widget<IconButton>(find.byKey(const Key('previous_match'))).onPressed, isNull);
  expect(tester.widget<IconButton>(find.byKey(const Key('next_match'))).onPressed, isNotNull);
  await tester.tap(find.byKey(const Key('next_match')));
  await tester.pumpAndSettle();
  expect(tester.widget<IconButton>(find.byKey(const Key('next_match'))).onPressed, isNull);
});
```

Update older chip tests to add their keyword through `keyword_input` before locating `remove_timeout`, `keyword_logic_timeout`, or `keyword_match_case_timeout`. Change the initial Aa expectation from five widgets to zero. Keep the existing close-button test and verify that it clears only unsubmitted input, not submitted keyword chips.

- [ ] **Step 10: Run focused integration tests and fix only search regressions**

Run:

```bash
rtk dart format lib/features/log_viewer/log_viewer_page.dart lib/features/log_viewer/widgets/log_table.dart test/widget_test.dart
rtk flutter test test/widget_test.dart --plain-name "submitted payload keyword produces dynamic row matches"
rtk flutter test test/widget_test.dart --plain-name "Matches only hides nonmatching rows"
rtk flutter test test/widget_test.dart --plain-name "next match moves the active search row without moving selection"
```

Expected: all three focused tests PASS and no asynchronous scrolling exception remains after `pumpAndSettle()`.

- [ ] **Step 11: Commit end-to-end integration**

```bash
rtk git add lib/features/log_viewer/log_viewer_page.dart lib/features/log_viewer/widgets/log_table.dart test/widget_test.dart
rtk git commit -m "feat: integrate DLT log search navigation"
```

---

### Task 5: Full verification and design conformance

**Files:**
- Verify: `lib/features/log_viewer/models/log_search.dart`
- Verify: `lib/features/log_viewer/services/log_search_engine.dart`
- Verify: `lib/features/log_viewer/log_viewer_page.dart`
- Verify: `lib/features/log_viewer/widgets/search_panel.dart`
- Verify: `lib/features/log_viewer/widgets/log_table.dart`
- Verify: `lib/features/log_viewer/widgets/log_row.dart`
- Verify: `test/log_search_engine_test.dart`
- Verify: `test/log_row_search_highlight_test.dart`
- Verify: `test/search_panel_test.dart`
- Verify: `test/widget_test.dart`

**Interfaces:**
- Consumes: completed Tasks 1–4.
- Produces: a formatted, analyzed, regression-tested implementation matching `docs/plans/2026-08-01-log-search-engine-design.md`.

- [ ] **Step 1: Scan for retired mock search state**

Run:

```bash
rtk rg -n "highlightedWord|_keywordLogic|_caseSensitiveKeywords|1/15|timeout_highlight" lib test
```

Expected: no matches. If a match remains, remove that retired field, hard-coded counter, parallel state, or obsolete test assertion before continuing.

- [ ] **Step 2: Format every changed Dart file**

Run:

```bash
rtk dart format lib/features/log_viewer/models/log_search.dart lib/features/log_viewer/services/log_search_engine.dart lib/features/log_viewer/log_viewer_page.dart lib/features/log_viewer/widgets/search_panel.dart lib/features/log_viewer/widgets/log_table.dart lib/features/log_viewer/widgets/log_row.dart lib/models/log_entry.dart lib/data/sample_logs.dart test/log_search_engine_test.dart test/log_row_search_highlight_test.dart test/search_panel_test.dart test/widget_test.dart
```

Expected: formatter exits successfully.

- [ ] **Step 3: Run static analysis**

Run:

```bash
rtk flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 4: Run the complete test suite**

Run:

```bash
rtk flutter test
```

Expected: every unit and widget test PASS.

- [ ] **Step 5: Review the final diff against the approved design**

Run:

```bash
rtk git diff --check
rtk git status --short
rtk git diff --stat HEAD~4..HEAD
```

Expected: no whitespace errors; only the planned search files and any pre-existing unrelated working-tree files are listed. Confirm manually that the implementation begins with zero keywords, searches payload only, applies the agreed AND/OR semantics, counts rows, keeps All logs as default, and preserves manual selection separately from search navigation.

- [ ] **Step 6: Commit verification-only adjustments when needed**

If Steps 1–5 required a source or test correction, commit only those planned search files:

```bash
rtk git add lib/features/log_viewer lib/models/log_entry.dart lib/data/sample_logs.dart test/log_search_engine_test.dart test/log_row_search_highlight_test.dart test/search_panel_test.dart test/widget_test.dart
rtk git commit -m "test: verify DLT log search behavior"
```

If no correction was required, do not create an empty commit.
