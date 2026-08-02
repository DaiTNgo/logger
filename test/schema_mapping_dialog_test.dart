import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/features/log_viewer/log_viewer_page.dart';
import 'package:logger/features/log_viewer/models/schema_mismatch.dart';
import 'package:logger/features/log_viewer/services/schema_preset_repository.dart';
import 'package:logger/features/log_viewer/widgets/log_viewer_header.dart';
import 'package:logger/features/log_viewer/widgets/schema_mapping_dialog.dart';
import 'package:logger/features/log_viewer/widgets/schema_warning_toast.dart';

void main() {
  late Directory temporaryDirectory;
  late String pipeLogPath;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp('logger-map-');
    pipeLogPath = '${temporaryDirectory.path}/pipe.log';
    await File(
      pipeLogPath,
    ).writeAsString('10:00|INFO|started\n10:01|WARN|waiting\n');
  });

  tearDown(() async {
    await temporaryDirectory.delete(recursive: true);
  });

  testWidgets('Open file always shows mapping preview before confirmation', (
    tester,
  ) async {
    final picker = _FakeLogFilePicker(pipeLogPath);
    await _pumpPage(tester, picker: picker);

    await tester.tap(find.byKey(const Key('open_log_file_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('schema_mapping_dialog')), findsOneWidget);
    expect(find.byKey(const Key('schema_preview_table')), findsOneWidget);
    expect(find.byKey(const Key('confirm_log_import')), findsOneWidget);
    expect(find.text('started'), findsOneWidget);
  });

  testWidgets('mapping limits Filter and View fields after confirmation', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpPage(tester, picker: _FakeLogFilePicker(pipeLogPath));

    await tester.tap(find.byKey(const Key('open_log_file_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm_log_import')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('view_columns_button')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('view_column_option_log_level')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('view_column_option_apid')), findsNothing);

    await tester.tapAt(const Offset(10, 500));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add_filter_button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('add_filter_log_level')), findsOneWidget);
    expect(find.byKey(const Key('add_filter_apid')), findsNothing);
  });

  testWidgets('invalid mapping keeps confirmation disabled with inline error', (
    tester,
  ) async {
    await _pumpPage(tester, picker: _FakeLogFilePicker(pipeLogPath));
    await tester.tap(find.byKey(const Key('open_log_file_button')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('mapping_field_2')),
      'log_level',
    );
    await tester.pumpAndSettle();

    final confirm = tester.widget<FilledButton>(
      find.byKey(const Key('confirm_log_import')),
    );
    expect(confirm.onPressed, isNull);
    expect(find.byKey(const Key('schema_mapping_error')), findsOneWidget);
  });

  testWidgets('Save preset persists schema configuration and not file data', (
    tester,
  ) async {
    final store = _MemoryStore();
    final repository = SchemaPresetRepository(store);
    await _pumpPage(
      tester,
      picker: _FakeLogFilePicker(pipeLogPath),
      repository: repository,
    );
    await tester.tap(find.byKey(const Key('open_log_file_button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('save_schema_preset')));
    await tester.pumpAndSettle();

    final presets = await repository.load();
    expect(presets, hasLength(1));
    expect(presets.single.schema.delimiter, '|');
    expect(store.values.values.single, isNot(contains(pipeLogPath)));
    expect(store.values.values.single, isNot(contains('started')));
  });

  test('sample loading caps bytes and recoverable records', () async {
    final path = '${temporaryDirectory.path}/large.txt';
    final longLine = '${'x' * 1024}|INFO|message\n';
    await File(path).writeAsString(longLine * 300);

    final sample = await loadLogSample(path);

    expect(sample.bytes.length, lessThanOrEqualTo(256 * 1024));
    expect(sample.lines, hasLength(200));
  });

  testWidgets('schema warning updates one notification for a generation', (
    tester,
  ) async {
    var summary = const SchemaMismatchSummary(extraColumnRecords: 1);
    late StateSetter setState;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, update) {
              setState = update;
              return SchemaWarningToast(
                generation: 7,
                mismatches: summary,
                columnCount: 3,
                onReviewMapping: () {},
              );
            },
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('schema_warning_toast')), findsOneWidget);
    expect(
      find.text('Some records do not match the configured 3-column schema'),
      findsOneWidget,
    );

    setState(() {
      summary = const SchemaMismatchSummary(
        extraColumnRecords: 1,
        missingColumnRecords: 2,
      );
    });
    await tester.pump();

    expect(find.byKey(const Key('schema_warning_toast')), findsOneWidget);
    expect(find.text('3 affected records'), findsOneWidget);
    expect(find.text('Review mapping'), findsOneWidget);
  });
}

Future<void> _pumpPage(
  WidgetTester tester, {
  required LogFilePicker picker,
  SchemaPresetRepository? repository,
}) => tester.pumpWidget(
  MaterialApp(
    home: LogViewerPage(
      entries: const [],
      filePicker: picker,
      schemaPresetRepository: repository,
    ),
  ),
);

final class _FakeLogFilePicker implements LogFilePicker {
  const _FakeLogFilePicker(this.path);

  final String? path;

  @override
  Future<String?> openLogFile() async => path;
}

final class _MemoryStore implements StringPreferenceStore {
  final Map<String, String> values = {};

  @override
  Future<String?> getString(String key) async => values[key];

  @override
  Future<void> setString(String key, String value) async {
    values[key] = value;
  }
}
