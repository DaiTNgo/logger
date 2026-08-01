import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:logger/features/log_viewer/models/log_search.dart';
import 'package:logger/ui/app_colors.dart';

class SearchPanel extends StatelessWidget {
  const SearchPanel({
    super.key,
    required this.keywords,
    required this.controller,
    required this.activeMatchIndex,
    required this.matchCount,
    required this.displayMode,
    required this.onSubmitted,
    required this.onRemoveKeyword,
    required this.onToggleKeywordMode,
    required this.onToggleMatchCase,
    required this.onPreviousMatch,
    required this.onNextMatch,
    required this.onDisplayModeChanged,
    required this.onClearSearch,
  });

  final List<SearchKeyword> keywords;
  final TextEditingController controller;
  final int activeMatchIndex;
  final int matchCount;
  final SearchDisplayMode displayMode;
  final ValueChanged<String> onSubmitted;
  final ValueChanged<String> onRemoveKeyword;
  final ValueChanged<String> onToggleKeywordMode;
  final ValueChanged<String> onToggleMatchCase;
  final VoidCallback? onPreviousMatch;
  final VoidCallback? onNextMatch;
  final ValueChanged<SearchDisplayMode> onDisplayModeChanged;
  final VoidCallback onClearSearch;

  @override
  Widget build(BuildContext context) {
    final actions = _SearchActions(
      keywords: keywords,
      activeMatchIndex: activeMatchIndex,
      matchCount: matchCount,
      displayMode: displayMode,
      onPreviousMatch: onPreviousMatch,
      onNextMatch: onNextMatch,
      onDisplayModeChanged: onDisplayModeChanged,
      onClearSearch: onClearSearch,
    ).children;
    return Container(
      color: AppColors.surfaceContainer,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        height: 40,
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(bottom: BorderSide(color: AppColors.outline)),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final tokens = _buildTokens(constraints.maxWidth < 500 ? 140 : 200);
            const leading = Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Icon(Icons.search, size: 20, color: AppColors.outline),
            );
            if (constraints.maxWidth < 500) {
              return SingleChildScrollView(
                key: const Key('narrow_search_controls_scroll'),
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    leading,
                    ...tokens,
                    const VerticalDivider(width: 1, color: AppColors.border),
                    ...actions,
                  ],
                ),
              );
            }
            return Row(
              children: [
                leading,
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: tokens),
                  ),
                ),
                const VerticalDivider(width: 1, color: AppColors.border),
                ...actions,
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildTokens(double inputWidth) => [
    ...keywords.map(
      (keyword) => _KeywordChip(
        value: keyword.text,
        logic: keyword.mode == SearchKeywordMode.and ? 'AND' : 'OR',
        matchCase: keyword.caseSensitive,
        onToggleLogic: () => onToggleKeywordMode(keyword.text),
        onToggleMatchCase: () => onToggleMatchCase(keyword.text),
        onRemove: () => onRemoveKeyword(keyword.text),
      ),
    ),
    SizedBox(
      width: inputWidth,
      child: TextField(
        key: const Key('keyword_input'),
        controller: controller,
        textInputAction: TextInputAction.done,
        onSubmitted: onSubmitted,
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          hintText: 'Add keyword...',
          hintStyle: GoogleFonts.ibmPlexSans(
            color: AppColors.outline,
            fontSize: 14,
          ),
        ),
        style: GoogleFonts.ibmPlexSans(color: AppColors.text, fontSize: 14),
      ),
    ),
  ];
}

class _SearchActions {
  const _SearchActions({
    required this.keywords,
    required this.activeMatchIndex,
    required this.matchCount,
    required this.displayMode,
    required this.onPreviousMatch,
    required this.onNextMatch,
    required this.onDisplayModeChanged,
    required this.onClearSearch,
  });
  final List<SearchKeyword> keywords;
  final int activeMatchIndex;
  final int matchCount;
  final SearchDisplayMode displayMode;
  final VoidCallback? onPreviousMatch;
  final VoidCallback? onNextMatch;
  final ValueChanged<SearchDisplayMode> onDisplayModeChanged;
  final VoidCallback onClearSearch;

