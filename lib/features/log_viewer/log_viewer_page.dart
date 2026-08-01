import 'package:flutter/material.dart';
import 'package:logger/data/sample_logs.dart';
import 'package:logger/features/log_viewer/models/dlt_filter.dart';
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
  final _keywords = <String>[
    'timeout',
    'error',
    'connection',
    'retry',
    'database',
  ];
  final _keywordLogic = <String, String>{};
  final _caseSensitiveKeywords = <String>{};
  final _filters = <DltFilter>[
    const DltFilter(fieldId: 'ecu_id', values: ['ECU_MAIN']),
    const DltFilter(fieldId: 'apid', values: ['TELE']),
    const DltFilter(fieldId: 'ctid', values: ['NetworkComm']),
    const DltFilter(fieldId: 'log_level', values: ['Error', 'Fatal']),
    const DltFilter(fieldId: 'message_type', values: ['Log']),
  ];
  final _keywordController = TextEditingController();
  var _activeMatch = 1;
  var _activeDestination = 0;
  var _activeLogIndex = 5;

  @override
  void dispose() {
    _keywordController.dispose();
    super.dispose();
  }

  void _addKeyword(String value) {
    final keyword = value.trim();
    if (keyword.isEmpty || _keywords.contains(keyword)) return;
    setState(() => _keywords.add(keyword));
  }

  void _removeKeyword(String keyword) {
    setState(() {
      _keywords.remove(keyword);
      _keywordLogic.remove(keyword);
      _caseSensitiveKeywords.remove(keyword);
    });
  }

  void _toggleKeywordLogic(String keyword) {
    setState(() {
      _keywordLogic[keyword] = (_keywordLogic[keyword] ?? 'AND') == 'AND'
          ? 'OR'
          : 'AND';
    });
  }

  void _toggleMatchCase(String keyword) {
    setState(() {
      if (!_caseSensitiveKeywords.add(keyword)) {
        _caseSensitiveKeywords.remove(keyword);
      }
    });
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

  void _setActiveMatch(int value) =>
      setState(() => _activeMatch = value.clamp(0, 14));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const LogViewerHeader(),
            SearchPanel(
              keywords: _keywords,
              keywordLogic: _keywordLogic,
              caseSensitiveKeywords: _caseSensitiveKeywords,
              controller: _keywordController,
              activeMatch: _activeMatch,
              onSubmitted: (value) {
                _addKeyword(value);
                _keywordController.clear();
              },
              onRemoveKeyword: _removeKeyword,
              onToggleKeywordLogic: _toggleKeywordLogic,
              onToggleMatchCase: _toggleMatchCase,
              onPreviousMatch: () => _setActiveMatch(_activeMatch - 1),
              onNextMatch: () => _setActiveMatch(_activeMatch + 1),
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
              child: LogTable(
                entries: sampleLogs,
                filters: _filters,
                activeIndex: _activeLogIndex,
                onRowTap: (index) => setState(() => _activeLogIndex = index),
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
