import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:logger/models/log_entry.dart';
import 'package:logger/ui/app_colors.dart';

class LogRow extends StatelessWidget {
  const LogRow({
    super.key,
    required this.entry,
    required this.isActive,
    required this.onTap,
  });
  final LogEntry entry;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isWarning = entry.level == LogLevel.warning;
    final isError = entry.level == LogLevel.error;
    final levelLabel = switch (entry.level) {
      LogLevel.info => 'INFO',
      LogLevel.warning => 'WARN',
      LogLevel.error => 'ERR',
    };
    final levelColor = switch (entry.level) {
      LogLevel.info => AppColors.success,
      LogLevel.warning => AppColors.warning,
      LogLevel.error => AppColors.error,
    };
    final background = isActive
        ? const Color(0x33D0E2FF)
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
                color: isActive ? AppColors.primary : AppColors.border,
              ),
              left: isActive
                  ? const BorderSide(color: AppColors.primary, width: 4)
                  : BorderSide.none,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: KeyedSubtree(
            key: isActive
                ? Key('active_log_row_${entry.time.replaceAll(':', '_')}')
                : null,
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
                    levelLabel,
                    style: GoogleFonts.ibmPlexMono(
                      color: levelColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _LogMessage(entry: entry, isActive: isActive),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LogMessage extends StatelessWidget {
  const _LogMessage({required this.entry, required this.isActive});
  final LogEntry entry;
  final bool isActive;
  @override
  Widget build(BuildContext context) {
    final word = entry.highlightedWord;
    final baseStyle = GoogleFonts.ibmPlexMono(
      color: AppColors.text,
      fontSize: 12,
    );
    if (word == null) return Text(entry.message, style: baseStyle);
    final matchIndex = entry.message.indexOf(word);
    if (matchIndex == -1) return Text(entry.message, style: baseStyle);
    return Text.rich(
      TextSpan(
        style: baseStyle,
        children: [
          TextSpan(text: entry.message.substring(0, matchIndex)),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: Container(
              key: Key('timeout_highlight_${entry.time.replaceAll(':', '_')}'),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: isActive ? AppColors.primary : const Color(0x66D0E2FF),
                border: isActive
                    ? null
                    : Border.all(color: const Color(0x4D0F62FE)),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Text(
                word,
                style: baseStyle.copyWith(
                  color: isActive ? AppColors.surface : AppColors.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          TextSpan(text: entry.message.substring(matchIndex + word.length)),
        ],
      ),
    );
  }
}
