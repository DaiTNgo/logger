import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:logger/features/log_viewer/models/dlt_filter.dart';
import 'package:logger/features/log_viewer/widgets/log_row.dart';
import 'package:logger/models/log_entry.dart';
import 'package:logger/ui/app_colors.dart';

class LogTable extends StatelessWidget {
  const LogTable({
    super.key,
    required this.entries,
    required this.filters,
    required this.activeIndex,
    required this.onRowTap,
  });

  final List<LogEntry> entries;
  final List<DltFilter> filters;
  final int activeIndex;
  final ValueChanged<int> onRowTap;

  @override
  Widget build(BuildContext context) {
    final columns = [
      const _LogColumn(label: 'Time', width: 72),
      for (final filter in filters)
        _LogColumn(
          label: definitionFor(filter.fieldId).label,
          fieldId: filter.fieldId,
          width: filter.fieldId == 'ctid' ? 128 : 96,
        ),
      const _LogColumn(label: 'Payload', width: 480, isPayload: true),
    ];
    final fixedWidth = columns
        .where((column) => !column.isPayload)
        .fold<double>(0, (width, column) => width + column.width);

    return LayoutBuilder(
      builder: (context, constraints) {
        final tableWidth = math.max(constraints.maxWidth, fixedWidth + 4 + 480);
        final payloadWidth = tableWidth - 4 - fixedWidth;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: tableWidth,
            child: Column(
              children: [
                _LogTableHeader(columns: columns, payloadWidth: payloadWidth),
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: entries.length,
                    itemBuilder: (context, index) => _LogTableRow(
                      entry: entries[index],
                      columns: columns,
                      payloadWidth: payloadWidth,
                      isActive: index == activeIndex,
                      onTap: () => onRowTap(index),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
              child: Text(
                column.label,
                key: Key('dlt_column_header_${column.label}'),
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.ibmPlexMono(
                  color: AppColors.secondaryText,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
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
    required this.onTap,
  });

  final LogEntry entry;
  final List<_LogColumn> columns;
  final double payloadWidth;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => LogRowShell(
    entry: entry,
    isActive: isActive,
    onTap: onTap,
    padding: EdgeInsets.zero,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final column in columns)
          _TableCell(
            width: column.isPayload ? payloadWidth : column.width,
            child: column.isPayload
                ? LogPayloadCell(entry: entry, isActive: isActive)
                : Text(
                    column.fieldId == null
                        ? entry.time
                        : entry.dltValues[column.fieldId] ?? '—',
                    overflow: TextOverflow.ellipsis,
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
  const _TableCell({required this.width, required this.child});

  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: child,
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
