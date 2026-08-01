import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/main.dart';

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

void main() {
  testWidgets('renders the LogViewer reference content', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(const MyApp());

    expect(find.text('LogViewer'), findsOneWidget);
    expect(find.byKey(const Key('keyword_count')), findsNothing);
    expect(find.text('ECU_MAIN'), findsOneWidget);
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
      expect(find.text(value), findsOneWidget);
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
    expect(find.text('Payload'), findsNothing);
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
    await tester.tap(find.text('Error'));
    await tester.tap(find.text('Fatal'));
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
    await tester.tap(find.text('Verbose'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('filter_operator_verbose_mode')), findsNothing);
    expect(find.text('Verbose'), findsOneWidget);
  });

  testWidgets('a time range stores its start and end values', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MyApp());

    await tester.tap(find.text('Clear all'));
    await openFilterMenu(tester);
    await tester.tap(find.byKey(const Key('add_filter_time_range')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('filter_value_time_range')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('time_range_start')),
      '2026-08-01 10:00',
    );
    await tester.enterText(
      find.byKey(const Key('time_range_end')),
      '2026-08-01 11:00',
    );
    await tester.tapAt(const Offset(10, 500));
    await tester.pumpAndSettle();

    expect(find.text('2026-08-01 10:00 – 2026-08-01 11:00'), findsOneWidget);
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
    expect(find.byKey(const Key('time_range_start_picker')), findsOneWidget);
    expect(find.byKey(const Key('time_range_end_picker')), findsOneWidget);
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

  testWidgets(
    'renders padded timeout highlights for inactive and active rows',
    (tester) async {
      await tester.pumpWidget(const MyApp());

      final inactive = tester.widget<Container>(
        find.byKey(const Key('timeout_highlight_10_48_33')),
      );
      final inactiveDecoration = inactive.decoration! as BoxDecoration;
      expect(inactive.padding, const EdgeInsets.symmetric(horizontal: 4));
      expect(inactiveDecoration.color, const Color(0x66D0E2FF));
      expect(
        inactiveDecoration.border,
        const Border.fromBorderSide(BorderSide(color: Color(0x4D0F62FE))),
      );

      final active = tester.widget<Container>(
        find.byKey(const Key('timeout_highlight_10_48_43')),
      );
      final activeDecoration = active.decoration! as BoxDecoration;
      expect(active.padding, const EdgeInsets.symmetric(horizontal: 4));
      expect(activeDecoration.color, const Color(0xFF0F62FE));
      expect(
        tester
            .widget<Text>(
              find.descendant(
                of: find.byKey(const Key('timeout_highlight_10_48_43')),
                matching: find.text('timeout'),
              ),
            )
            .style
            ?.color,
        Colors.white,
      );
    },
  );

  testWidgets('renders the static search controls and Aa chip actions', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Aa'), findsNWidgets(5));
    expect(find.byIcon(Icons.subject), findsNothing);
    expect(
      tester
          .widget<Text>(find.byKey(const Key('match_counter')))
          .style
          ?.fontFamily,
      startsWith('IBMPlexMono'),
    );
  });

  testWidgets('removing a keyword updates the count', (tester) async {
    await tester.pumpWidget(const MyApp());

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

    final logicControl = find.byKey(const Key('keyword_logic_timeout'));
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

    expect(find.text('ECU_MAIN'), findsNothing);
    expect(find.text('TELE'), findsOneWidget);
  });

  testWidgets('search actions expose tooltips and keep filters visible', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.byKey(const Key('advanced_filters_toggle')), findsNothing);
    expect(find.byKey(const Key('filter_strip')), findsOneWidget);
    expect(find.byTooltip('Match case for timeout'), findsOneWidget);
    expect(find.byTooltip('Previous match'), findsOneWidget);
    expect(find.byTooltip('Next match'), findsOneWidget);
    expect(find.byTooltip('Clear search input'), findsOneWidget);
  });

  testWidgets('match case is configured per keyword', (tester) async {
    await tester.pumpWidget(const MyApp());

    await tester.tap(find.byKey(const Key('keyword_match_case_timeout')));
    await tester.pump();

    expect(find.byKey(const Key('search_mode_control')), findsNothing);
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

  testWidgets('match navigation clamps the counter between one and fifteen', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    await tester.tap(find.byKey(const Key('previous_match')));
    await tester.tap(find.byKey(const Key('previous_match')));
    await tester.pump();
    expect(find.byKey(const Key('match_counter')), findsOneWidget);
    expect(find.text('1/15'), findsOneWidget);

    for (var index = 0; index < 15; index++) {
      await tester.tap(find.byKey(const Key('next_match')));
    }
    await tester.pump();
    expect(find.text('15/15'), findsOneWidget);

    await tester.tap(find.byKey(const Key('next_match')));
    await tester.pump();
    expect(find.text('15/15'), findsOneWidget);
  });

  testWidgets('search-action close clears only the unsubmitted input', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());

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

  testWidgets('narrow search controls scroll to and operate an action', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MyApp());

    await tester.scrollUntilVisible(
      find.byKey(const Key('next_match')),
      100,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('narrow_search_controls_scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.byKey(const Key('next_match')));
    await tester.pump();

    expect(find.text('3/15'), findsOneWidget);
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
