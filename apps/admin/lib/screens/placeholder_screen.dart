import 'package:flutter/material.dart';

/// Placeholder screen for admin sections not yet backed by data.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 24),
        const Expanded(
          child: Card(
            child: Center(child: Text('Coming soon.')),
          ),
        ),
      ],
    );
  }
}
