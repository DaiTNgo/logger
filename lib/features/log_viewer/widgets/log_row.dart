import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:logger/features/log_viewer/models/log_search.dart';
import 'package:logger/models/log_entry.dart';
import 'package:logger/ui/app_colors.dart';

class LogRow extends StatelessWidget {
  const LogRow({
    super.key,
    required this.entry,
    required this.isActive,
    required this.onTap,
    this.isCurrentSearchMatch = false,
    this.matchRanges = const [],
  });
  final LogEntry entry;
  final bool isActive;
  final VoidCallback onTap;
  final bool isCurrentSearchMatch;
  final List<SearchRange> matchRanges;

  @override
  Widget build(BuildContext context) => LogRowShell(
    entry: entry,
    isActive: isActive,
    onTap: onTap,
    isCurrentSearchMatch: isCurrentSearchMatch,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 64,
          child: Text(
            entry.time,
            textAlign: TextAlign.right,
            style: GoogleFonts.ibmPlexMono(
              color: AppColors.secondaryText,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 40,
          child: Text(
            _levelLabel(entry.level),
            style: GoogleFonts.ibmPlexMono(
              color: _levelColor(entry.level),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: LogPayloadCell(
            entry: entry,
            isCurrentSearchMatch: isCurrentSearchMatch,
            matchRanges: matchRanges,
          ),
        ),
      ],
    ),
  );
}

class LogRowShell extends StatelessWidget {
  const LogRowShell({
    super.key,
    required this.entry,
    required this.isActive,
    required this.onTap,
    required this.child,
    this.isCurrentSearchMatch = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  });

  final LogEntry entry;
  final bool isActive;
  final VoidCallback onTap;
  final Widget child;
  final bool isCurrentSearchMatch;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final isWarning = entry.level == LogLevel.warning;
    final isError = entry.level == LogLevel.error;
    final background = isCurrentSearchMatch
        ? const Color(0x33D0E2FF)
        : isActive
        ? const Color(0x1AD0E2FF)
        : isWarning
        ? const Color(0x4DFCF4D6)
        : isError
        ? const Color(0x14DA1E28)
        : AppColors.surface;
    return Semantics(
      label: entry.message,
      excludeSemantics: true,
      child: InkWell(
        key: Key('log_row_${entry.time.replaceAll(':', '_')}'),
        onTap: onTap,
        child: Container(
          key: isActive ? const Key('active_log_row') : null,
          decoration: BoxDecoration(
            color: background,
            border: Border(
              bottom: BorderSide(
                color: isCurrentSearchMatch
                    ? AppColors.primary
                    : AppColors.border,
              ),
              left: BorderSide(
                color: isActive ? AppColors.primary : Colors.transparent,
                width: 4,
              ),
            ),
          ),
          padding: padding,
          child: KeyedSubtree(
            key: isCurrentSearchMatch
                ? Key(
                    'current_search_match_row_${entry.time.replaceAll(':', '_')}',
                  )
                : null,
            child: KeyedSubtree(
              key: isActive
                  ? Key('active_log_row_${entry.time.replaceAll(':', '_')}')
                  : null,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class LogPayloadCell extends StatelessWidget {
  const LogPayloadCell({
    super.key,
    required this.entry,
    this.isCurrentSearchMatch = false,
    this.matchRanges = const [],
  });

  final LogEntry entry;
  final bool isCurrentSearchMatch;
  final List<SearchRange> matchRanges;

  @override
  Widget build(BuildContext context) => _LogMessage(
    entry: entry,
    isCurrentSearchMatch: isCurrentSearchMatch,
    matchRanges: matchRanges,
  );
}

String _levelLabel(LogLevel level) => switch (level) {
  LogLevel.info => 'INFO',
  LogLevel.warning => 'WARN',
  LogLevel.error => 'ERR',
};

Color _levelColor(LogLevel level) => switch (level) {
  LogLevel.info => AppColors.success,
  LogLevel.warning => AppColors.warning,
  LogLevel.error => AppColors.error,
};

class _LogMessage extends StatelessWidget {
  const _LogMessage({
    required this.entry,
    required this.isCurrentSearchMatch,
    required this.matchRanges,
  });

  final LogEntry entry;
  final bool isCurrentSearchMatch;
  final List<SearchRange> matchRanges;

  @override
  Widget build(BuildContext context) {
    final baseStyle = GoogleFonts.ibmPlexMono(
      color: AppColors.text,
      fontSize: 12,
    );
    if (matchRanges.isEmpty) return Text(entry.message, style: baseStyle);
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final range in matchRanges) {
      if (cursor < range.start) {
        spans.add(TextSpan(text: entry.message.substring(cursor, range.start)));
      }
      spans.add(
        TextSpan(
          text: entry.message.substring(range.start, range.end),
          style: baseStyle.copyWith(
            backgroundColor: isCurrentSearchMatch
                ? AppColors.primary
                : const Color(0x66D0E2FF),
            color: isCurrentSearchMatch ? AppColors.surface : AppColors.text,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
      cursor = range.end;
    }
    if (cursor < entry.message.length) {
      spans.add(TextSpan(text: entry.message.substring(cursor)));
    }
    return RichText(
      key: Key('payload_search_highlights_${entry.time.replaceAll(':', '_')}'),
      text: TextSpan(style: baseStyle, children: spans),
    );
  }
}