  List<Widget> get children {
    final counter = matchCount == 0
        ? '0/0'
        : '${activeMatchIndex + 1}/$matchCount';
    return [
      const SizedBox(width: 8),
      PopupMenuButton<SearchDisplayMode>(
        key: const Key('search_mode_control'),
        enabled: keywords.isNotEmpty,
        initialValue: displayMode,
        onSelected: onDisplayModeChanged,
        itemBuilder: (context) => const [
          PopupMenuItem(
            value: SearchDisplayMode.allLogs,
            child: Text('All logs'),
          ),
          PopupMenuItem(
            value: SearchDisplayMode.matchesOnly,
            child: Text('Matches only'),
          ),
        ],
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              displayMode == SearchDisplayMode.allLogs
                  ? 'All logs'
                  : 'Matches only',
              style: GoogleFonts.ibmPlexSans(fontSize: 12),
            ),
            const Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
      ),
      Text(
        key: const Key('match_counter'),
        counter,
        style: GoogleFonts.ibmPlexMono(color: AppColors.outline, fontSize: 12),
      ),
      const SizedBox(width: 6),
      Tooltip(
        message: 'Previous match',
        child: IconButton(
          key: const Key('previous_match'),
          onPressed: onPreviousMatch,
          icon: const Icon(Icons.keyboard_arrow_up),
          color: AppColors.secondaryText,
          constraints: const BoxConstraints.tightFor(width: 24, height: 32),
          padding: EdgeInsets.zero,
        ),
      ),
      Tooltip(
        message: 'Next match',
        child: IconButton(
          key: const Key('next_match'),
          onPressed: onNextMatch,
          icon: const Icon(Icons.keyboard_arrow_down),
          color: AppColors.secondaryText,
          constraints: const BoxConstraints.tightFor(width: 24, height: 32),
          padding: EdgeInsets.zero,
        ),
      ),
      const SizedBox(width: 4),
      Tooltip(
        message: 'Clear search input',
        child: IconButton(
          key: const Key('clear_search_input'),
          onPressed: onClearSearch,
          icon: const Icon(Icons.close, size: 18),
          color: AppColors.secondaryText,
          constraints: const BoxConstraints.tightFor(width: 24, height: 32),
          padding: EdgeInsets.zero,
        ),
      ),
    ];
  }
}

class _KeywordChip extends StatelessWidget {
  const _KeywordChip({
    required this.value,
    required this.logic,
    required this.matchCase,
    required this.onToggleLogic,
    required this.onToggleMatchCase,
    required this.onRemove,
  });
  final String value;
  final String logic;
  final bool matchCase;
  final VoidCallback onToggleLogic;
  final VoidCallback onToggleMatchCase;
  final VoidCallback onRemove;
  @override
  Widget build(BuildContext context) => Container(
    height: 28,
    margin: const EdgeInsets.only(right: 4),
    decoration: const BoxDecoration(
      border: Border.fromBorderSide(BorderSide(color: AppColors.primary)),
      color: AppColors.surface,
    ),
    child: Row(
      children: [
        Tooltip(
          message: 'Toggle logic for $value',
          child: InkWell(
            key: Key('keyword_logic_$value'),
            onTap: onToggleLogic,
            child: Container(
              height: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: const BoxDecoration(
                color: Color(0x66D0E2FF),
                border: Border(right: BorderSide(color: AppColors.primary)),
              ),
              child: Center(
                child: Text(
                  logic,
                  style: GoogleFonts.ibmPlexSans(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
        Container(
          key: Key('keyword_value_$value'),
          height: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Center(
            child: Text(
              value,
              style: GoogleFonts.ibmPlexMono(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        Tooltip(
          message: 'Match case for $value',
          child: InkWell(
            onTap: onToggleMatchCase,
            child: Container(
              key: Key('keyword_match_case_badge_$value'),
              width: 26,
              height: 18,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: matchCase
                    ? AppColors.primaryContainer
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(
                child: Text(
                  'Aa',
                  key: Key('keyword_match_case_$value'),
                  style: GoogleFonts.ibmPlexSans(
                    color: matchCase
                        ? AppColors.primary
                        : AppColors.secondaryText,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
        Tooltip(
          message: 'Remove $value',
          child: InkWell(
            key: Key('remove_$value'),
            onTap: onRemove,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.close, size: 14, color: AppColors.primary),
            ),
          ),
        ),
      ],
    ),
  );
}
