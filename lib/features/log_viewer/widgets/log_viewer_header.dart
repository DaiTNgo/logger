import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:logger/ui/app_colors.dart';

abstract interface class LogFilePicker {
  Future<String?> openLogFile();
}

final class FileSelectorLogFilePicker implements LogFilePicker {
  const FileSelectorLogFilePicker();

  @override
  Future<String?> openLogFile() async {
    const typeGroup = XTypeGroup(
      label: 'Log files',
      extensions: ['log', 'txt', 'dlt'],
    );
    final file = await openFile(acceptedTypeGroups: const [typeGroup]);
    return file?.path;
  }
}

class LogViewerHeader extends StatelessWidget {
  const LogViewerHeader({super.key, this.onOpenFile});

  final VoidCallback? onOpenFile;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => Row(
          children: [
            const Tooltip(
              message: 'Open navigation',
              child: Icon(Icons.menu, color: AppColors.secondaryText),
            ),
            const SizedBox(width: 12),
            Text(
              'LogViewer',
              style: GoogleFonts.ibmPlexSans(
                color: AppColors.primary,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            if (constraints.maxWidth < 420)
              Tooltip(
                message: 'Open file',
                child: IconButton(
                  key: const Key('open_log_file_button'),
                  onPressed: onOpenFile,
                  icon: const Icon(Icons.file_open, size: 18),
                ),
              )
            else
              TextButton.icon(
                key: const Key('open_log_file_button'),
                onPressed: onOpenFile,
                icon: const Icon(Icons.file_open, size: 18),
                label: const Text('Open file'),
              ),
            if (constraints.maxWidth >= 420) ...[
              const SizedBox(width: 8),
              const Tooltip(
                message: 'Search logs',
                child: Icon(Icons.search, color: AppColors.secondaryText),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
