// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/widgets.dart' as fw;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thaypay/src/ui/app.dart';

void main() {
  testWidgets('App boots smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: ThayPayApp()));
    await tester.pump();
    // Let 0-duration timers from flutter_animate flush, without waiting for
    // chart animations to fully settle.
    await tester.pump(const Duration(milliseconds: 20));

    expect(find.byTooltip('Calendar'), findsOneWidget);
    expect(find.byTooltip('Home'), findsOneWidget);
    expect(find.byTooltip('Wallet'), findsOneWidget);

    // Dispose to avoid pending timers at test teardown.
    await tester.pumpWidget(const fw.SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 20));
  });
}
