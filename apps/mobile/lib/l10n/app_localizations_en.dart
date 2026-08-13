// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Prescription Scanner';

  @override
  String get scanPrescription => 'Scan prescription';

  @override
  String get medicalDisclaimer =>
      'This app transcribes visible prescription text. It does not provide medical advice.';
}
