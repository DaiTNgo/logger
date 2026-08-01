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
