import 'package:flutter/material.dart';

/// Read-only, audit-safe prescription directory.
///
/// Structured results are stored on the user's device in UID-scoped Hive.
/// Prepared images are sent directly to Google Gemini for transcription, but
/// this app does not keep images/results in its own cloud prescription store.
/// Therefore there is no server-side prescription directory to list here.
class PrescriptionsScreen extends StatefulWidget {
  const PrescriptionsScreen({super.key});

  @override
  State<PrescriptionsScreen> createState() => _PrescriptionsScreenState();
}

class _PrescriptionsScreenState extends State<PrescriptionsScreen> {
  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.of(context).size.width < 720;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Prescriptions',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                  Text('Extraction records stay on the user\'s device.'),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (isNarrow)
          Column(
            children: const [
              _StatChip('Local structured results', 'UID'),
              _StatChip('App cloud copies', '0'),
            ],
          )
        else
          Row(
            children: const [
              _StatChip('Local structured results', 'UID'),
              SizedBox(width: 12),
              _StatChip('App cloud copies', '0'),
            ],
          ),
        const SizedBox(height: 16),
        Expanded(
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.shield_outlined,
                      size: 40,
                      color: Colors.black38,
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'No server-side prescription data',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Prepared images are sent directly to Google Gemini for '
                      'transcription. This app keeps no prescription image or '
                      'structured-result copy in its own cloud database; '
                      'account-scoped results remain on the user’s device.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.black12),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F766E),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.black54, fontSize: 13),
        ),
      ],
    ),
  );
}
