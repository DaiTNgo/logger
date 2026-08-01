import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/data/sample_logs.dart';
import 'package:logger/features/log_viewer/models/dlt_filter.dart';
import 'package:logger/features/log_viewer/log_viewer_page.dart';
import 'package:logger/features/log_viewer/widgets/filter_strip.dart';
import 'package:logger/features/log_viewer/widgets/log_table.dart';
import 'package:logger/main.dart';
import 'package:logger/models/log_entry.dart';

Future<void> openFilterMenu(WidgetTester tester) async {
  final button = find.byKey(const Key('add_filter_button'));
  final filterScroll = find
      .descendant(
        of: find.byKey(const Key('filter_strip')),
        matching: find.byType(Scrollable),
      )
      .first;
  await tester.dragUntilVisible(button, filterScroll, const Offset(-200, 0));
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> openTimeRangeFilter(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1600, 700));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(const MyApp());
  await tester.tap(find.text('Clear all'));
  await openFilterMenu(tester);
  await tester.tap(find.byKey(const Key('add_filter_time_range')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('filter_value_time_range')));
  await tester.pumpAndSettle();
}

Future<void> selectCalendarDate(
  WidgetTester tester,
  Key calendarKey,
  Key popoverKey,
  DateTime date,
) async {
  await tester.tap(find.byKey(calendarKey));
  await tester.pumpAndSettle();
  final calendar = find.byKey(popoverKey);
  final localizations = MaterialLocalizations.of(tester.element(calendar));
  await tester.tap(
    find.descendant(
      of: calendar,
      matching: find.bySemanticsLabel(
        '${localizations.formatDecimal(date.day)}, '
        '${localizations.formatFullDate(date)}, '
        '${localizations.currentDateLabel}',
      ),
    ),
  );
  await tester.pumpAndSettle();
}

String formatDate(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

Future<void> selectTimeOption(
  WidgetTester tester,
  Key controlKey,
  Key popoverKey,
  Key optionKey,
) async {
  await tester.tap(find.byKey(controlKey));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    find.byKey(optionKey),
    100,
    scrollable: find.descendant(
      of: find.byKey(popoverKey),
      matching: find.byType(Scrollable),
    ),
  );
  await tester.tap(find.byKey(optionKey));
  await tester.pumpAndSettle();
}

