import 'package:flutter/material.dart';
import 'package:admin_api_key_manager/admin_api_key_manager.dart';

/// Wraps the drop-in key management screen from admin_api_key_manager so admins
/// can add, edit, enable/disable, test, and delete Gemini keys in the shared
/// `admin_api_keys` Firestore collection.
class KeysScreen extends StatelessWidget {
  const KeysScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('AI Configuration',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        const Text('Manage Gemini API keys used by the mobile app.'),
        const SizedBox(height: 18),
        Expanded(
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: const AdminApiKeysScreen(),
          ),
        ),
      ],
    );
  }
}
