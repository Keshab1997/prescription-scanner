import 'package:flutter_test/flutter_test.dart';
import 'package:prescription_scanner/services/disposable_email.dart';

void main() {
  group('disposableEmailError', () {
    test('rejects known disposable domains case-insensitively', () {
      expect(disposableEmailError('user@mailinator.com'), isNotNull);
      expect(disposableEmailError('User@YopMail.com'), isNotNull);
      expect(disposableEmailError('x@10minutemail.com'), isNotNull);
      expect(disposableEmailError('x@guerrillamail.com'), isNotNull);
      expect(disposableEmailError('x@trashmail.de'), isNotNull);
    });

    test('allows regular email providers', () {
      expect(disposableEmailError('keshabsarkar2018@gmail.com'), isNull);
      expect(disposableEmailError('name@outlook.com'), isNull);
      expect(disposableEmailError('name@yahoo.com'), isNull);
      expect(disposableEmailError('name@protonmail.com'), isNull);
    });

    test('handles malformed emails gracefully', () {
      expect(disposableEmailError('no-at-sign'), isNull);
      expect(disposableEmailError(''), isNull);
      expect(disposableEmailError('user@'), isNull);
      expect(disposableEmailError('@mailinator.com'), isNull);
    });
  });
}
