import 'package:flutter_test/flutter_test.dart';
import 'package:prescription_scanner/config.dart';
import 'package:prescription_scanner/legal/legal_copy.dart';

void main() {
  test('privacy copy names Gemini and does not claim the image never leaves', () {
    expect(LegalCopy.privacyPolicy.toLowerCase(), contains('gemini'));
    expect(LegalCopy.privacySummary.toLowerCase(), contains('gemini'));
    expect(LegalCopy.privacyPolicy.toLowerCase(), isNot(contains('never leaves')));
    expect(LegalCopy.privacyPolicy.toLowerCase(), isNot(contains('nothing is uploaded')));
  });

  test('medical copy forbids diagnosis and treatment', () {
    expect(LegalCopy.medicalShort.toLowerCase(), contains('not a diagnosis'));
    expect(LegalCopy.medicalFull.toLowerCase(), contains('not a medical device'));
    expect(LegalCopy.medicalFull.toLowerCase(), contains('does not diagnose'));
  });

  test('guest vs signed-in limits are explicit', () {
    expect(LegalCopy.guestLimitBody, contains('1 free scan'));
    expect(LegalCopy.guestLimitBody, contains('2 more'));
    expect(LegalCopy.signedInLimitBody.toLowerCase(), contains('signed-in'));
  });

  test('camera rationale explains prescription photos only', () {
    expect(LegalCopy.cameraRationale.toLowerCase(), contains('prescription'));
    expect(LegalCopy.cameraRationale.toLowerCase(), contains('not saved to our cloud'));
  });

  test('ads stay on test units unless production id is provided', () {
    expect(AppConfig.useTestAds, isTrue);
    expect(AppConfig.bannerAdUnitId, AppConfig.bannerAdUnitIdTest);
    expect(AppConfig.bannerAdUnitIdTest, contains('ca-app-pub-3940256099942544'));
  });
}
