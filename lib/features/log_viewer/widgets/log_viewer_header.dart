import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:logger/ui/app_colors.dart';

class LogViewerHeader extends StatelessWidget {
  const LogViewerHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
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
          const Tooltip(
            message: 'Search logs',
            child: Icon(Icons.search, color: AppColors.secondaryText),
          ),
        ],
      ),
    );
  }
}
