import 'package:flutter/material.dart';
import 'package:logger/features/log_viewer/models/dlt_filter.dart';
import 'package:logger/ui/app_colors.dart';

class FilterStrip extends StatelessWidget {
  const FilterStrip({
    super.key,
    required this.filters,
    required this.onSelectField,
    required this.onUpdateFilter,
    required this.onRemoveFilter,
    required this.onClearFilters,
  });

  final List<DltFilter> filters;
  final ValueChanged<String> onSelectField;
  final ValueChanged<DltFilter> onUpdateFilter;
  final ValueChanged<String> onRemoveFilter;
  final VoidCallback onClearFilters;

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
        for (final definition in dltFilterDefinitions)
          PopupMenuItem(
            key: Key('add_filter_${definition.id}'),
            value: definition.id,
            child: Text(definition.label),
          ),
      ],
    );
    if (fieldId != null) onSelectField(fieldId);
  }
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
      if (filter.rangeStart == null || filter.rangeEnd == null) {
        return 'Select...';
      }
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
      childBuilder: (_) => SizedBox(
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
    var start = filter.rangeStart ?? '';
    var end = filter.rangeEnd ?? '';
    _showDropdown(
      anchorContext: context,
      dropdownKey: const Key('filter_dropdown_time_range'),
      onDismiss: () {
        if (start.trim().isNotEmpty && end.trim().isNotEmpty) {
          onUpdate(
            filter.copyWith(rangeStart: start.trim(), rangeEnd: end.trim()),
          );
        }
      },
      childBuilder: (_) => SizedBox(
        width: 320,
        child: Padding(
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
              TextField(
                key: const Key('time_range_start'),
                keyboardType: TextInputType.datetime,
                onChanged: (value) => start = value,
                decoration: const InputDecoration(
                  labelText: 'Start',
                  hintText: 'YYYY-MM-DD HH:mm',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('time_range_end'),
                keyboardType: TextInputType.datetime,
                onChanged: (value) => end = value,
                decoration: const InputDecoration(
                  labelText: 'End',
                  hintText: 'YYYY-MM-DD HH:mm',
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    key: const Key('time_range_start_picker'),
                    onPressed: () async {
                      final value = await _pickDateTime(context);
                      if (value != null) start = value;
                    },
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: const Text('Start date & time'),
                  ),
                  OutlinedButton.icon(
                    key: const Key('time_range_end_picker'),
                    onPressed: () async {
                      final value = await _pickDateTime(context);
                      if (value != null) end = value;
                    },
                    icon: const Icon(Icons.schedule, size: 16),
                    label: const Text('End date & time'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
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

Future<String?> _pickDateTime(BuildContext context) async {
  final date = await showDatePicker(
    context: context,
    initialDate: DateTime.now(),
    firstDate: DateTime(2000),
    lastDate: DateTime(2100),
  );
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.now(),
  );
  if (time == null) return null;
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '${date.year}-$month-$day $hour:$minute';
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
    entry.remove();
    onDismiss?.call();
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
        Positioned(
          left: offset.dx,
          top: offset.dy + anchor.size.height + 4,
          child: Material(
            key: dropdownKey,
            color: AppColors.surface,
            elevation: 8,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              side: const BorderSide(color: AppColors.border),
              borderRadius: BorderRadius.circular(16),
            ),
            child: childBuilder(dismiss),
          ),
        ),
      ],
    ),
  );
  overlay.insert(entry);
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
