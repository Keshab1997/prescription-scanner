import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:prescription_scanner/models/extracted_prescription.dart';
import 'package:prescription_scanner/services/consent_store.dart';
import 'package:prescription_scanner/services/result_store.dart';

void main() {
  test(
    'local prescription and consent data are isolated by Firebase UID',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'ks-user-data-test',
      );
      Hive.init(directory.path);
      addTearDown(() async {
        await Hive.close();
        await directory.delete(recursive: true);
      });

      // Simulate data from the old owner-less schema. The selected migration
      // policy requires this box to be deleted rather than assigned arbitrarily.
      final legacy = await Hive.openBox('rx_results');
      await legacy.put('legacy-result', {'id': 'legacy-result'});
      await legacy.close();

      final store = await ResultStore.init();
      expect(await Hive.boxExists('rx_results'), isFalse);

      final resultA = _result('shared-id', DateTime(2026, 8, 16, 10));
      final resultB = _result('shared-id', DateTime(2026, 8, 16, 11));
      await store.save('firebase-user-a', resultA);
      await store.save('firebase-user-b', resultB);

      expect(store.getAll('firebase-user-a'), hasLength(1));
      expect(store.getAll('firebase-user-b'), hasLength(1));
      expect(
        store.get('firebase-user-a', 'shared-id')?.createdAt,
        resultA.createdAt,
      );
      expect(
        store.get('firebase-user-b', 'shared-id')?.createdAt,
        resultB.createdAt,
      );
      expect(store.get('firebase-user-c', 'shared-id'), isNull);

      await ConsentStore.grantAiConsent('firebase-user-a');
      expect(await ConsentStore.hasAiConsent('firebase-user-a'), isTrue);
      expect(await ConsentStore.hasAiConsent('firebase-user-b'), isFalse);

      await store.save('guest', _result('guest-scan', DateTime(2026, 8, 17)));
      final moved = await store.transferOwner('guest', 'firebase-user-b');
      expect(moved, 1);
      expect(store.getAll('guest'), isEmpty);
      expect(store.get('firebase-user-b', 'guest-scan'), isNotNull);

      await store.clearUser('firebase-user-a');
      await ConsentStore.clearUser('firebase-user-a');
      expect(store.getAll('firebase-user-a'), isEmpty);
      expect(store.getAll('firebase-user-b'), hasLength(1));
      expect(await ConsentStore.hasAiConsent('firebase-user-a'), isFalse);
    },
  );
}

ExtractedPrescription _result(String id, DateTime createdAt) {
  return ExtractedPrescription(
    id: id,
    overallConfidence: 0.9,
    needsManualReview: false,
    isPrescription: true,
    medicines: const [],
    warnings: const [],
    tests: const [],
    followUp: null,
    createdAt: createdAt,
  );
}
