import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prescription_scanner/app.dart';

void main() {
  testWidgets('opens the secure login screen', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: PrescriptionScannerApp()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Prescription Scanner'), findsNothing);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign in securely'), findsOneWidget);
  });
}
