import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prescription_scanner_admin/main.dart';

void main() {
  testWidgets('App root builds without throwing', (WidgetTester tester) async {
    await tester.pumpWidget(const AdminApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
