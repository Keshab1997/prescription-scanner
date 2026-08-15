import 'package:flutter/material.dart';

/// Read-only, audit-safe prescription directory.
///
/// Scanned results are stored only on the user's device (local Hive); the
/// original image and structured result never leave the phone. There is
/// therefore no server-side prescription table to list here. This screen
/// explains that and shows any server-side extraction failures if present.
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
                  Text('Prescriptions',
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
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
              _StatChip('On-device', '100%'),
              _StatChip('Server copies', '0'),
            ],
          )
        else
          Row(
            children: const [
              _StatChip('On-device', '100%'),
              SizedBox(width: 12),
              _StatChip('Server copies', '0'),
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
                    const Icon(Icons.shield_outlined,
                        size: 40, color: Colors.black38),
                    const SizedBox(height: 14),
                    const Text(
                      'No server-side prescription data',
                      style:
                          TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Prescription images and results are processed on the '
                      'device and kept locally. They are not uploaded to a '
                      'server, so there is nothing to list here.',
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
