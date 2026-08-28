import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mindset/main.dart';

void main() {
  testWidgets('MindSet shows the welcome experience', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MindSetApp());

    expect(find.text('MindSet'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(find.text('Create account'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
  });
}
