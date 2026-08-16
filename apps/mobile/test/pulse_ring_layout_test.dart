import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prescription_scanner/widgets/ui_animations.dart';

void main() {
  testWidgets('PulseRing animation does not change layout size', (
    tester,
  ) async {
    const ringKey = Key('ring');
    const contentKey = Key('content-below');

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                PulseRing(
                  key: ringKey,
                  pulses: 1,
                  child: SizedBox.square(dimension: 72),
                ),
                SizedBox(height: 18),
                Text('No prescriptions yet', key: contentKey),
              ],
            ),
          ),
        ),
      ),
    );

    final initialRingSize = tester.getSize(find.byKey(ringKey));
    final initialContentPosition = tester.getTopLeft(find.byKey(contentKey));

    for (final elapsed in <Duration>[
      const Duration(milliseconds: 400),
      const Duration(milliseconds: 800),
      const Duration(milliseconds: 1200),
      const Duration(milliseconds: 2000),
    ]) {
      await tester.pump(elapsed);
      expect(tester.getSize(find.byKey(ringKey)), initialRingSize);
      expect(tester.getTopLeft(find.byKey(contentKey)), initialContentPosition);
    }
  });
}
