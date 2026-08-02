import 'package:flutter/material.dart';
import 'package:logger/data/sample_logs.dart';
import 'package:logger/features/log_viewer/models/dlt_filter.dart';
import 'package:logger/features/log_viewer/models/log_search.dart';
import 'package:logger/features/log_viewer/services/log_search_engine.dart';
import 'package:logger/features/log_viewer/widgets/bottom_navigation.dart';
import 'package:logger/features/log_viewer/widgets/filter_strip.dart';
import 'package:logger/features/log_viewer/widgets/log_table.dart';
import 'package:logger/features/log_viewer/widgets/log_viewer_header.dart';
import 'package:logger/features/log_viewer/widgets/search_panel.dart';
import 'package:logger/models/log_entry.dart';

class LogViewerPage extends StatefulWidget {
  const LogViewerPage({super.key, this.entries = sampleLogs});

  final List<LogEntry> entries;

  @override
  State<LogViewerPage> createState() => _LogViewerPageState();
}

class _LogViewerPageState extends State<LogViewerPage> {
  final _searchEngine = const LogSearchEngine();
  final _keywords = <SearchKeyword>[];
  final _keywordController = TextEditingController();
  final _logScrollController = ScrollController();
  final _filters = <DltFilter>[
    const DltFilter(fieldId: 'ecu_id', values: ['ECU_MAIN']),
    const DltFilter(fieldId: 'apid', values: ['TELE']),
    const DltFilter(fieldId: 'ctid', values: ['NetworkComm']),
    const DltFilter(fieldId: 'log_level', values: ['Error', 'Fatal']),
    const DltFilter(fieldId: 'message_type', values: ['Log']),
  ];
  final _visibleColumnIds = <String>{
    'ecu_id',
    'apid',
    'ctid',
    'log_level',
    'message_type',
  };
  var _matches = <LogSearchMatch>[];
  var _activeMatchIndex = 0;
  var _displayMode = SearchDisplayMode.allLogs;
  var _scrollGeneration = 0;
  var _activeDestination = 0;
  int? _activeLogIndex;

  @override
  void initState() {
    super.initState();
    _activeLogIndex = widget.entries.isEmpty
        ? null
        : 5.clamp(0, widget.entries.length - 1);
  }

  @override
  void didUpdateWidget(covariant LogViewerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(widget.entries, oldWidget.entries)) return;

