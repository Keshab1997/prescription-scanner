import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Reads/writes the `admin_contacts/primary` document (admin email + phone).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Settings',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        const Text('Primary admin contact used for alerts and recovery.'),
        const SizedBox(height: 24),
        Expanded(
          child: StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('admin_contacts')
                .doc('primary')
                .snapshots(),
            builder: (context, snap) {
              if (snap.hasError) {
                return const Center(
                    child: Text('Failed to load settings.'));
              }
              final data =
                  snap.data?.data() as Map<String, dynamic>?;
              final email = data?['email'] as String? ?? '';
              final phone = data?['phone'] as String? ?? '';
              return _ContactCard(
                email: email,
                phone: phone,
                loading: !snap.hasData,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ContactCard extends StatefulWidget {
  const _ContactCard({
    required this.email,
    required this.phone,
    required this.loading,
  });
  final String email;
  final String phone;
  final bool loading;

  @override
  State<_ContactCard> createState() => _ContactCardState();
}

class _ContactCardState extends State<_ContactCard> {
  late final TextEditingController _email =
      TextEditingController(text: widget.email);
  late final TextEditingController _phone =
      TextEditingController(text: widget.phone);
  bool _busy = false;
  String? _saved;

  @override
  void dispose() {
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _saved = null;
    });
    try {
      await FirebaseFirestore.instance
          .collection('admin_contacts')
          .doc('primary')
          .set({
        'email': _email.text.trim(),
        'phone': _phone.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (mounted) setState(() => _saved = 'Saved');
    } catch (e) {
      if (mounted) setState(() => _saved = 'Save failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loading) {
      return const Card(child: Center(child: CircularProgressIndicator()));
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SizedBox(
          width: 420,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _email,
                decoration: const InputDecoration(
                  labelText: 'Admin email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _phone,
                decoration: const InputDecoration(
                  labelText: 'Admin phone',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 18),
              if (_saved != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(_saved!,
                      style: TextStyle(
                          color: _saved == 'Saved'
                              ? const Color(0xFF0F766E)
                              : Colors.redAccent)),
                ),
              FilledButton.icon(
                onPressed: _busy ? null : _save,
                icon: _busy
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_outlined),
                label: const Text('Save contact'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
