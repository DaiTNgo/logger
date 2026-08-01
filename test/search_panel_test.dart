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

  testWidgets('empty search displays 0/0 and disables navigation', (
    tester,
  ) async {
    await tester.pumpWidget(panel());
    expect(find.text('0/0'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('previous_match')))
          .onPressed,
      isNull,
    );
    expect(
      tester.widget<IconButton>(find.byKey(const Key('next_match'))).onPressed,
      isNull,
    );
  });

  testWidgets('populated search displays row counter and keyword options', (
    tester,
  ) async {
    await tester.pumpWidget(
      panel(
        keywords: const [SearchKeyword(text: 'Timeout', caseSensitive: true)],
        activeMatchIndex: 1,
        matchCount: 3,
        onPrevious: () {},
        onNext: () {},
      ),
    );
    expect(find.text('2/3'), findsOneWidget);
    expect(find.text('AND'), findsOneWidget);
    expect(find.byKey(const Key('keyword_match_case_Timeout')), findsOneWidget);
  });

  testWidgets('mode menu emits Matches only', (tester) async {
    SearchDisplayMode? selected;
    await tester.pumpWidget(
      panel(
        keywords: const [SearchKeyword(text: 'timeout')],
        onModeChanged: (value) => selected = value,
      ),
    );
    await tester.tap(find.byKey(const Key('search_mode_control')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Matches only').last);
    expect(selected, SearchDisplayMode.matchesOnly);
  });
}
