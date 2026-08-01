# Per-Keyword Match Case Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove global Search mode and let each keyword chip independently enable Match case.

**Architecture:** `LogViewerPage` stores a `Set<String>` of case-sensitive keywords alongside its existing keyword and logic state. `SearchPanel` receives that set and callback, while `_KeywordChip` renders a compact, keyed `text_format` action beside its AND/OR control.

**Tech Stack:** Flutter, Dart, Material 3, `flutter_test`.

## Global Constraints

- Do not add dependencies.
- Remove Search mode state, UI, callback, tooltip, and tests completely.
- Match case belongs to exactly one keyword chip; toggling `timeout` must not change `error`.
- Preserve keyword add/remove, AND/OR logic, responsiveness, colors, and existing widget keys.
- Show a `Match case for <keyword>` tooltip on each chip action and render the selected icon in `#0F62FE`.

---

### Task 1: Move match-case state into keyword chips

**Files:**
- Modify: `lib/features/log_viewer/log_viewer_page.dart`
- Modify: `lib/features/log_viewer/widgets/search_panel.dart`
- Modify: `test/widget_test.dart`

**Interfaces:**
- Produces: `SearchPanel.caseSensitiveKeywords: Set<String>` and `SearchPanel.onToggleMatchCase: ValueChanged<String>`.

- [ ] **Step 1: Write the failing widget test**

Replace the global mode test with this behavior:

```dart
await tester.tap(find.byKey(const Key('keyword_match_case_timeout')));
await tester.pump();
expect(find.byKey(const Key('search_mode_control')), findsNothing);
expect(tester.widget<Icon>(find.byKey(const Key('keyword_match_case_timeout'))).color, const Color(0xFF0F62FE));
expect(tester.widget<Icon>(find.byKey(const Key('keyword_match_case_error'))).color, const Color(0xFF525252));
expect(find.byTooltip('Match case for timeout'), findsOneWidget);
```

- [ ] **Step 2: Run the focused test to verify it fails**

Run: `flutter test test/widget_test.dart --plain-name "match case is configured per keyword"`

Expected: FAIL because the current global control still exists and chip controls are absent.

- [ ] **Step 3: Implement the minimum state and UI changes**

Add `final _caseSensitiveKeywords = <String>{};` to page state. Toggle membership in a new `_toggleMatchCase(String keyword)` method; remove a keyword from this set inside `_removeKeyword`. Remove `_searchMode`, every Search mode interface parameter, and the global Match case action. Pass the set/callback into each `_KeywordChip`, which renders a `Tooltip` containing an `IconButton` keyed `keyword_match_case_<keyword>`.

- [ ] **Step 4: Run final verification**

Run: `dart format lib test && flutter analyze && flutter test`

Expected: analyzer reports no issues and every widget test passes.

## Self-Review

- Spec coverage: removes Search mode and makes Match case per-keyword.
- Placeholder scan: none.
- Type consistency: state is `Set<String>` and callback is `ValueChanged<String>` throughout.
