import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:logger/features/log_viewer/log_viewer_page.dart';
import 'package:logger/ui/app_colors.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LogViewer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: const ColorScheme.light(
          primary: AppColors.primary,
          surface: AppColors.surface,
          onSurface: AppColors.text,
        ),
        scaffoldBackgroundColor: AppColors.surface,
        textTheme: GoogleFonts.ibmPlexSansTextTheme(),
      ),
      home: const LogViewerPage(),
    );
  }
}
