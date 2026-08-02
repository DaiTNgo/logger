import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:logger/features/log_viewer/models/dlt_filter.dart';
import 'package:logger/features/log_viewer/models/log_search.dart';
import 'package:logger/features/log_viewer/widgets/log_row.dart';
import 'package:logger/models/log_entry.dart';
import 'package:logger/ui/app_colors.dart';

const logTableRowExtent = 28.0;
const _timeColumnWidth = 88.0;
const _dltColumnWidth = 112.0;
const _ctidColumnWidth = 128.0;
const _payloadColumnMinWidth = 480.0;
const _cellHorizontalPadding = 16.0;
const _payloadWidthBuffer = 4.0;

class LogTable extends StatefulWidget {
  const LogTable({
    super.key,
    required this.entries,
    required this.visibleEntryIndexes,
    required this.matchRangesByEntryIndex,
    required this.currentSearchEntryIndex,
    required this.verticalController,
    required this.visibleColumnIds,
    required this.activeIndex,
    required this.onRowTap,
  });

  final List<LogEntry> entries;
  final List<int> visibleEntryIndexes;
  final Map<int, List<SearchRange>> matchRangesByEntryIndex;
  final int? currentSearchEntryIndex;
  final ScrollController verticalController;
  final Set<String> visibleColumnIds;
  final int? activeIndex;
  final ValueChanged<int> onRowTap;

  static const debugUsesPerRecordGlobalKeys = false;

  @override
  State<LogTable> createState() => _LogTableState();
}

class _LogTableState extends State<LogTable> {
  List<LogEntry>? _scannedEntries;
  String _longestPayload = '';

  String _longestPayloadString() {
    if (!identical(_scannedEntries, widget.entries)) {
      _scannedEntries = widget.entries;
      var longest = '';
      for (final entry in widget.entries) {
        final message = entry.message;
        if (message.length > longest.length) longest = message;
      }
      _longestPayload = longest;
    }
    return _longestPayload;
  }

  double _payloadColumnWidth(BuildContext context) {
    final painter = TextPainter(
      text: TextSpan(
        text: _longestPayloadString(),
        style: GoogleFonts.ibmPlexMono(fontSize: 12),
      ),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    return math.max(
      _payloadColumnMinWidth,
      painter.width + _cellHorizontalPadding + _payloadWidthBuffer,
    );
  }

  @override
  Widget build(BuildContext context) {
    final columns = [
      const _LogColumn(label: 'Time', width: _timeColumnWidth),
      for (final definition in dltFilterDefinitions)
        if (widget.visibleColumnIds.contains(definition.id))
          _LogColumn(
            label: definition.label,
            fieldId: definition.id,
            width: definition.id == 'ctid' ? _ctidColumnWidth : _dltColumnWidth,
          ),
      const _LogColumn(
        label: 'Payload',
        width: _payloadColumnMinWidth,
        isPayload: true,
      ),
    ];
    final fixedWidth = columns
        .where((column) => !column.isPayload)
        .fold<double>(0, (width, column) => width + column.width);

    return MediaQuery.withNoTextScaling(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tableWidth = math.max(
            constraints.maxWidth,
            fixedWidth + 4 + _payloadColumnWidth(context),
          );
          final payloadWidth = tableWidth - 4 - fixedWidth;
          return SingleChildScrollView(
            key: const Key('log_table_horizontal_scroll'),
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: tableWidth,
              child: Column(
                children: [
                  _LogTableHeader(columns: columns, payloadWidth: payloadWidth),
                  Expanded(
                    child: ListView.builder(
                      key: const Key('log_table_vertical_list'),
                      controller: widget.verticalController,
                      padding: EdgeInsets.zero,
                      itemExtent: logTableRowExtent,
                      itemCount: widget.visibleEntryIndexes.length,
                      itemBuilder: (context, visibleIndex) {
                        final sourceIndex =
                            widget.visibleEntryIndexes[visibleIndex];
                        return _LogTableRow(
                          entry: widget.entries[sourceIndex],
                          columns: columns,
                          payloadWidth: payloadWidth,
                          isActive: sourceIndex == widget.activeIndex,
                          isCurrentSearchMatch:
                              sourceIndex == widget.currentSearchEntryIndex,
                          matchRanges:
                              widget.matchRangesByEntryIndex[sourceIndex] ??
                              const [],
                          onTap: () => widget.onRowTap(sourceIndex),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LogTableHeader extends StatelessWidget {
  const _LogTableHeader({required this.columns, required this.payloadWidth});

  final List<_LogColumn> columns;
  final double payloadWidth;

  @override
  Widget build(BuildContext context) => Container(
    height: 36,
    decoration: const BoxDecoration(
      color: AppColors.surfaceContainer,
      border: Border(bottom: BorderSide(color: AppColors.border)),
    ),
    child: Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: [
          for (final column in columns)
            _TableCell(
              width: column.isPayload ? payloadWidth : column.width,
              scrollable: false,
              child: Tooltip(
                message: column.label,
                child: Text(
                  column.label,
                  key: Key('dlt_column_header_${column.label}'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.ibmPlexMono(
                    color: AppColors.secondaryText,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class _LogTableRow extends StatelessWidget {
  const _LogTableRow({
    required this.entry,
    required this.columns,
    required this.payloadWidth,
    required this.isActive,
    required this.isCurrentSearchMatch,
    required this.matchRanges,
    required this.onTap,
  });

  final LogEntry entry;
  final List<_LogColumn> columns;
  final double payloadWidth;
  final bool isActive;
  final bool isCurrentSearchMatch;
  final List<SearchRange> matchRanges;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => LogRowShell(
    entry: entry,
    isActive: isActive,
    isCurrentSearchMatch: isCurrentSearchMatch,
    onTap: onTap,
    padding: EdgeInsets.zero,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final column in columns)
          _TableCell(
            width: column.isPayload ? payloadWidth : column.width,
            scrollable: !column.isPayload,
            child: column.isPayload
                ? LogPayloadCell(
                    entry: entry,
                    isCurrentSearchMatch: isCurrentSearchMatch,
                    matchRanges: matchRanges,
                  )
                : Text(
                    column.fieldId == null
                        ? entry.time
                        : entry.dltValues[column.fieldId] ?? '—',
                    softWrap: false,
                    style: GoogleFonts.ibmPlexMono(
                      color: AppColors.secondaryText,
                      fontSize: 12,
                    ),
                  ),
          ),
      ],
    ),
  );
}

class _TableCell extends StatelessWidget {
  const _TableCell({
    required this.width,
    required this.child,
    this.scrollable = true,
  });

  final double width;
  final Widget child;
  final bool scrollable;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: scrollable
          ? SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: child,
            )
          : child,
    ),
  );
}

class _LogColumn {
  const _LogColumn({
    required this.label,
    required this.width,
    this.fieldId,
    this.isPayload = false,
  });

  final String label;
  final String? fieldId;
  final double width;
  final bool isPayload;
}
