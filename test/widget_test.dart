import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:omr_pdf_generator/app.dart';

void main() {
  testWidgets('Application starts successfully', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: OMRPdfGeneratorApp()));

    expect(find.text('Dashboard'), findsWidgets);
    expect(find.text('New Job'), findsWidgets);
  });
}
