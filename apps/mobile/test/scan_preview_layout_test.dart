import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prescription_scanner/screens/scan_screens.dart';
import 'package:prescription_scanner/services/prescription_upload_service.dart';

class _FakeUploadService extends PrescriptionUploadService {
  @override
  Future<PreparedPrescription?> recoverInterruptedPick() async => null;
}

void main() {
  for (final screenWidth in <double>[320, 360, 412]) {
    testWidgets(
      'scan preview stays fixed across animation at ${screenWidth.toInt()} px',
      (tester) async {
        tester.view.physicalSize = Size(screenWidth, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              prescriptionUploadServiceProvider.overrideWithValue(
                _FakeUploadService(),
              ),
            ],
            child: const MaterialApp(home: UploadScreen()),
          ),
        );
        await tester.pump();

        final preview = find.byKey(const ValueKey('empty-scan-preview'));
        final viewport = find.byKey(const ValueKey('scan-animation-viewport'));
        final document = find.byKey(const ValueKey('scan-document'));
        final title = find.byKey(const ValueKey('scan-preview-title'));
        final subtitle = find.byKey(const ValueKey('scan-preview-subtitle'));
        final takePhoto = find.text('Take photo');
        final tips = find.text('For a clearer result');

        final initialPreviewSize = tester.getSize(preview);
        final initialViewportSize = tester.getSize(viewport);
        final initialDocumentPosition = tester.getTopLeft(document);
        final initialTitlePosition = tester.getTopLeft(title);
        final initialSubtitlePosition = tester.getTopLeft(subtitle);
        final initialTakePhotoPosition = tester.getTopLeft(takePhoto);
        final initialTipsPosition = tester.getTopLeft(tips);

        expect(initialPreviewSize.height, 320);
        expect(initialViewportSize.height, 132);
        expect(tester.takeException(), isNull);

        // Cover small, middle and fully expanded ripple phases.
        for (final elapsed in <Duration>[
          const Duration(milliseconds: 350),
          const Duration(milliseconds: 800),
          const Duration(milliseconds: 1150),
          const Duration(milliseconds: 2000),
        ]) {
          await tester.pump(elapsed);

          expect(tester.getSize(preview), initialPreviewSize);
          expect(tester.getSize(viewport), initialViewportSize);
          expect(tester.getTopLeft(document), initialDocumentPosition);
          expect(tester.getTopLeft(title), initialTitlePosition);
          expect(tester.getTopLeft(subtitle), initialSubtitlePosition);
          expect(tester.getTopLeft(takePhoto), initialTakePhotoPosition);
          expect(tester.getTopLeft(tips), initialTipsPosition);
          expect(tester.takeException(), isNull);
        }
      },
    );
  }
}
