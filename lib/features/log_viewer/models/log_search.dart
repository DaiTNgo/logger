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

  SearchKeyword copyWith({SearchKeywordMode? mode, bool? caseSensitive}) =>
      SearchKeyword(
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
