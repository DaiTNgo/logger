import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/features/log_viewer/log_viewer_page.dart';
import 'package:logger/features/log_viewer/widgets/log_table.dart';
import 'package:logger/models/log_entry.dart';

class _EntriesHarness extends StatefulWidget {
  const _EntriesHarness({super.key, required this.entries});

  final List<LogEntry> entries;

  @override
  State<_EntriesHarness> createState() => _EntriesHarnessState();
}

class _EntriesHarnessState extends State<_EntriesHarness> {
  late List<LogEntry> _entries = widget.entries;

  void replaceEntries(List<LogEntry> entries) {
    setState(() => _entries = entries);
  }

  @override
  Widget build(BuildContext context) => LogViewerPage(entries: _entries);
}

LogEntry _entry(String time, String message) =>
    LogEntry(time: time, level: LogLevel.info, message: message);

Future<void> _submitKeyword(WidgetTester tester, String keyword) async {
  await tester.enterText(find.byKey(const Key('keyword_input')), keyword);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
}

Future<void> _showMatchesOnly(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('search_mode_control')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Matches only').last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('short initial entries clamp the default selection', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LogViewerPage(
          entries: [
            _entry('11:00:00', 'first row'),
            _entry('11:00:01', 'last row'),
          ],
        ),
      ),
    );

    expect(find.byKey(const Key('active_log_row_11_00_01')), findsOneWidget);
    expect(tester.widget<LogTable>(find.byType(LogTable)).activeIndex, 1);
  });

  testWidgets('empty initial entries have no selection', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: LogViewerPage(entries: [])),
    );

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('active_log_row')), findsNothing);
    expect(tester.widget<LogTable>(find.byType(LogTable)).activeIndex, isNull);
  });

  testWidgets('empty to nonempty replacement preserves no selection', (
    tester,
  ) async {
    final harnessKey = GlobalKey<_EntriesHarnessState>();
    await tester.pumpWidget(
      MaterialApp(
        home: _EntriesHarness(key: harnessKey, entries: const []),
      ),
    );

    harnessKey.currentState!.replaceEntries([
      _entry('11:00:00', 'first new row'),
      _entry('11:00:01', 'last new row'),
    ]);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('active_log_row')), findsNothing);
    expect(tester.widget<LogTable>(find.byType(LogTable)).activeIndex, isNull);
  });

  testWidgets(
    'entry replacement recomputes matches and clamps the active result',
    (tester) async {
      final harnessKey = GlobalKey<_EntriesHarnessState>();
      final initialEntries = [
        _entry('12:00:00', 'prefix far from the needle'),
        _entry('12:00:01', 'not a match'),
        _entry('12:00:02', 'another not-match'),
        _entry('12:00:03', 'prefix far from the needle again'),
        _entry('12:00:04', 'still not a match'),
        _entry('12:00:05', 'prefix far from the needle last'),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: _EntriesHarness(key: harnessKey, entries: initialEntries),
        ),
      );
      await _submitKeyword(tester, 'needle');
      await tester.tap(find.byKey(const Key('next_match')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('next_match')));
      await tester.pumpAndSettle();
      expect(find.text('3/3'), findsOneWidget);

      harnessKey.currentState!.replaceEntries([
        _entry('13:00:00', 'needle'),
        _entry('13:00:01', 'x needle y'),
      ]);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('2/2'), findsOneWidget);
      expect(
        find.byKey(const Key('current_search_match_row_13_00_01')),
        findsOneWidget,
      );
      for (final time in ['13_00_00', '13_00_01']) {
        final richText = tester.widget<RichText>(
          find.byKey(Key('payload_search_highlights_$time')),
        );
        final spans = (richText.text as TextSpan).children!.cast<TextSpan>();
        expect(
          spans
              .where((span) => span.style?.backgroundColor != null)
              .map((span) => span.text),
          ['needle'],
        );
      }
    },
  );

  testWidgets(
    'longer entry replacement navigates to a newly keyed distant match',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 500));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final harnessKey = GlobalKey<_EntriesHarnessState>();
      await tester.pumpWidget(
        MaterialApp(
          home: _EntriesHarness(
            key: harnessKey,
            entries: [
              _entry('12:00:00', 'needle'),
              _entry('12:00:01', 'plain row'),
            ],
          ),
        ),
      );
      await _submitKeyword(tester, 'needle');

      final longerEntries = List<LogEntry>.generate(30, (index) {
        final marker = index == 0 || index == 20 ? ' needle' : '';
        final isTall = index > 0 && index < 12;
        return _entry(
          '13:00:${index.toString().padLeft(2, '0')}',
          '${isTall ? List.filled(90, 'uneven payload ').join() : 'row'}$marker',
        );
      });
      harnessKey.currentState!.replaceEntries(longerEntries);
      await tester.pumpAndSettle();
      expect(find.text('1/2'), findsOneWidget);

      await tester.tap(find.byKey(const Key('next_match')));
      await tester.pumpAndSettle();

      final activeRow = find.byKey(
        const Key('current_search_match_row_13_00_20'),
      );
      final verticalScrollable = tester
          .stateList<ScrollableState>(
            find.descendant(
              of: find.byType(LogTable),
              matching: find.byType(Scrollable),
            ),
          )
          .singleWhere((state) => state.position.axis == Axis.vertical);
      final viewport = tester.getRect(find.byWidget(verticalScrollable.widget));
      final rowBounds = tester.getRect(activeRow);
      expect(rowBounds.top, greaterThanOrEqualTo(viewport.top));
      expect(rowBounds.bottom, lessThanOrEqualTo(viewport.bottom));
    },
  );

  testWidgets('entry replacement supersedes an in-flight distant search seek', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 500));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final harnessKey = GlobalKey<_EntriesHarnessState>();
    final initialEntries = List<LogEntry>.generate(50, (index) {
      final isMatch = index == 0 || index == 40;
      return _entry(
        '12:00:${index.toString().padLeft(2, '0')}',
        isMatch ? 'row needle' : List.filled(40, 'initial payload ').join(),
      );
    });
    await tester.pumpWidget(
      MaterialApp(
        home: _EntriesHarness(key: harnessKey, entries: initialEntries),
      ),
    );
    await _submitKeyword(tester, 'needle');

    final verticalScrollable = tester
        .stateList<ScrollableState>(
          find.descendant(
            of: find.byType(LogTable),
            matching: find.byType(Scrollable),
          ),
        )
        .singleWhere((state) => state.position.axis == Axis.vertical);
    await tester.tap(find.byKey(const Key('next_match')));
    await tester.pump(const Duration(milliseconds: 20));
    expect(verticalScrollable.position.pixels, greaterThan(0));
    harnessKey.currentState!.replaceEntries(
      List<LogEntry>.generate(
        30,
        (index) => _entry(
          '13:00:${index.toString().padLeft(2, '0')}',
          index == 0
              ? 'row needle'
              : List.filled(40, 'replacement payload ').join(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1/1'), findsOneWidget);
    final activeRow = find.byKey(
      const Key('current_search_match_row_13_00_00'),
    );
    final viewport = tester.getRect(find.byWidget(verticalScrollable.widget));
    final rowBounds = tester.getRect(activeRow);
    expect(rowBounds.top, greaterThanOrEqualTo(viewport.top));
    expect(rowBounds.bottom, lessThanOrEqualTo(viewport.bottom));
    expect(verticalScrollable.position.pixels, closeTo(0, 0.1));
  });

  testWidgets(
    'entry replacement retains keyword logic and case options for recompute',
    (tester) async {
      final harnessKey = GlobalKey<_EntriesHarnessState>();
      await tester.pumpWidget(
        MaterialApp(
          home: _EntriesHarness(
            key: harnessKey,
            entries: [
              _entry('12:00:00', 'timeout ERROR'),
              _entry('12:00:01', 'timeout error'),
              _entry('12:00:02', 'database ERROR'),
            ],
          ),
        ),
      );
      await _submitKeyword(tester, 'timeout');
      await _submitKeyword(tester, 'ERROR');
      final timeoutLogic = find.byKey(const Key('keyword_logic_timeout'));
      await tester.ensureVisible(timeoutLogic);
      await tester.tap(timeoutLogic);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('keyword_match_case_ERROR')));
      await tester.pumpAndSettle();

      harnessKey.currentState!.replaceEntries([
        _entry('13:00:00', 'timeout error'),
        _entry('13:00:01', 'database ERROR'),
        _entry('13:00:02', 'timeout ERROR'),
      ]);
      await tester.pumpAndSettle();

      expect(
        find.descendant(of: timeoutLogic, matching: find.text('OR')),
        findsOneWidget,
      );
      expect(find.text('1/2'), findsOneWidget);
      expect(
        find.byKey(const Key('payload_search_highlights_13_00_00')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('current_search_match_row_13_00_01')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('payload_search_highlights_13_00_02')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'entry replacement preserves selection by identity then clamps its index',
    (tester) async {
      final harnessKey = GlobalKey<_EntriesHarnessState>();
      final selectedEntry = _entry('12:00:01', 'selected row');
      await tester.pumpWidget(
        MaterialApp(
          home: _EntriesHarness(
            key: harnessKey,
            entries: [
              _entry('12:00:00', 'first row'),
              selectedEntry,
              _entry('12:00:02', 'last row'),
            ],
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('log_row_12_00_01')));
      await tester.pump();

      harnessKey.currentState!.replaceEntries([
        _entry('13:00:00', 'new first row'),
        _entry('13:00:01', 'new second row'),
        selectedEntry,
      ]);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('active_log_row_12_00_01')), findsOneWidget);

      harnessKey.currentState!.replaceEntries([
        _entry('14:00:00', 'replacement first row'),
        _entry('14:00:01', 'replacement last row'),
      ]);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('active_log_row_14_00_01')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'empty entry replacement keeps Matches only in a safe 0/0 state',
    (tester) async {
      final harnessKey = GlobalKey<_EntriesHarnessState>();
      await tester.pumpWidget(
        MaterialApp(
          home: _EntriesHarness(
            key: harnessKey,
            entries: [
              _entry('12:00:00', 'needle'),
              _entry('12:00:01', 'plain row'),
            ],
          ),
        ),
      );
      await _submitKeyword(tester, 'needle');
      await _showMatchesOnly(tester);

      harnessKey.currentState!.replaceEntries(const []);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Matches only'), findsOneWidget);
      expect(find.text('0/0'), findsOneWidget);
      expect(find.byKey(const Key('search_empty_state')), findsOneWidget);
    },
  );
}
