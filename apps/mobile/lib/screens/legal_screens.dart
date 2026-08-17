import 'package:flutter/material.dart';
import 'package:prescription_scanner/legal/legal_copy.dart';
import 'package:prescription_scanner/theme.dart';

class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({
    required this.title,
    required this.body,
    super.key,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.amberSoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              LegalCopy.medicalShort,
              style: TextStyle(
                color: Color(0xFF805511),
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            body,
            style: const TextStyle(
              color: AppColors.ink,
              height: 1.5,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Support: ${LegalCopy.supportEmail}',
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LegalDocumentScreen(
      title: 'Privacy Policy',
      body: LegalCopy.privacyPolicy,
    );
  }
}

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LegalDocumentScreen(
      title: 'Terms of Use',
      body: LegalCopy.terms,
    );
  }
}

class MedicalDisclaimerScreen extends StatelessWidget {
  const MedicalDisclaimerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LegalDocumentScreen(
      title: 'Medical disclaimer',
      body: LegalCopy.medicalFull,
    );
  }
}
