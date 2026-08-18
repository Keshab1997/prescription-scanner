import 'package:flutter/material.dart';
import 'package:prescription_scanner/theme.dart';

/// Compact "About" card shown at the bottom of the Profile screen and inside
/// the Help screen. Keeps the app identity (name, ID, version, AI, developer)
/// defined in one place.
class AboutCard extends StatelessWidget {
  const AboutCard({super.key});

  static const String appName = 'Prescription Scanner';
  static const String appId = 'com.keshabstudios.prescriptionscanner';
  static const String appVersion = '1.0.0';
  static const String developer = 'Keshab Studios';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 22, color: AppColors.teal),
          SizedBox(height: 12),
          _AboutRow(label: 'App', value: appName),
          Divider(height: 20),
          _AboutRow(label: 'App ID', value: appId),
          Divider(height: 20),
          _AboutRow(label: 'Version', value: appVersion),
          Divider(height: 20),
          _AboutRow(label: 'AI', value: 'Prescription Scanner AI'),
          Divider(height: 20),
          _AboutRow(label: 'Developer', value: developer),
        ],
      ),
    );
  }
}

class _AboutRow extends StatelessWidget {
  const _AboutRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}
