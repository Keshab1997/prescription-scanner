import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:admin_api_key_manager/admin_api_key_manager.dart';

/// Smart API key setup.
///
/// Two tabs:
///  • "Add key" — a guided form where picking a provider auto-fills the base
///    URL and a sensible default model, so admins never have to type endpoints.
///  • "Manage" — the drop-in package screen for editing, toggling, testing and
///    deleting existing keys in the shared `admin_api_keys` Firestore pool.
class KeysScreen extends StatefulWidget {
  const KeysScreen({super.key});

  @override
  State<KeysScreen> createState() => _KeysScreenState();
}

class _KeysScreenState extends State<KeysScreen> {
  int _tab = 0;
  bool _testingAll = false;

  Future<void> _testAll() async {
    setState(() => _testingAll = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('admin_api_keys')
          .where('isActive', isEqualTo: true)
          .get();
      final keys = snap.docs
          .map((d) => AdminApiKey.fromMap(d.data(), d.id))
          .toList();
      if (keys.isEmpty) {
        _toast('No active keys to test.');
        return;
      }
      final results = <String, int>{};
      for (final k in keys) {
        results[k.name] = await pingKeyStatus(
          provider: k.provider,
          baseUrl: k.baseUrl,
          apiKey: k.key,
          model: k.model,
        );
      }
      if (!mounted) return;
      final ok = results.values.where((s) => s == 200).length;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Health check'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$ok of ${results.length} active keys healthy (HTTP 200).',
                ),
                const SizedBox(height: 12),
                for (final e in results.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Icon(
                          e.value == 200
                              ? Icons.check_circle
                              : Icons.error_outline,
                          size: 16,
                          color: e.value == 200
                              ? const Color(0xFF0F766E)
                              : Colors.redAccent,
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(e.key)),
                        Text(e.value == 200 ? 'OK' : 'HTTP ${e.value}'),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _testingAll = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
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
                    'AI Configuration',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                  Text('Manage Gemini API keys used by the mobile app.'),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: _testingAll ? null : _testAll,
              icon: _testingAll
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.health_and_safety_outlined),
              label: Text(_testingAll ? 'Testing…' : 'Test all active'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.black12,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _TabButton('Add key', _tab == 0, () => setState(() => _tab = 0)),
              _TabButton('Manage', _tab == 1, () => setState(() => _tab = 1)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _tab == 0
              ? _AddKeyForm(
                  onSaved: () {
                    _toast('Key added. Switch to Manage to edit it.');
                    setState(() => _tab = 1);
                  },
                )
              : Card(
                  clipBehavior: Clip.antiAlias,
                  child: const AdminApiKeysScreen(),
                ),
        ),
      ],
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton(this.label, this.selected, this.onTap);
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: selected ? const Color(0xFF102F36) : Colors.black54,
          ),
        ),
      ),
    );
  }
}

/// Guided add-key form. Picking a provider auto-fills base URL + default model.
class _AddKeyForm extends StatefulWidget {
  const _AddKeyForm({required this.onSaved});
  final VoidCallback onSaved;

  @override
  State<_AddKeyForm> createState() => _AddKeyFormState();
}

class _AddKeyFormState extends State<_AddKeyForm> {
  final _name = TextEditingController();
  final _key = TextEditingController();
  final _baseUrl = TextEditingController();
  final _model = TextEditingController();
  String _provider = 'google';
  int _priority = 1;
  bool _busy = false;

  static const _providers = {
    'google': _ProviderPreset(
      label: 'Google AI Studio (Gemini)',
      baseUrl: 'https://generativelanguage.googleapis.com/v1beta',
      model: 'gemini-1.5-flash',
      hint: 'Key from aistudio.google.com/apikey',
    ),
    'openrouter': _ProviderPreset(
      label: 'OpenRouter',
      baseUrl: 'https://openrouter.ai/api/v1',
      model: 'openai/gpt-4o-mini',
      hint: 'Key from openrouter.ai/keys',
    ),
    'custom': _ProviderPreset(
      label: 'Custom (OpenAI-compatible)',
      baseUrl: 'https://',
      model: '',
      hint: 'Any /chat/completions endpoint',
    ),
  };

  void _onProviderChanged(String provider) {
    final p = _providers[provider]!;
    setState(() {
      _provider = provider;
      // Only auto-fill when the user hasn't hand-edited, or for non-custom.
      _baseUrl.text = p.baseUrl;
      if (p.model.isNotEmpty) _model.text = p.model;
    });
  }

  @override
  void initState() {
    super.initState();
    _onProviderChanged(_provider);
  }

  @override
  void dispose() {
    _name.dispose();
    _key.dispose();
    _baseUrl.dispose();
    _model.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final key = _key.text.trim();
    final name = _name.text.trim();
    final baseUrl = _baseUrl.text.trim();
    final model = _model.text.trim();
    if (name.isEmpty || key.isEmpty || baseUrl.isEmpty || model.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Name, key, base URL and model are required'),
          ),
        );
      }
      return;
    }
    setState(() => _busy = true);
    try {
      await FirebaseFirestore.instance.collection('admin_api_keys').add({
        'name': name,
        'key': key,
        'baseUrl': baseUrl,
        'model': model,
        'provider': _provider,
        'isActive': true,
        'priority': _priority,
        'usageCount': 0,
        'errorCount': 0,
        'addedBy': FirebaseAuth.instance.currentUser?.email ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      widget.onSaved();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preset = _providers[_provider]!;
    return Card(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: SizedBox(
          width: 460,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _provider,
                decoration: const InputDecoration(
                  labelText: 'Provider',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final e in _providers.entries)
                    DropdownMenuItem(value: e.key, child: Text(e.value.label)),
                ],
                onChanged: (v) => _onProviderChanged(v ?? 'google'),
              ),
              const SizedBox(height: 6),
              Text(
                preset.hint,
                style: const TextStyle(color: Colors.black45, fontSize: 12),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Key name',
                  border: OutlineInputBorder(),
                  hintText: 'e.g. Primary Gemini',
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _key,
                decoration: const InputDecoration(
                  labelText: 'API key',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _baseUrl,
                decoration: const InputDecoration(
                  labelText: 'Base URL (auto-filled by provider)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _model,
                decoration: const InputDecoration(
                  labelText: 'Model (auto-filled by provider)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Text('Priority'),
                  const SizedBox(width: 12),
                  DropdownButton<int>(
                    value: _priority,
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('1 (highest)')),
                      DropdownMenuItem(value: 2, child: Text('2')),
                      DropdownMenuItem(value: 3, child: Text('3 (lowest)')),
                    ],
                    onChanged: (v) => setState(() => _priority = v ?? 1),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: _busy ? null : _save,
                icon: _busy
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_outlined),
                label: const Text('Add key'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProviderPreset {
  const _ProviderPreset({
    required this.label,
    required this.baseUrl,
    required this.model,
    required this.hint,
  });
  final String label;
  final String baseUrl;
  final String model;
  final String hint;
}