    final reconciliationGeneration = ++_scrollGeneration;
    _matches = _searchEngine.search(widget.entries, _keywords);
    _activeMatchIndex = _matches.isEmpty
        ? 0
        : _activeMatchIndex.clamp(0, _matches.length - 1);
    _activeLogIndex = _reconcileActiveLogIndex(
      oldEntries: oldWidget.entries,
      newEntries: widget.entries,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || reconciliationGeneration != _scrollGeneration) return;
      _scrollToActiveMatch();
    });
  }

  int? _reconcileActiveLogIndex({
    required List<LogEntry> oldEntries,
    required List<LogEntry> newEntries,
  }) {
    if (newEntries.isEmpty) return null;

    final oldIndex = _activeLogIndex;
    if (oldIndex == null) return null;
    if (oldIndex >= 0 && oldIndex < oldEntries.length) {
      final selectedEntry = oldEntries[oldIndex];
      final identityIndex = newEntries.indexWhere(
        (entry) => identical(entry, selectedEntry),
      );
      if (identityIndex != -1) return identityIndex;
    }

    return oldIndex.clamp(0, newEntries.length - 1);
  }

  @override
  void dispose() {
    _keywordController.dispose();
    _logScrollController.dispose();
    super.dispose();
  }

  void _mutateSearch(VoidCallback mutation) {
    setState(() {
      mutation();
      _matches = _searchEngine.search(widget.entries, _keywords);
      _activeMatchIndex = 0;
      if (_keywords.isEmpty) {
        _displayMode = SearchDisplayMode.allLogs;
      }
    });
    _scrollToActiveMatch();
  }

  void _addKeyword(String value) {
    final text = value.trim();
    if (text.isEmpty || _keywords.any((keyword) => keyword.text == text)) {
      return;
    }
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

  void _selectMatch(int index) {
    setState(() => _activeMatchIndex = index);
    _scrollToActiveMatch();
  }

  void _setDisplayMode(SearchDisplayMode mode) {
    setState(() => _displayMode = mode);
    _scrollToActiveMatch();
  }

  void _scrollToActiveMatch() {
    final generation = ++_scrollGeneration;
    if (_matches.isEmpty) return;
    final sourceIndex = _matches[_activeMatchIndex].entryIndex;
    if (!_isCurrentScroll(generation, sourceIndex)) return;
    final visibleIndex = _displayMode == SearchDisplayMode.matchesOnly
        ? _matches.indexWhere((match) => match.entryIndex == sourceIndex)
        : sourceIndex;
    if (visibleIndex == -1) return;
    _scrollToVisibleIndex(visibleIndex);
  }

  bool _isCurrentScroll(int generation, int sourceIndex) =>
      mounted &&
      generation == _scrollGeneration &&
      _matches.isNotEmpty &&
      _activeMatchIndex < _matches.length &&
      _matches[_activeMatchIndex].entryIndex == sourceIndex;

  void _scrollToVisibleIndex(int visibleIndex) {
    if (!_logScrollController.hasClients) return;
    final position = _logScrollController.position;
    final target = (visibleIndex * logTableRowExtent)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    _logScrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
    );
  }

  void _removeFilter(String fieldId) => setState(
    () => _filters.removeWhere((filter) => filter.fieldId == fieldId),
  );

  void _toggleVisibleColumn(String fieldId) => setState(() {
    if (!_visibleColumnIds.add(fieldId)) {
      _visibleColumnIds.remove(fieldId);
    }
  });

  void _addOrFocusFilter(String fieldId) {
    if (_filters.any((filter) => filter.fieldId == fieldId)) return;
    setState(() => _filters.add(DltFilter(fieldId: fieldId)));
  }

  void _updateFilter(DltFilter updatedFilter) {
    setState(() {
      final index = _filters.indexWhere(
        (filter) => filter.fieldId == updatedFilter.fieldId,
      );
      if (index == -1) {
        _filters.add(updatedFilter);
      } else {
        _filters[index] = updatedFilter;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final matchRangesByEntryIndex = {
      for (final match in _matches) match.entryIndex: match.ranges,
    };
    final visibleEntryIndexes = _displayMode == SearchDisplayMode.matchesOnly
        ? _matches.map((match) => match.entryIndex).toList(growable: false)
        : List<int>.generate(widget.entries.length, (index) => index);
    final currentSearchEntryIndex = _matches.isEmpty
        ? null
        : _matches[_activeMatchIndex].entryIndex;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const LogViewerHeader(),
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
            FilterStrip(
              filters: _filters,
              visibleColumnIds: _visibleColumnIds,
              onToggleVisibleColumn: _toggleVisibleColumn,
              onSelectField: _addOrFocusFilter,
              onUpdateFilter: _updateFilter,
              onRemoveFilter: _removeFilter,
              onClearFilters: () => setState(_filters.clear),
            ),
            Expanded(
              child:
                  visibleEntryIndexes.isEmpty &&
                      _displayMode == SearchDisplayMode.matchesOnly
                  ? const Center(
                      child: Text(
                        'No logs match the current search',
                        key: Key('search_empty_state'),
                      ),
                    )
                  : LogTable(
                      entries: widget.entries,
                      visibleEntryIndexes: visibleEntryIndexes,
                      matchRangesByEntryIndex: matchRangesByEntryIndex,
                      currentSearchEntryIndex: currentSearchEntryIndex,
                      verticalController: _logScrollController,
                      visibleColumnIds: _visibleColumnIds,
                      activeIndex: _activeLogIndex,
                      onRowTap: (index) =>
                          setState(() => _activeLogIndex = index),
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigation(
        activeDestination: _activeDestination,
        onSelect: (value) => setState(() => _activeDestination = value),
      ),
    );
  }
}
