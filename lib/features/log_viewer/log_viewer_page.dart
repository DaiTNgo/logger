import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:logger/data/sample_logs.dart';
import 'package:logger/features/log_viewer/models/dlt_filter.dart';
import 'package:logger/features/log_viewer/models/log_search.dart';
import 'package:logger/features/log_viewer/services/log_search_engine.dart';
import 'package:logger/features/log_viewer/widgets/bottom_navigation.dart';
import 'package:logger/features/log_viewer/widgets/filter_strip.dart';
import 'package:logger/features/log_viewer/widgets/log_table.dart';
import 'package:logger/features/log_viewer/widgets/log_viewer_header.dart';
import 'package:logger/features/log_viewer/widgets/search_panel.dart';

class LogViewerPage extends StatefulWidget {
  const LogViewerPage({super.key});

  @override
  State<LogViewerPage> createState() => _LogViewerPageState();
}

class _LogViewerPageState extends State<LogViewerPage> {
  final _searchEngine = const LogSearchEngine();
  final _keywords = <SearchKeyword>[];
  final _keywordController = TextEditingController();
  final _logScrollController = ScrollController();
  final _rowKeys = <int, GlobalKey>{
    for (var index = 0; index < sampleLogs.length; index++) index: GlobalKey(),
  };
  final _filters = <DltFilter>[
    const DltFilter(fieldId: 'ecu_id', values: ['ECU_MAIN']),
    const DltFilter(fieldId: 'apid', values: ['TELE']),
    const DltFilter(fieldId: 'ctid', values: ['NetworkComm']),
    const DltFilter(fieldId: 'log_level', values: ['Error', 'Fatal']),
    const DltFilter(fieldId: 'message_type', values: ['Log']),
  ];
  var _matches = <LogSearchMatch>[];
  var _activeMatchIndex = 0;
  var _displayMode = SearchDisplayMode.allLogs;
  var _activeDestination = 0;
  var _activeLogIndex = 5;

  @override
  void dispose() {
    _keywordController.dispose();
    _logScrollController.dispose();
    super.dispose();
  }

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
    if (_matches.isEmpty) return;
    final sourceIndex = _matches[_activeMatchIndex].entryIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      var rowContext = _rowKeys[sourceIndex]?.currentContext;
      final needsPreciseScroll =
          rowContext == null || !_isRowVisible(rowContext);
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
      if (rowContext != null && rowContext.mounted && needsPreciseScroll) {
        await Scrollable.ensureVisible(
          rowContext,
          duration: const Duration(milliseconds: 150),
          alignment: 0.5,
        );
      }
    });
  }

  bool _isRowVisible(BuildContext context) {
    if (!_logScrollController.hasClients) return false;
    final renderObject = context.findRenderObject();
    if (renderObject == null || !renderObject.attached) return false;
    final viewport = RenderAbstractViewport.of(renderObject);
    final leadingOffset = viewport.getOffsetToReveal(renderObject, 0).offset;
    final trailingOffset = viewport.getOffsetToReveal(renderObject, 1).offset;
    final currentOffset = _logScrollController.offset;
    return trailingOffset <= currentOffset && currentOffset <= leadingOffset;
  }

  void _removeFilter(String fieldId) => setState(
    () => _filters.removeWhere((filter) => filter.fieldId == fieldId),
  );

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
        : List<int>.generate(sampleLogs.length, (index) => index);
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
                      entries: sampleLogs,
                      visibleEntryIndexes: visibleEntryIndexes,
                      matchRangesByEntryIndex: matchRangesByEntryIndex,
                      currentSearchEntryIndex: currentSearchEntryIndex,
                      verticalController: _logScrollController,
                      rowKeys: _rowKeys,
                      filters: _filters,
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
