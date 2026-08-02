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

  test('returns every repeated occurrence in one matched row', () {
    final matches = engine.search(
      const [LogEntry(time: '1', level: LogLevel.info, message: 'error error')],
      const [SearchKeyword(text: 'error')],
    );
    expect(matches.single.ranges, const [
      SearchRange(0, 5),
      SearchRange(6, 11),
    ]);
  });

  test('merges overlapping occurrences of one keyword', () {
    final matches = engine.search(
      const [LogEntry(time: '1', level: LogLevel.info, message: 'aaa')],
      const [SearchKeyword(text: 'aa')],
    );

    expect(matches.single.ranges, const [SearchRange(0, 3)]);
  });

  test('merges overlapping and adjacent keyword ranges', () {
    final matches = engine.search(
      const [LogEntry(time: '1', level: LogLevel.info, message: 'database')],
      const [
        SearchKeyword(text: 'data'),
        SearchKeyword(text: 'database', mode: SearchKeywordMode.or),
      ],
    );
    expect(matches.single.ranges, const [SearchRange(0, 8)]);
  });

  test('merges truly adjacent keyword ranges', () {
    final matches = engine.search(
      const [LogEntry(time: '1', level: LogLevel.info, message: 'database')],
      const [SearchKeyword(text: 'data'), SearchKeyword(text: 'base')],
    );

    expect(matches.single.ranges, const [SearchRange(0, 8)]);
  });

  test('treats regex characters as literal text', () {
    final matches = engine.search(
      const [LogEntry(time: '1', level: LogLevel.info, message: 'retry [1/3]')],
      const [SearchKeyword(text: '[1/3]')],
    );
    expect(matches.single.ranges, const [SearchRange(6, 11)]);
  });

  test('preserves source entry order', () {
    final matches = engine.search(logs.reversed.toList(), const [
      SearchKeyword(text: 'timeout', mode: SearchKeywordMode.or),
      SearchKeyword(text: 'database', mode: SearchKeywordMode.or),
    ]);
    expect(matches.map((match) => match.entryIndex), [1, 2, 3]);
  });
}
