import 'package:flutter/material.dart';
import 'package:logger/features/log_viewer/models/schema_mismatch.dart';

class SchemaWarningToast extends StatelessWidget {
  const SchemaWarningToast({
    super.key,
    required this.generation,
    required this.mismatches,
    required this.columnCount,
    required this.onReviewMapping,
  });

  final int generation;
  final SchemaMismatchSummary mismatches;
  final int columnCount;
  final VoidCallback onReviewMapping;

  @override
  Widget build(BuildContext context) {
    if (mismatches.isEmpty) return const SizedBox.shrink();
    return Material(
      key: const Key('schema_warning_toast'),
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Some records do not match the configured '
                    '$columnCount-column schema',
                  ),
                  Text('${mismatches.totalRecords} affected records'),
                ],
              ),
            ),
            TextButton(
              key: const Key('review_schema_mapping'),
              onPressed: onReviewMapping,
              child: const Text('Review mapping'),
            ),
          ],
        ),
      ),
    );
  }
}
