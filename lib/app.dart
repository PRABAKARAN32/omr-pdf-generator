import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';

import 'features/dashboard/screens/dashboard_screen.dart';

import 'features/client/screens/new_job_screen.dart';
import 'features/client/providers/job_session_provider.dart';

import 'features/excel_import/screens/excel_import_screen.dart';
import 'features/excel_import/providers/excel_provider.dart';

import 'features/barcode/screens/barcode_configuration_screen.dart';
import 'features/barcode/providers/barcode_configuration_provider.dart';

import 'features/layout_designer/screens/layout_designer_screen.dart';
import 'features/layout_designer/providers/layout_configuration_provider.dart';

import 'features/pdf_generation/screens/pdf_preview_screen.dart';

import 'shared/widgets/app_sidebar.dart';

class OMRPdfGeneratorApp extends StatelessWidget {
  const OMRPdfGeneratorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OMR PDF Generator',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const AppShell(),
    );
  }
}

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int selectedIndex = 0;

  static const List<String> pageTitles = [
    'Dashboard',
    'New Job',
    'Excel Import',
    'Barcode Configuration',
    'PDF Layout Designer',
    'PDF Preview',
  ];

  void _goToPage(int index) {
    if (index < 0 || index >= pageTitles.length) return;

    setState(() {
      selectedIndex = index;
    });
  }

  void _startNewProject() {
    ref.read(jobSessionProvider.notifier).clearSession();
    ref.read(excelProvider.notifier).reset();
    ref.read(barcodeConfigurationProvider.notifier).reset();
    ref.read(layoutConfigurationProvider.notifier).reset();

    _goToPage(1);
  }

  void _returnToDashboardAfterDownload() {
    _goToPage(0);
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      // 0 - Dashboard
      DashboardScreen(onNewProject: _startNewProject),

      // 1 - New Job
      NewJobScreen(onBack: () => _goToPage(0), onContinue: () => _goToPage(2)),

      // 2 - Excel Import
      ExcelImportScreen(onBack: () => _goToPage(1), onNext: () => _goToPage(3)),

      // 3 - Barcode Configuration
      BarcodeConfigurationScreen(
        onBack: () => _goToPage(2),
        onNext: () => _goToPage(4),
      ),

      // 4 - PDF Layout Designer
      LayoutDesignerScreen(
        onBack: () => _goToPage(3),
        onNext: () => _goToPage(5),
      ),

      // 5 - PDF Preview
      PdfPreviewScreen(
        onBack: () => _goToPage(4),
        onDownloadComplete: _returnToDashboardAfterDownload,
        isActive: selectedIndex == 5,
      ),
    ];

    return Scaffold(
      body: Row(
        children: [
          AppSidebar(
            selectedIndex: selectedIndex,
            onDestinationSelected: _goToPage,
          ),
          Expanded(
            child: Container(
              color: AppTheme.background,
              child: IndexedStack(index: selectedIndex, children: pages),
            ),
          ),
        ],
      ),
    );
  }
}
