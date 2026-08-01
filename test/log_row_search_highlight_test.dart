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
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LogPayloadCell(
            entry: entry,
            isCurrentSearchMatch: true,
            matchRanges: [SearchRange(0, 7), SearchRange(13, 18)],
          ),
        ),
      ),
    );

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
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LogRowShell(
            entry: entry,
            isActive: false,
            isCurrentSearchMatch: true,
            onTap: () {},
            child: const Text('row'),
          ),
        ),
      ),
    );
    expect(
      find.byKey(const Key('current_search_match_row_10_00_00')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('active_log_row')), findsNothing);
  });
}
