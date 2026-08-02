import 'package:flutter/material.dart';
import 'package:logger/features/log_viewer/models/dlt_filter.dart';
import 'package:logger/ui/app_colors.dart';

class FilterStrip extends StatelessWidget {
  const FilterStrip({
    super.key,
    required this.filters,
    required this.visibleColumnIds,
    required this.onToggleVisibleColumn,
    required this.onSelectField,
    required this.onUpdateFilter,
    required this.onRemoveFilter,
    required this.onClearFilters,
    this.availableFieldIds,
  });

  final List<DltFilter> filters;
  final Set<String> visibleColumnIds;
  final ValueChanged<String> onToggleVisibleColumn;
  final ValueChanged<String> onSelectField;
  final ValueChanged<DltFilter> onUpdateFilter;
  final ValueChanged<String> onRemoveFilter;
  final VoidCallback onClearFilters;
  final Set<String>? availableFieldIds;

  Iterable<DltFilterDefinition> get _availableDefinitions =>
      dltFilterDefinitions.where(
        (definition) =>
            availableFieldIds == null ||
            availableFieldIds!.contains(definition.id),
      );

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('filter_strip'),
    height: 52,
    decoration: const BoxDecoration(
      color: AppColors.surfaceContainer,
      border: Border(bottom: BorderSide(color: AppColors.border)),
    ),
    child: Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                ...filters.map(
                  (filter) => _DltFilterChip(
                    filter: filter,
                    onUpdate: onUpdateFilter,
                    onRemove: () => onRemoveFilter(filter.fieldId),
                  ),
                ),
                Builder(
                  builder: (buttonContext) => OutlinedButton(
                    key: const Key('add_filter_button'),
                    onPressed: () => _showFieldMenu(buttonContext),
                    style: const ButtonStyle(
                      minimumSize: WidgetStatePropertyAll(Size(0, 28)),
                      padding: WidgetStatePropertyAll(
                        EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      ),
                      side: WidgetStatePropertyAll(
                        BorderSide(color: AppColors.border),
                      ),
                      shape: WidgetStatePropertyAll(RoundedRectangleBorder()),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text(
                      'Add filter',
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Builder(
                  builder: (buttonContext) => OutlinedButton(
                    key: const Key('view_columns_button'),
                    onPressed: () => _showViewMenu(buttonContext),
                    style: const ButtonStyle(
                      minimumSize: WidgetStatePropertyAll(Size(0, 28)),
                      padding: WidgetStatePropertyAll(
                        EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      ),
                      side: WidgetStatePropertyAll(
                        BorderSide(color: AppColors.border),
                      ),
                      shape: WidgetStatePropertyAll(RoundedRectangleBorder()),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text(
                      'View',
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Tooltip(
          message: 'Clear all filters',
          child: InkWell(
            onTap: onClearFilters,
            child: const Padding(
              padding: EdgeInsets.only(left: 12, right: 16),
              child: Center(
                child: Text(
                  'Clear all',
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Future<void> _showFieldMenu(BuildContext context) async {
    final buttonBox = context.findRenderObject()! as RenderBox;
    final overlayBox =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final position = RelativeRect.fromRect(
      buttonBox.localToGlobal(Offset.zero) & buttonBox.size,
      Offset.zero & overlayBox.size,
    );
    final fieldId = await showMenu<String>(
      context: context,
      position: position,
      items: [
        for (final definition in _availableDefinitions)
          PopupMenuItem(
            key: Key('add_filter_${definition.id}'),
            value: definition.id,
            child: Text(definition.label),
          ),
      ],
    );
    if (fieldId != null) onSelectField(fieldId);
  }

  void _showViewMenu(BuildContext context) => _showDropdown(
    anchorContext: context,
    dropdownKey: const Key('view_columns_dropdown'),
    childBuilder: (_) => SizedBox(
      width: 320,
      child: StatefulBuilder(
        builder: (context, setDropdownState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final definition in _availableDefinitions)
              InkWell(
                key: Key('view_column_option_${definition.id}'),
                onTap: () => setDropdownState(
                  () => onToggleVisibleColumn(definition.id),
                ),
                child: SizedBox(
                  height: 40,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 32,
                        child: visibleColumnIds.contains(definition.id)
                            ? Icon(
                                Icons.check,
                                key: Key(
                                  'view_column_selected_${definition.id}',
                                ),
                              )
                            : null,
                      ),
                      Text(definition.label),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class _DltFilterChip extends StatelessWidget {
  const _DltFilterChip({
    required this.filter,
    required this.onUpdate,
    required this.onRemove,
  });

  final DltFilter filter;
  final ValueChanged<DltFilter> onUpdate;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final definition = definitionFor(filter.fieldId);
    final value = _valueLabel(definition);
    return Container(
      key: Key('dlt_filter_${definition.id}'),
      margin: const EdgeInsets.only(right: 8),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border.fromBorderSide(BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          _FilterLabel(label: definition.label, emphasized: true),
          if (definition.mode == DltFilterMode.multiValue)
            _FilterLabel(
              key: Key('filter_operator_${definition.id}'),
              label: 'is',
            ),
          Builder(
            builder: (valueContext) => InkWell(
              key: Key('filter_value_${definition.id}'),
              onTap: () => _showValueSelector(valueContext, definition),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  value,
                  style: const TextStyle(fontSize: 12, color: AppColors.text),
                ),
              ),
            ),
          ),
          Tooltip(
            message: 'Remove ${definition.label} filter',
            child: InkWell(
              key: Key('remove_filter_${definition.id}'),
              onTap: onRemove,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(
                  Icons.close,
                  size: 14,
                  color: AppColors.secondaryText,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _valueLabel(DltFilterDefinition definition) {
    if (definition.mode == DltFilterMode.timeRange) {
      if (filter.rangeStart == null && filter.rangeEnd == null) {
        return 'Select...';
      }
      if (filter.rangeEnd == null) return '${filter.rangeStart} –';
      if (filter.rangeStart == null) return '– ${filter.rangeEnd}';
      return '${filter.rangeStart} – ${filter.rangeEnd}';
    }
    return filter.values.isEmpty ? 'Select...' : filter.values.join(', ');
  }

  Future<void> _showValueSelector(
    BuildContext context,
    DltFilterDefinition definition,
  ) async {
    switch (definition.mode) {
      case DltFilterMode.multiValue:
        _showMultiValueSelector(context, definition);
        return;
      case DltFilterMode.singleValue:
        _showSingleValueSelector(context, definition);
        return;
      case DltFilterMode.timeRange:
        _showTimeRangeSelector(context);
        return;
    }
  }

  void _showMultiValueSelector(
    BuildContext context,
    DltFilterDefinition definition,
  ) {
    final selectedValues = filter.values.toSet();
    _showDropdown(
      anchorContext: context,
      dropdownKey: Key('filter_dropdown_${definition.id}'),
      childBuilder: (dismiss) => SizedBox(
        width: 320,
        child: StatefulBuilder(
          builder: (context, setDropdownState) => Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (index, option) in definition.options.indexed)
                  InkWell(
                    onTap: () => setDropdownState(() {
                      if (!selectedValues.add(option)) {
                        selectedValues.remove(option);
                      }
                      onUpdate(
                        filter.copyWith(values: selectedValues.toList()),
                      );
                    }),
                    borderRadius: BorderRadius.circular(12),
                    hoverColor: AppColors.surfaceContainer,
                    child: Container(
                      key: Key('filter_option_${definition.id}_$index'),
                      width: double.infinity,
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 32,
                            child: selectedValues.contains(option)
                                ? Icon(
                                    Icons.check,
                                    key: Key(
                                      'multi_selected_${definition.id}_$index',
                                    ),
                                    size: 22,
                                  )
                                : null,
                          ),
                          Text(option, style: const TextStyle(fontSize: 16)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSingleValueSelector(
    BuildContext context,
    DltFilterDefinition definition,
  ) => _showDropdown(
    anchorContext: context,
    dropdownKey: Key('filter_dropdown_${definition.id}'),
    childBuilder: (dismiss) => SizedBox(
      width: 320,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (index, option) in definition.options.indexed)
              InkWell(
                key: Key('filter_option_${definition.id}_$index'),
                onTap: () {
                  onUpdate(filter.copyWith(values: [option]));
                  dismiss();
                },
                borderRadius: BorderRadius.circular(12),
                hoverColor: AppColors.surfaceContainer,
                child: Container(
                  width: double.infinity,
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 32,
                        child: filter.values.contains(option)
                            ? Icon(
                                Icons.circle,
                                key: Key(
                                  'single_selected_${definition.id}_$index',
                                ),
                                size: 8,
                              )
                            : null,
                      ),
                      Text(option, style: const TextStyle(fontSize: 16)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );

  void _showTimeRangeSelector(BuildContext context) {
    final panelKey = GlobalKey<_TimeRangePanelState>();
    _showDropdown(
      anchorContext: context,
      dropdownKey: const Key('filter_dropdown_time_range'),
      onDismiss: () => panelKey.currentState?.submitFocusedDate(),
      childBuilder: (dismiss) => SizedBox(
        width: 320,
        child: _TimeRangePanel(
          key: panelKey,
          initialStart: _parseDateTime(filter.rangeStart),
          initialEnd: _parseDateTime(filter.rangeEnd),
          dismissPanel: dismiss,
          onUpdate: (start, end) => onUpdate(
            DltFilter(
              fieldId: filter.fieldId,
              values: filter.values,
              rangeStart: start == null ? null : _formatDateTime(start),
              rangeEnd: end == null ? null : _formatDateTime(end),
            ),
          ),
        ),
      ),
    );
  }
}

class _TimeRangePanel extends StatefulWidget {
  const _TimeRangePanel({
    super.key,
    this.initialStart,
    this.initialEnd,
    required this.dismissPanel,
    required this.onUpdate,
  });

  final DateTime? initialStart;
  final DateTime? initialEnd;
  final VoidCallback dismissPanel;
  final void Function(DateTime? start, DateTime? end) onUpdate;

  @override
  State<_TimeRangePanel> createState() => _TimeRangePanelState();
}

class _TimeRangePanelState extends State<_TimeRangePanel> {
  late DateTime? _start = widget.initialStart;
  late DateTime? _end = widget.initialEnd;
  late final TextEditingController _startDateController;
  late final TextEditingController _endDateController;
  late final FocusNode _startDateFocusNode;
  late final FocusNode _endDateFocusNode;
  var _startDateTextDirty = false;
  var _endDateTextDirty = false;

  @override
  void initState() {
    super.initState();
    _startDateController = TextEditingController(text: _formatDate(_start));
    _endDateController = TextEditingController(text: _formatDate(_end));
    _startDateFocusNode = FocusNode()
      ..addListener(() {
        if (!_startDateFocusNode.hasFocus) {
          _submitDate(isStart: true, value: _startDateController.text);
        }
      });
    _endDateFocusNode = FocusNode()
      ..addListener(() {
        if (!_endDateFocusNode.hasFocus) {
          _submitDate(isStart: false, value: _endDateController.text);
        }
      });
  }

  @override
  void dispose() {
    _startDateController.dispose();
    _endDateController.dispose();
    _startDateFocusNode.dispose();
    _endDateFocusNode.dispose();
    super.dispose();
  }

  void _submitDate({required bool isStart, required String value}) {
    final date = _parseDate(value);
    if (date == null) return;
    final current = isStart ? _start : _end;
    _updateBoundary(
      isStart: isStart,
      value: DateTime(
        date.year,
        date.month,
        date.day,
        current?.hour ?? 0,
        current?.minute ?? 0,
      ),
    );
  }

  void submitFocusedDate() {
    if (_startDateFocusNode.hasFocus) {
      _submitDate(isStart: true, value: _startDateController.text);
    } else if (_endDateFocusNode.hasFocus) {
      _submitDate(isStart: false, value: _endDateController.text);
    }
  }

  void _updateBoundary({
    required bool isStart,
    required DateTime value,
    bool syncDateText = true,
  }) {
    setState(() {
      if (isStart) {
        _start = value;
        if (syncDateText) {
          _startDateController.text = _formatDate(value);
          _startDateTextDirty = false;
        }
      } else {
        _end = value;
        if (syncDateText) {
          _endDateController.text = _formatDate(value);
          _endDateTextDirty = false;
        }
      }
    });
    if (_start == null || _end == null || !_start!.isAfter(_end!)) {
      widget.onUpdate(_start, _end);
    }
  }

  void _clearBoundary({required bool isStart}) {
    setState(() {
      if (isStart) {
        _start = null;
        _startDateController.clear();
        _startDateTextDirty = false;
      } else {
        _end = null;
        _endDateController.clear();
        _endDateTextDirty = false;
      }
    });
    widget.onUpdate(_start, _end);
  }

  void _showCalendar(BuildContext context, {required bool isStart}) {
    _showDropdown(
      anchorContext: context,
      dropdownKey: Key(
        isStart ? 'inline_start_calendar' : 'inline_end_calendar',
      ),
      childBuilder: (dismiss) => SizedBox(
        width: 320,
        child: CalendarDatePicker(
          initialDate: (isStart ? _start : _end) ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
          onDateChanged: (date) {
            final current = isStart ? _start : _end;
            final updated = DateTime(
              date.year,
              date.month,
              date.day,
              current?.hour ?? 0,
              current?.minute ?? 0,
            );
            _updateBoundary(isStart: isStart, value: updated);
            dismiss();
          },
        ),
      ),
    );
  }

  void _showTimeOptions(
    BuildContext context, {
    required bool isStart,
    required bool isHour,
  }) {
    final part = isHour ? 'hour' : 'minute';
    final boundary = isHour ? 24 : 60;
    final prefix = 'time_range_${isStart ? 'start' : 'end'}_$part';
    _showDropdown(
      anchorContext: context,
      dropdownKey: Key('${prefix}_options'),
      childBuilder: (dismiss) => SizedBox(
        width: 120,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var value = 0; value < boundary; value++)
              InkWell(
                key: Key('${prefix}_option_$value'),
                onTap: () {
                  final current = isStart ? _start : _end;
                  final base = current ?? DateTime.now();
                  _updateBoundary(
                    isStart: isStart,
                    value: DateTime(
                      base.year,
                      base.month,
                      base.day,
                      isHour ? value : base.hour,
                      isHour ? base.minute : value,
                    ),
                    syncDateText: isStart
                        ? !_startDateTextDirty
                        : !_endDateTextDirty,
                  );
                  dismiss();
                },
                child: SizedBox(
                  width: double.infinity,
                  height: 36,
                  child: Center(child: Text(value.toString().padLeft(2, '0'))),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(12),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick range',
          style: TextStyle(color: AppColors.secondaryText, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: const [
            _TimePreset(label: 'Today'),
            _TimePreset(label: 'Last 7 days'),
            _TimePreset(label: 'Last 30 days'),
            _TimePreset(label: 'Last 90 days'),
          ],
        ),
        const SizedBox(height: 12),
        _DateTimeSection(
          title: 'START DATE & TIME',
          dateKey: const Key('time_range_start'),
          dateInputKey: const Key('time_range_start_input'),
          calendarKey: const Key('time_range_start_calendar'),
          hourKey: const Key('time_range_start_hour'),
          minuteKey: const Key('time_range_start_minute'),
          clearKey: const Key('time_range_clear_start'),
          value: _start,
          dateController: _startDateController,
          dateFocusNode: _startDateFocusNode,
          onDateChanged: (_) => _startDateTextDirty = true,
          onClear: () => _clearBoundary(isStart: true),
          onCalendarTap: (context) => _showCalendar(context, isStart: true),
          onHourTap: (context) =>
              _showTimeOptions(context, isStart: true, isHour: true),
          onMinuteTap: (context) =>
              _showTimeOptions(context, isStart: true, isHour: false),
        ),
        const SizedBox(height: 16),
        _DateTimeSection(
          title: 'END DATE & TIME',
          dateKey: const Key('time_range_end'),
          dateInputKey: const Key('time_range_end_input'),
          calendarKey: const Key('time_range_end_calendar'),
          hourKey: const Key('time_range_end_hour'),
          minuteKey: const Key('time_range_end_minute'),
          clearKey: const Key('time_range_clear_end'),
          value: _end,
          dateController: _endDateController,
          dateFocusNode: _endDateFocusNode,
          onDateChanged: (_) => _endDateTextDirty = true,
          onClear: () => _clearBoundary(isStart: false),
          onCalendarTap: (context) => _showCalendar(context, isStart: false),
          onHourTap: (context) =>
              _showTimeOptions(context, isStart: false, isHour: true),
          onMinuteTap: (context) =>
              _showTimeOptions(context, isStart: false, isHour: false),
        ),
      ],
    ),
  );
}

class _DateTimeSection extends StatelessWidget {
  const _DateTimeSection({
    required this.title,
    required this.dateKey,
    required this.dateInputKey,
    required this.calendarKey,
    required this.hourKey,
    required this.minuteKey,
    required this.clearKey,
    required this.value,
    required this.dateController,
    required this.dateFocusNode,
    required this.onDateChanged,
    required this.onClear,
    required this.onCalendarTap,
    required this.onHourTap,
    required this.onMinuteTap,
  });

  final String title;
  final Key dateKey;
  final Key dateInputKey;
  final Key calendarKey;
  final Key hourKey;
  final Key minuteKey;
  final Key clearKey;
  final DateTime? value;
  final TextEditingController dateController;
  final FocusNode dateFocusNode;
  final ValueChanged<String> onDateChanged;
  final VoidCallback onClear;
  final ValueChanged<BuildContext> onCalendarTap;
  final ValueChanged<BuildContext> onHourTap;
  final ValueChanged<BuildContext> onMinuteTap;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              title,
              softWrap: false,
              style: const TextStyle(
                color: AppColors.secondaryText,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            key: clearKey,
            onPressed: onClear,
            child: const Text('Clear'),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Container(
        key: dateKey,
        child: TextField(
          key: dateInputKey,
          controller: dateController,
          focusNode: dateFocusNode,
          onChanged: onDateChanged,
          decoration: InputDecoration(
            hintText: 'YYYY-MM-DD',
            suffixIcon: Builder(
              builder: (iconContext) => IconButton(
                key: calendarKey,
                icon: const Icon(Icons.calendar_today, size: 18),
                onPressed: () => onCalendarTap(iconContext),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: _TimePart(
              key: hourKey,
              value: value?.hour,
              onTap: onHourTap,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text(':'),
          ),
          Expanded(
            child: _TimePart(
              key: minuteKey,
              value: value?.minute,
              onTap: onMinuteTap,
            ),
          ),
        ],
      ),
    ],
  );
}

class _TimePart extends StatelessWidget {
  const _TimePart({super.key, this.value, required this.onTap});

  final int? value;
  final ValueChanged<BuildContext> onTap;

  @override
  Widget build(BuildContext context) => Builder(
    builder: (partContext) => InkWell(
      onTap: () => onTap(partContext),
      child: InputDecorator(
        decoration: const InputDecoration(hintText: '00'),
        child: Text(value?.toString().padLeft(2, '0') ?? ''),
      ),
    ),
  );
}

class _TimePreset extends StatelessWidget {
  const _TimePreset({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(label, style: const TextStyle(fontSize: 12)),
  );
}

DateTime? _parseDateTime(String? value) =>
    value == null ? null : DateTime.tryParse(value.replaceFirst(' ', 'T'));

DateTime? _parseDate(String value) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return null;
  final year = int.parse(value.substring(0, 4));
  final month = int.parse(value.substring(5, 7));
  final day = int.parse(value.substring(8, 10));
  final date = DateTime(year, month, day);
  return date.year == year && date.month == month && date.day == day
      ? date
      : null;
}

String _formatDate(DateTime? value) {
  if (value == null) return '';
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

String _formatDateTime(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '${value.year}-$month-$day $hour:$minute';
}

void _showDropdown({
  required BuildContext anchorContext,
  required Key dropdownKey,
  required Widget Function(VoidCallback dismiss) childBuilder,
  VoidCallback? onDismiss,
}) {
  final anchor = anchorContext.findRenderObject()! as RenderBox;
  final overlay = Overlay.of(anchorContext);
  final overlayBox = overlay.context.findRenderObject()! as RenderBox;
  final offset = anchor.localToGlobal(Offset.zero, ancestor: overlayBox);
  late OverlayEntry entry;
  var closed = false;
  void dismiss() {
    if (closed) return;
    closed = true;
    onDismiss?.call();
    entry.remove();
  }

  entry = OverlayEntry(
    builder: (context) => Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: dismiss,
          ),
        ),
        Positioned.fill(
          child: CustomSingleChildLayout(
            delegate: _DropdownPositionDelegate(anchor: offset & anchor.size),
            child: Material(
              key: dropdownKey,
              color: AppColors.surface,
              elevation: 8,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                side: const BorderSide(color: AppColors.border),
                borderRadius: BorderRadius.circular(16),
              ),
              child: SingleChildScrollView(child: childBuilder(dismiss)),
            ),
          ),
        ),
      ],
    ),
  );
  overlay.insert(entry);
}

class _DropdownPositionDelegate extends SingleChildLayoutDelegate {
  const _DropdownPositionDelegate({required this.anchor});

  static const _safeMargin = 16.0;
  static const _gap = 4.0;
  static const _maxWidth = 320.0;

  final Rect anchor;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final size = constraints.biggest;
    final above = (anchor.top - _safeMargin).clamp(0.0, size.height);
    final below = (size.height - anchor.bottom - _gap - _safeMargin).clamp(
      0.0,
      size.height,
    );
    final maxHeight = above > below ? above : below;
    return BoxConstraints(
      maxWidth: (size.width - _safeMargin * 2).clamp(0.0, _maxWidth),
      maxHeight: maxHeight,
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final above = anchor.top - _safeMargin;
    final below = size.height - anchor.bottom - _gap - _safeMargin;
    final opensUp = childSize.height > below && above > below;
    final maxLeft = size.width - childSize.width - _safeMargin;
    final maxTop = size.height - childSize.height - _safeMargin;
    final left = anchor.left.clamp(_safeMargin, maxLeft);
    final preferredTop = opensUp
        ? anchor.top - _gap - childSize.height
        : anchor.bottom + _gap;
    final top = preferredTop.clamp(_safeMargin, maxTop);
    return Offset(left, top);
  }

  @override
  bool shouldRelayout(_DropdownPositionDelegate oldDelegate) =>
      oldDelegate.anchor != anchor;
}

class _FilterLabel extends StatelessWidget {
  const _FilterLabel({super.key, required this.label, this.emphasized = false});

  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    decoration: const BoxDecoration(
      border: Border(right: BorderSide(color: AppColors.border)),
    ),
    child: Center(
      child: Text(
        label,
        style: TextStyle(
          color: emphasized ? AppColors.text : AppColors.secondaryText,
          fontSize: 12,
          fontWeight: emphasized ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    ),
  );
}
