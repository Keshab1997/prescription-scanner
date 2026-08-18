import 'package:flutter_test/flutter_test.dart';
import 'package:prescription_scanner/services/play_in_app_update.dart';

void main() {
  test('no Play update when the store has nothing newer', () {
    expect(
      decidePlayUpdate(
        updateAvailable: false,
        immediateAllowed: true,
        flexibleAllowed: true,
      ),
      PlayUpdateAction.none,
    );
  });

  test('prefers a blocking immediate update when Play allows it', () {
    expect(
      decidePlayUpdate(
        updateAvailable: true,
        immediateAllowed: true,
        flexibleAllowed: true,
      ),
      PlayUpdateAction.immediate,
    );
  });

  test('falls back to flexible when immediate is not allowed', () {
    expect(
      decidePlayUpdate(
        updateAvailable: true,
        immediateAllowed: false,
        flexibleAllowed: true,
      ),
      PlayUpdateAction.flexible,
    );
  });

  test('still forces immediate when Play flags neither type', () {
    expect(
      decidePlayUpdate(
        updateAvailable: true,
        immediateAllowed: false,
        flexibleAllowed: false,
      ),
      PlayUpdateAction.immediate,
    );
  });
}