void main() {
  test('sample logs provide every supported DLT field', () {
    const fieldIds = [
      'ecu_id',
      'apid',
      'ctid',
      'message_type',
      'log_level',
      'trace_type',
      'network_type',
      'header_type',
      'verbose_mode',
      'message_counter',
      'length',
      'number_of_arguments',
      'session_id',
      'time_range',
    ];
    for (final fieldId in fieldIds) {
      expect(sampleLogs.first.dltValues[fieldId], isNotEmpty);
    }
  });

  testWidgets('renders the LogViewer reference content', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(const MyApp());

    expect(find.text('LogViewer'), findsOneWidget);
    expect(find.byKey(const Key('keyword_count')), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const Key('filter_strip')),
        matching: find.text('ECU_MAIN'),
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        "Failed to resolve host 'db-replica-sec.internal'. DNS query timeout after 5000ms.",
      ),
      findsOneWidget,
    );
    expect(find.text('Explorer'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('shows headers for active DLT filters plus fixed columns', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MyApp());

    for (final label in const [
      'Time',
      'ECU ID',
      'APID',
      'CTID',
      'Message Type',
      'Log Level',
      'Payload',
    ]) {
      expect(find.byKey(Key('dlt_column_header_$label')), findsOneWidget);
    }
    expect(find.byKey(const Key('dlt_column_header_Trace Type')), findsNothing);
  });

  testWidgets('adding and removing a filter shows and hides its column', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MyApp());

    await openFilterMenu(tester);
    await tester.tap(find.byKey(const Key('add_filter_trace_type')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('dlt_column_header_Trace Type')),
      findsOneWidget,
    );

    final filterScroll = find
        .descendant(
          of: find.byKey(const Key('filter_strip')),
          matching: find.byType(Scrollable),
        )
        .first;
    final removeButton = find.byKey(const Key('remove_filter_trace_type'));
    await tester.dragUntilVisible(
      removeButton,
      filterScroll,
      const Offset(-200, 0),
    );
    await tester.tap(removeButton);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dlt_column_header_Trace Type')), findsNothing);
  });

  testWidgets('clearing filters retains Time and Payload columns', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.tap(find.text('Clear all'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dlt_column_header_Time')), findsOneWidget);
    expect(find.byKey(const Key('dlt_column_header_Payload')), findsOneWidget);
    expect(find.byKey(const Key('dlt_column_header_ECU ID')), findsNothing);
  });

  testWidgets('renders every supplied log message and initial filter value', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(const MyApp());

    final logScroll = find.byType(Scrollable).last;
    for (final message in const [
      'System initialization complete. Module [core] started successfully in 142ms.',
      'Network listener bound to 0.0.0.0:8080. Awaiting connections.',
      'High memory usage detected in worker pool. Current utilization: 85%. Consider scaling.',
      'Connection timeout while attempting to reach database replica at 192.168.1.5:5432. Retrying in 5s...',
      'Retry 1/3: Attempting connection to secondary replica.',
      "Failed to resolve host 'db-replica-sec.internal'. DNS query timeout after 5000ms.",
      'User session terminated gracefully. [UID: 9482-A]',
      "Scheduled task 'LogRotation' completed. 4 files compressed.",
      'Deprecation warning: API endpoint /v1/users/list will be removed in next release.',
      'Heartbeat sent to orchestrator. Status: HEALTHY.',
    ]) {
      await tester.scrollUntilVisible(
        find.bySemanticsLabel(message),
        200,
        scrollable: logScroll,
      );
      expect(find.bySemanticsLabel(message), findsOneWidget);
    }

    for (final value in const [
      'ECU_MAIN',
      'TELE',
      'NetworkComm',
      'Error, Fatal',
      'Log',
    ]) {
      expect(
        find.descendant(
          of: find.byKey(const Key('filter_strip')),
          matching: find.text(value),
        ),
        findsOneWidget,
      );
    }
    semantics.dispose();
  });

  testWidgets('uses a complete enabled outlined Add filter button', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    final button = find.widgetWithText(OutlinedButton, 'Add filter');
    expect(button, findsOneWidget);
    expect(tester.widget<OutlinedButton>(button).onPressed, isNotNull);
    expect(
      tester
          .widget<Text>(
            find.descendant(of: button, matching: find.text('Add filter')),
          )
          .style
          ?.fontSize,
      12,
    );
  });

  testWidgets('Add filter lists all non-payload DLT fields', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MyApp());

    await openFilterMenu(tester);

    for (final fieldId in const [
      'ecu_id',
      'apid',
      'ctid',
      'message_type',
      'log_level',
      'trace_type',
      'network_type',
      'header_type',
      'verbose_mode',
      'message_counter',
      'length',
      'number_of_arguments',
      'session_id',
      'time_range',
    ]) {
      expect(find.byKey(Key('add_filter_$fieldId')), findsOneWidget);
    }
    expect(find.byKey(const Key('add_filter_payload')), findsNothing);
  });

  testWidgets('selecting a DLT field adds a multi-value filter chip', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MyApp());

    await tester.tap(find.text('Clear all'));
    await openFilterMenu(tester);
    await tester.tap(find.byKey(const Key('add_filter_log_level')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dlt_filter_log_level')), findsOneWidget);
    expect(find.byKey(const Key('filter_operator_log_level')), findsOneWidget);
    expect(find.text('Select...'), findsOneWidget);
  });

  testWidgets('a multi-value filter stores all confirmed values', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MyApp());

    await tester.tap(find.text('Clear all'));
    await openFilterMenu(tester);
    await tester.tap(find.byKey(const Key('add_filter_log_level')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('filter_value_log_level')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('filter_option_log_level_1')));
    await tester.tap(find.byKey(const Key('filter_option_log_level_0')));
    await tester.tapAt(const Offset(10, 500));
    await tester.pumpAndSettle();

    expect(find.text('Error, Fatal'), findsOneWidget);
    expect(find.byKey(const Key('confirm_filter_values')), findsNothing);
  });

  testWidgets('a single-value filter opens a custom anchored dropdown', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MyApp());

    await tester.tap(find.text('Clear all'));
    await openFilterMenu(tester);
    await tester.tap(find.byKey(const Key('add_filter_verbose_mode')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('filter_value_verbose_mode')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('filter_dropdown_verbose_mode')),
      findsOneWidget,
    );
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('custom dropdown uses the reference rounded option style', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MyApp());

    await tester.tap(find.text('Clear all'));
    await openFilterMenu(tester);
    await tester.tap(find.byKey(const Key('add_filter_verbose_mode')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('filter_value_verbose_mode')));
    await tester.pumpAndSettle();

    final dropdown = tester.widget<Material>(
      find.byKey(const Key('filter_dropdown_verbose_mode')),
    );
    final shape = dropdown.shape! as RoundedRectangleBorder;
    expect(shape.borderRadius, BorderRadius.circular(16));
    expect(
      tester
          .getSize(find.byKey(const Key('filter_option_verbose_mode_0')))
          .height,
      40,
    );
  });

  testWidgets('value dropdowns show selected-state indicators', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MyApp());

    await tester.tap(find.byKey(const Key('filter_value_ecu_id')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('multi_selected_ecu_id_0')), findsOneWidget);
  });

  testWidgets(
    'multi-value options fill the dropdown width without selection tint',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const MyApp());

      await tester.tap(find.byKey(const Key('filter_value_ecu_id')));
      await tester.pumpAndSettle();

      final first = find.byKey(const Key('filter_option_ecu_id_0'));
      final second = find.byKey(const Key('filter_option_ecu_id_1'));
      expect(tester.getSize(first).width, tester.getSize(second).width);
      expect(tester.getSize(first).width, 304);
      expect(tester.getSize(first).height, 40);
      final decoration =
          tester.widget<Container>(first).decoration! as BoxDecoration;
      expect(decoration.color, Colors.transparent);
    },
  );

  testWidgets('a single-value filter does not show the is operator', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MyApp());

    await tester.tap(find.text('Clear all'));
    await openFilterMenu(tester);
    await tester.tap(find.byKey(const Key('add_filter_verbose_mode')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('filter_value_verbose_mode')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('filter_option_verbose_mode_0')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('filter_operator_verbose_mode')), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const Key('filter_strip')),
        matching: find.text('Verbose'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('start hour opens all 24 hour options', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MyApp());

    await tester.tap(find.text('Clear all'));
    await openFilterMenu(tester);
    await tester.tap(find.byKey(const Key('add_filter_time_range')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('filter_value_time_range')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('time_range_start_hour')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('time_range_start_hour_options')),
      findsOneWidget,
    );
    for (var hour = 0; hour < 24; hour++) {
      expect(
        find.byKey(Key('time_range_start_hour_option_$hour')),
        findsOneWidget,
      );
    }
  });

  testWidgets('end minute opens all 60 minute options', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MyApp());

    await tester.tap(find.text('Clear all'));
    await openFilterMenu(tester);
    await tester.tap(find.byKey(const Key('add_filter_time_range')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('filter_value_time_range')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('time_range_end_minute')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('time_range_end_minute_options')),
      findsOneWidget,
    );
    for (var minute = 0; minute < 60; minute++) {
      expect(
        find.byKey(Key('time_range_end_minute_option_$minute')),
        findsOneWidget,
      );
    }
  });

  testWidgets('a valid nested time range auto-saves its start and end values', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final selectedDate = DateUtils.dateOnly(DateTime.now());
    await tester.pumpWidget(const MyApp());

    await tester.tap(find.text('Clear all'));
    await openFilterMenu(tester);
    await tester.tap(find.byKey(const Key('add_filter_time_range')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('filter_value_time_range')));
    await tester.pumpAndSettle();

    await selectCalendarDate(
      tester,
      const Key('time_range_start_calendar'),
      const Key('inline_start_calendar'),
      selectedDate,
    );
    await selectTimeOption(
      tester,
      const Key('time_range_start_hour'),
      const Key('time_range_start_hour_options'),
      const Key('time_range_start_hour_option_10'),
    );
    await selectTimeOption(
      tester,
      const Key('time_range_start_minute'),
      const Key('time_range_start_minute_options'),
      const Key('time_range_start_minute_option_0'),
    );

    await selectCalendarDate(
      tester,
      const Key('time_range_end_calendar'),
      const Key('inline_end_calendar'),
      selectedDate,
    );
    await selectTimeOption(
      tester,
      const Key('time_range_end_hour'),
      const Key('time_range_end_hour_options'),
      const Key('time_range_end_hour_option_11'),
    );
    await selectTimeOption(
      tester,
      const Key('time_range_end_minute'),
      const Key('time_range_end_minute_options'),
      const Key('time_range_end_minute_option_0'),
    );

    expect(
      find.text(
        '${formatDate(selectedDate)} 10:00 – ${formatDate(selectedDate)} 11:00',
      ),
      findsOneWidget,
    );
  });

  testWidgets('an invalid nested time range does not update the filter', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final selectedDate = DateUtils.dateOnly(DateTime.now());
    await tester.pumpWidget(const MyApp());

    await tester.tap(find.text('Clear all'));
    await openFilterMenu(tester);
    await tester.tap(find.byKey(const Key('add_filter_time_range')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('filter_value_time_range')));
    await tester.pumpAndSettle();

    await selectCalendarDate(
      tester,
      const Key('time_range_start_calendar'),
      const Key('inline_start_calendar'),
      selectedDate,
    );
    await selectTimeOption(
      tester,
      const Key('time_range_start_hour'),
      const Key('time_range_start_hour_options'),
      const Key('time_range_start_hour_option_11'),
    );
    await selectCalendarDate(
      tester,
      const Key('time_range_end_calendar'),
      const Key('inline_end_calendar'),
      selectedDate,
    );
    await selectTimeOption(
      tester,
      const Key('time_range_end_hour'),
      const Key('time_range_end_hour_options'),
      const Key('time_range_end_hour_option_10'),
    );
    await tester.tapAt(const Offset(10, 500));
    await tester.pumpAndSettle();

    expect(find.text('Select...'), findsOneWidget);
  });

  testWidgets('a valid typed start date applies only after blur', (
    tester,
  ) async {
    await openTimeRangeFilter(tester);
    final input = find.byKey(const Key('time_range_start_input'));
    await tester.tap(input);
    await tester.enterText(input, '2026-08-02');
    expect(find.text('Select...'), findsOneWidget);
    await tester.tap(find.byKey(const Key('time_range_end_input')));
    await tester.pumpAndSettle();
    expect(find.text('2026-08-02 00:00 –'), findsOneWidget);
  });

  testWidgets('an invalid typed date does not update the filter', (
    tester,
  ) async {
    await openTimeRangeFilter(tester);
    final input = find.byKey(const Key('time_range_start_input'));
    await tester.tap(input);
    await tester.enterText(input, '2026-02-30');
    await tester.tap(find.byKey(const Key('time_range_end_input')));
    await tester.pumpAndSettle();
    expect(find.text('Select...'), findsOneWidget);
    expect(find.text('2026-02-30'), findsOneWidget);
  });

  testWidgets('start calendar opens in a popover', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MyApp());

    await tester.tap(find.text('Clear all'));
    await openFilterMenu(tester);
    await tester.tap(find.byKey(const Key('add_filter_time_range')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('filter_value_time_range')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('time_range_start_calendar')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('inline_start_calendar')), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('outside click closes the full nested time range popover stack', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final selectedDate = DateUtils.dateOnly(DateTime.now());
    await tester.pumpWidget(const MyApp());

    await tester.tap(find.text('Clear all'));
    await openFilterMenu(tester);
    await tester.tap(find.byKey(const Key('add_filter_time_range')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('filter_value_time_range')));
    await tester.pumpAndSettle();
    await selectCalendarDate(
      tester,
      const Key('time_range_start_calendar'),
      const Key('inline_start_calendar'),
      selectedDate,
    );
    await selectCalendarDate(
      tester,
      const Key('time_range_end_calendar'),
      const Key('inline_end_calendar'),
      selectedDate,
    );

    await tester.tap(find.byKey(const Key('time_range_start_hour')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('filter_dropdown_time_range')), findsOneWidget);
    expect(
      find.byKey(const Key('time_range_start_hour_options')),
      findsOneWidget,
    );

    await tester.tapAt(const Offset(1500, 650));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('filter_dropdown_time_range')), findsNothing);
    expect(
      find.byKey(const Key('time_range_start_hour_options')),
      findsNothing,
    );
    expect(
      find.text(
        '${formatDate(selectedDate)} 00:00 – ${formatDate(selectedDate)} 00:00',
      ),
      findsOneWidget,
    );
  });

  testWidgets('an upward short dropdown remains adjacent to its anchor', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(600, 400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: FilterStrip(
              filters: const [DltFilter(fieldId: 'verbose_mode')],
              onSelectField: (_) {},
              onUpdateFilter: (_) {},
              onRemoveFilter: (_) {},
              onClearFilters: () {},
            ),
          ),
        ),
      ),
    );

    final anchor = find.byKey(const Key('filter_value_verbose_mode'));
    await tester.tap(anchor);
    await tester.pumpAndSettle();

    final dropdown = find.byKey(const Key('filter_dropdown_verbose_mode'));
    expect(tester.getTopLeft(dropdown).dy, greaterThanOrEqualTo(16));
    expect(
      tester.getBottomRight(dropdown).dy,
      closeTo(tester.getTopLeft(anchor).dy - 4, 1),
    );
  });

  testWidgets('time range offers presets and date-time picker controls', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MyApp());

    await tester.tap(find.text('Clear all'));
    await openFilterMenu(tester);
    await tester.tap(find.byKey(const Key('add_filter_time_range')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('filter_value_time_range')));
    await tester.pumpAndSettle();

    expect(find.text('Today'), findsOneWidget);
    expect(find.byKey(const Key('time_range_start_hour')), findsOneWidget);
    expect(find.byKey(const Key('time_range_end_minute')), findsOneWidget);
  });

  testWidgets('choosing an active DLT field does not add a duplicate chip', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MyApp());

    await tester.tap(find.text('Clear all'));
    await openFilterMenu(tester);
    await tester.tap(find.byKey(const Key('add_filter_ecu_id')));
    await tester.pumpAndSettle();
    await openFilterMenu(tester);
    await tester.tap(find.byKey(const Key('add_filter_ecu_id')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dlt_filter_ecu_id')), findsOneWidget);
  });

  testWidgets('search starts empty and inactive', (tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.text('Aa'), findsNothing);
    expect(find.text('0/0'), findsOneWidget);
    expect(
      find.byKey(const Key('payload_search_highlights_10_48_33')),
      findsNothing,
    );
  });

  testWidgets('submitted payload keyword produces dynamic row matches', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.enterText(find.byKey(const Key('keyword_input')), 'timeout');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('1/2'), findsOneWidget);
    expect(
      find.byKey(const Key('payload_search_highlights_10_48_33')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('current_search_match_row_10_48_33')),
      findsOneWidget,
    );
  });

  testWidgets(
    'next match moves the active search row without moving selection',
    (tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.tap(find.byKey(const Key('log_row_10_42_01')));
      await tester.pump();
      await tester.enterText(find.byKey(const Key('keyword_input')), 'timeout');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('active_log_row_10_42_01')), findsOneWidget);

      await tester.tap(find.byKey(const Key('next_match')));
      await tester.pumpAndSettle();
      expect(find.text('2/2'), findsOneWidget);
      expect(
        find.byKey(const Key('current_search_match_row_10_48_43')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('active_log_row_10_42_01')), findsOneWidget);
    },
  );

  testWidgets(
    'search navigation preserves the table horizontal scroll offset',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const MyApp());
      await tester.enterText(find.byKey(const Key('keyword_input')), 'timeout');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      final tableScrollables = find.descendant(
        of: find.byType(LogTable),
        matching: find.byType(Scrollable),
      );
      final horizontalScrollable = tester
          .stateList<ScrollableState>(tableScrollables)
          .singleWhere((state) => state.position.axis == Axis.horizontal);
      horizontalScrollable.position.jumpTo(200);
      await tester.pump();
      final horizontalOffsetBefore = horizontalScrollable.position.pixels;

      await tester.tap(find.byKey(const Key('next_match')));
      await tester.pumpAndSettle();

      expect(
        horizontalScrollable.position.pixels,
        closeTo(horizontalOffsetBefore, 0.1),
      );
      expect(
        find.byKey(const Key('current_search_match_row_10_48_43')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'variable-height search navigation reveals the distant active row',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 500));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final entries = List<LogEntry>.generate(30, (index) {
        final isTall = index > 0 && index < 12;
        final marker = index == 0 || index == 20 ? ' needle' : '';
        return LogEntry(
          time: '12:00:${index.toString().padLeft(2, '0')}',
          level: LogLevel.info,
          message:
              '${isTall ? List.filled(90, 'uneven payload ').join() : 'row'}$marker',
        );
      });
      await tester.pumpWidget(
        MaterialApp(home: LogViewerPage(entries: entries)),
      );
      await tester.enterText(find.byKey(const Key('keyword_input')), 'needle');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('next_match')));
      await tester.pumpAndSettle();

      final activeRow = find.byKey(
        const Key('current_search_match_row_12_00_20'),
      );
      final verticalScrollable = tester
          .stateList<ScrollableState>(
            find.descendant(
              of: find.byType(LogTable),
              matching: find.byType(Scrollable),
            ),
          )
          .singleWhere((state) => state.position.axis == Axis.vertical);
      final viewport = tester.getRect(find.byWidget(verticalScrollable.widget));
      final rowBounds = tester.getRect(activeRow);
      expect(rowBounds.top, greaterThanOrEqualTo(viewport.top));
      expect(rowBounds.bottom, lessThanOrEqualTo(viewport.bottom));
    },
  );

  testWidgets(
    'overlapping search navigation settles on the latest active match',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const MyApp());
      for (final keyword in ['System', 'database']) {
        await tester.enterText(find.byKey(const Key('keyword_input')), keyword);
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
      }
      for (final keyword in ['System', 'database']) {
        final logicControl = find.byKey(Key('keyword_logic_$keyword'));
        await tester.ensureVisible(logicControl);
        await tester.tap(logicControl);
        await tester.pumpAndSettle();
      }

      await tester.tap(find.byKey(const Key('next_match')));
      await tester.pump(const Duration(milliseconds: 20));
      await tester.tap(find.byKey(const Key('remove_database')));
      await tester.pumpAndSettle();

      final verticalScrollable = tester
          .stateList<ScrollableState>(
            find.descendant(
              of: find.byType(LogTable),
              matching: find.byType(Scrollable),
            ),
          )
          .singleWhere((state) => state.position.axis == Axis.vertical);
      expect(find.text('1/1'), findsOneWidget);
      expect(
        find.byKey(const Key('current_search_match_row_10_42_01')),
        findsOneWidget,
      );
      expect(verticalScrollable.position.pixels, closeTo(0, 0.1));
    },
  );

  testWidgets('Matches only hides nonmatching rows', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.enterText(find.byKey(const Key('keyword_input')), 'timeout');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('search_mode_control')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Matches only').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('log_row_10_48_33')), findsOneWidget);
    expect(find.byKey(const Key('log_row_10_48_43')), findsOneWidget);
    expect(find.byKey(const Key('log_row_10_42_01')), findsNothing);
  });

  testWidgets('Matches only shows an empty state for zero results', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.enterText(
      find.byKey(const Key('keyword_input')),
      'not-present',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('search_mode_control')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Matches only').last);
    await tester.pumpAndSettle();
    expect(find.text('No logs match the current search'), findsOneWidget);
    expect(find.text('0/0'), findsOneWidget);
  });

  testWidgets('removing a keyword updates the count', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.enterText(find.byKey(const Key('keyword_input')), 'timeout');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('remove_timeout')));
    await tester.pump();

    expect(find.byKey(const Key('remove_timeout')), findsNothing);
    expect(find.byKey(const Key('keyword_count')), findsNothing);
  });

  testWidgets('submitting a keyword adds a search token', (tester) async {
    await tester.pumpWidget(const MyApp());

    await tester.enterText(find.byKey(const Key('keyword_input')), 'latency');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(find.text('latency'), findsOneWidget);
    expect(find.byKey(const Key('keyword_count')), findsNothing);
  });

  testWidgets('clear all removes structured filters', (tester) async {
    await tester.pumpWidget(const MyApp());

    await tester.tap(find.text('Clear all'));
    await tester.pump();

    expect(find.text('ECU_MAIN'), findsNothing);
    expect(find.text('Add filter'), findsOneWidget);
  });

  testWidgets('bottom navigation reflects the selected destination', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    await tester.tap(find.text('Filters'));
    await tester.pump();

    final selected = tester.widget<Icon>(find.byKey(const Key('nav_icon_2')));
    expect(selected.color, const Color(0xFF0F62FE));
  });

  testWidgets(
    'narrow composition keeps search, filters, logs, and navigation available',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(const MyApp());

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('keyword_input')), findsOneWidget);
      expect(find.byKey(const Key('filter_strip')), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('active_log_row')),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.byKey(const Key('active_log_row')), findsOneWidget);
      expect(find.text('Explorer'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    },
  );

  testWidgets('a keyword logic control toggles between AND and OR', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    for (final keyword in ['timeout', 'error']) {
      await tester.enterText(find.byKey(const Key('keyword_input')), keyword);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
    }

    final logicControl = find.byKey(const Key('keyword_logic_timeout'));
    await tester.ensureVisible(logicControl);
    await tester.tap(logicControl);
    await tester.pump();

    expect(
      find.descendant(of: logicControl, matching: find.text('OR')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('keyword_logic_error')),
        matching: find.text('AND'),
      ),
      findsOneWidget,
    );

    await tester.tap(logicControl);
    await tester.pump();

    expect(
      find.descendant(of: logicControl, matching: find.text('AND')),
      findsOneWidget,
    );
  });

  testWidgets('keyword chip orders logic, keyword, match case, and remove', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.enterText(find.byKey(const Key('keyword_input')), 'timeout');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    final logicX = tester
        .getCenter(find.byKey(const Key('keyword_logic_timeout')))
        .dx;
    final keywordX = tester
        .getCenter(find.byKey(const Key('keyword_value_timeout')))
        .dx;
    final matchCaseX = tester
        .getCenter(find.byKey(const Key('keyword_match_case_timeout')))
        .dx;
    final removeX = tester
        .getCenter(find.byKey(const Key('remove_timeout')))
        .dx;

    expect(logicX, lessThan(keywordX));
    expect(keywordX, lessThan(matchCaseX));
    expect(matchCaseX, lessThan(removeX));
  });

  testWidgets('removing one structured filter preserves the others', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    await tester.tap(find.byKey(const Key('remove_filter_ecu_id')));
    await tester.pump();

    expect(
      find.descendant(
        of: find.byKey(const Key('filter_strip')),
        matching: find.text('ECU_MAIN'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('filter_strip')),
        matching: find.text('TELE'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('search actions expose tooltips and keep filters visible', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.enterText(find.byKey(const Key('keyword_input')), 'timeout');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('advanced_filters_toggle')), findsNothing);
    expect(find.byKey(const Key('filter_strip')), findsOneWidget);
    expect(find.byTooltip('Match case for timeout'), findsOneWidget);
    expect(find.byTooltip('Previous match'), findsOneWidget);
    expect(find.byTooltip('Next match'), findsOneWidget);
    expect(find.byTooltip('Clear search input'), findsOneWidget);
  });

  testWidgets('match case is configured per keyword', (tester) async {
    await tester.pumpWidget(const MyApp());
    for (final keyword in ['timeout', 'error']) {
      await tester.enterText(find.byKey(const Key('keyword_input')), keyword);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
    }

    await tester.tap(find.byKey(const Key('keyword_match_case_timeout')));
    await tester.pump();

    expect(find.byKey(const Key('search_mode_control')), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const Key('keyword_match_case_timeout')))
          .style
          ?.color,
      const Color(0xFF0F62FE),
    );
    expect(
      tester
          .widget<Text>(find.byKey(const Key('keyword_match_case_error')))
          .style
          ?.color,
      const Color(0xFF525252),
    );
    final matchCaseBadge = tester.widget<Container>(
      find.byKey(const Key('keyword_match_case_badge_timeout')),
    );
    final badgeDecoration = matchCaseBadge.decoration! as BoxDecoration;
    expect(badgeDecoration.color, const Color(0xFFD0E2FF));
    expect(badgeDecoration.borderRadius, BorderRadius.circular(6));
    expect(find.byTooltip('Match case for timeout'), findsOneWidget);
  });

  testWidgets('search-action close clears only the unsubmitted input', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    await tester.enterText(find.byKey(const Key('keyword_input')), 'timeout');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('keyword_input')), 'latency');
    await tester.tap(find.byKey(const Key('clear_search_input')));
    await tester.pump();

    expect(
      tester
          .widget<TextField>(find.byKey(const Key('keyword_input')))
          .controller
          ?.text,
      isEmpty,
    );
    expect(find.byKey(const Key('remove_timeout')), findsOneWidget);
    expect(find.byKey(const Key('keyword_count')), findsNothing);
  });

  testWidgets('selecting a log row keeps its content position stable', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    final row = find.byKey(const Key('log_row_10_42_01'));
    final timestamp = find.descendant(of: row, matching: find.text('10:42:01'));
    final timestampBeforeTap = tester.getTopLeft(timestamp);

    await tester.tap(row);
    await tester.pump();

    expect(tester.getTopLeft(timestamp), timestampBeforeTap);
  });

  testWidgets('tapping a log row moves the active rail to that row', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    await tester.tap(find.byKey(const Key('log_row_10_42_01')));
    await tester.pump();

    expect(find.byKey(const Key('active_log_row_10_42_01')), findsOneWidget);
    expect(find.byKey(const Key('active_log_row_10_48_43')), findsNothing);
    final row = tester.widget<Container>(
      find.byKey(const Key('active_log_row')),
    );
    final decoration = row.decoration! as BoxDecoration;
    final border = decoration.border! as Border;
    expect(border.left, const BorderSide(color: Color(0xFF0F62FE), width: 4));
    expect(find.byKey(const Key('log_row_10_42_01')), findsOneWidget);
  });

  testWidgets('match case is evaluated per submitted keyword', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.enterText(find.byKey(const Key('keyword_input')), 'Timeout');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('1/2'), findsOneWidget);
    await tester.tap(find.byKey(const Key('keyword_match_case_Timeout')));
    await tester.pumpAndSettle();
    expect(find.text('0/0'), findsOneWidget);
  });

  testWidgets('OR becomes optional when another keyword remains AND', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    for (final keyword in ['timeout', 'database']) {
      await tester.enterText(find.byKey(const Key('keyword_input')), keyword);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
    }
    expect(find.text('1/1'), findsOneWidget);
    await tester.tap(find.byKey(const Key('keyword_logic_database')));
    await tester.pumpAndSettle();
    expect(find.text('1/2'), findsOneWidget);
  });

  testWidgets('removing the final keyword restores All logs', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.enterText(find.byKey(const Key('keyword_input')), 'timeout');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('search_mode_control')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Matches only').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('remove_timeout')));
    await tester.pumpAndSettle();
    expect(find.text('All logs'), findsOneWidget);
    expect(find.text('0/0'), findsOneWidget);
    expect(find.byKey(const Key('log_row_10_42_01')), findsOneWidget);
  });

  testWidgets('navigation buttons disable at the first and last match', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.enterText(find.byKey(const Key('keyword_input')), 'timeout');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('previous_match')))
          .onPressed,
      isNull,
    );
    expect(
      tester.widget<IconButton>(find.byKey(const Key('next_match'))).onPressed,
      isNotNull,
    );
    await tester.tap(find.byKey(const Key('next_match')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<IconButton>(find.byKey(const Key('next_match'))).onPressed,
      isNull,
    );
  });

  testWidgets('keyword input stays readable on desktop and narrow screens', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    expect(tester.getSize(find.byKey(const Key('keyword_input'))).width, 200);

    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MyApp());
    expect(tester.getSize(find.byKey(const Key('keyword_input'))).width, 140);
  });
}
