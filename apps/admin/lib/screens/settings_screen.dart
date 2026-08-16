import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Admin-managed runtime configuration.
///
/// `app_settings/1` is consumed by the mobile app for scan limits and service
/// availability. `admin_contacts/primary` remains the private recovery/alert
/// contact record. Both documents are created with merge semantics, so a fresh
/// Firebase project no longer needs either document to be seeded manually.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _dailyLimit = TextEditingController(text: '3');
  final _email = TextEditingController();
  final _phone = TextEditingController();

  bool _loading = true;
  bool _savingApp = false;
  bool _savingContact = false;
  bool _aiEnabled = true;
  bool _maintenanceMode = false;
  String? _loadError;
  String? _appMessage;
  String? _contactMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _dailyLimit.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final results = await Future.wait([
        FirebaseFirestore.instance.collection('app_settings').doc('1').get(),
        FirebaseFirestore.instance
            .collection('admin_contacts')
            .doc('primary')
            .get(),
      ]);
      final app = results[0].data() ?? const <String, dynamic>{};
      final contact = results[1].data() ?? const <String, dynamic>{};
      if (!mounted) return;
      setState(() {
        _dailyLimit.text = _asInt(app['daily_limit'], fallback: 3).toString();
        _aiEnabled = app['ai_enabled'] is bool
            ? app['ai_enabled'] as bool
            : true;
        _maintenanceMode = app['maintenance_mode'] == true;
        _email.text = contact['email']?.toString() ?? '';
        _phone.text = contact['phone']?.toString() ?? '';
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = _friendlyError(error);
      });
    }
  }

  Future<void> _saveAppSettings() async {
    final dailyLimit = int.tryParse(_dailyLimit.text.trim());
    if (dailyLimit == null || dailyLimit < 0 || dailyLimit > 1000) {
      setState(() {
        _appMessage = 'Daily limit must be a whole number from 0 to 1000.';
      });
      return;
    }

    setState(() {
      _savingApp = true;
      _appMessage = null;
    });
    try {
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();
      batch.set(firestore.collection('app_settings').doc('1'), {
        'daily_limit': dailyLimit,
        'ai_enabled': _aiEnabled,
        'maintenance_mode': _maintenanceMode,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      batch.set(firestore.collection('admin_audit_logs').doc(), {
        'admin_uid': FirebaseAuth.instance.currentUser!.uid,
        'action': 'app_settings_updated',
        'target_id': 'app_settings/1',
        'changed_fields': ['daily_limit', 'ai_enabled', 'maintenance_mode'],
        'created_at': FieldValue.serverTimestamp(),
      });
      await batch.commit();
      if (mounted) setState(() => _appMessage = 'App settings saved.');
    } catch (error) {
      if (mounted) {
        setState(() => _appMessage = 'Save failed: ${_friendlyError(error)}');
      }
    } finally {
      if (mounted) setState(() => _savingApp = false);
    }
  }

  Future<void> _saveContact() async {
    final email = _email.text.trim();
    final phone = _phone.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _contactMessage = 'Enter a valid admin email.');
      return;
    }

    setState(() {
      _savingContact = true;
      _contactMessage = null;
    });
    try {
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();
      batch.set(
        firestore.collection('admin_contacts').doc('primary'),
        {
          'email': email,
          'phone': phone,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      batch.set(firestore.collection('admin_audit_logs').doc(), {
        'admin_uid': FirebaseAuth.instance.currentUser!.uid,
        'action': 'admin_contact_updated',
        'target_id': 'admin_contacts/primary',
        'changed_fields': ['email', 'phone'],
        'created_at': FieldValue.serverTimestamp(),
      });
      await batch.commit();
      if (mounted) setState(() => _contactMessage = 'Admin contact saved.');
    } catch (error) {
      if (mounted) {
        setState(
          () => _contactMessage = 'Save failed: ${_friendlyError(error)}',
        );
      }
    } finally {
      if (mounted) setState(() => _savingContact = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Settings',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                  Text('Control the mobile app and admin contact details.'),
                ],
              ),
            ),
            IconButton(
              onPressed: _loading ? null : _load,
              tooltip: 'Refresh settings',
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Expanded(child: _body()),
      ],
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Center(
        child: _ErrorState(message: _loadError!, onRetry: _load),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final appCard = _AppSettingsCard(
          dailyLimit: _dailyLimit,
          aiEnabled: _aiEnabled,
          maintenanceMode: _maintenanceMode,
          saving: _savingApp,
          message: _appMessage,
          onAiChanged: (value) => setState(() => _aiEnabled = value),
          onMaintenanceChanged: (value) =>
              setState(() => _maintenanceMode = value),
          onSave: _saveAppSettings,
        );
        final contactCard = _ContactCard(
          email: _email,
          phone: _phone,
          saving: _savingContact,
          message: _contactMessage,
          onSave: _saveContact,
        );

        final controls = constraints.maxWidth >= 900
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: appCard),
                  const SizedBox(width: 18),
                  Expanded(child: contactCard),
                ],
              )
            : Column(
                children: [appCard, const SizedBox(height: 18), contactCard],
              );

        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            children: [
              controls,
              const SizedBox(height: 18),
              const _AuditLogCard(),
            ],
          ),
        );
      },
    );
  }
}

class _AppSettingsCard extends StatelessWidget {
  const _AppSettingsCard({
    required this.dailyLimit,
    required this.aiEnabled,
    required this.maintenanceMode,
    required this.saving,
    required this.message,
    required this.onAiChanged,
    required this.onMaintenanceChanged,
    required this.onSave,
  });

  final TextEditingController dailyLimit;
  final bool aiEnabled;
  final bool maintenanceMode;
  final bool saving;
  final String? message;
  final ValueChanged<bool> onAiChanged;
  final ValueChanged<bool> onMaintenanceChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.tune_rounded, color: Color(0xFF0F766E)),
                SizedBox(width: 10),
                Text(
                  'Mobile app controls',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Saved to Firestore app_settings/1 and applied to verified users.',
              style: TextStyle(color: Colors.black54, fontSize: 12),
            ),
            const SizedBox(height: 20),
            TextField(
              key: const ValueKey('daily-scan-limit'),
              controller: dailyLimit,
              enabled: !saving,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Daily scan limit per user',
                helperText: 'Use 0 to temporarily stop all daily scans.',
                prefixIcon: Icon(Icons.speed_rounded),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            SwitchListTile.adaptive(
              key: const ValueKey('ai-enabled-switch'),
              contentPadding: EdgeInsets.zero,
              title: const Text('AI scanning enabled'),
              subtitle: const Text(
                'Allow users to process new prescription scans.',
              ),
              value: aiEnabled,
              onChanged: saving ? null : onAiChanged,
            ),
            const Divider(),
            SwitchListTile.adaptive(
              key: const ValueKey('maintenance-mode-switch'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Maintenance mode'),
              subtitle: const Text(
                'Show the service as temporarily unavailable.',
              ),
              value: maintenanceMode,
              onChanged: saving ? null : onMaintenanceChanged,
            ),
            if (message != null) ...[
              const SizedBox(height: 10),
              _StatusText(message!),
            ],
            const SizedBox(height: 18),
            FilledButton.icon(
              key: const ValueKey('save-app-settings'),
              onPressed: saving ? null : onSave,
              icon: saving
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(saving ? 'Saving…' : 'Save app settings'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.email,
    required this.phone,
    required this.saving,
    required this.message,
    required this.onSave,
  });

  final TextEditingController email;
  final TextEditingController phone;
  final bool saving;
  final String? message;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.admin_panel_settings_outlined),
                SizedBox(width: 10),
                Text(
                  'Primary admin contact',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: email,
              enabled: !saving,
              decoration: const InputDecoration(
                labelText: 'Admin email',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 14),
            TextField(
              controller: phone,
              enabled: !saving,
              decoration: const InputDecoration(
                labelText: 'Admin phone',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
            if (message != null) ...[
              const SizedBox(height: 10),
              _StatusText(message!),
            ],
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: saving ? null : onSave,
              icon: saving
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(saving ? 'Saving…' : 'Save contact'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuditLogCard extends StatelessWidget {
  const _AuditLogCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.history_rounded, color: Color(0xFF0F766E)),
                SizedBox(width: 10),
                Text(
                  'Recent admin activity',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 14),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('admin_audit_logs')
                  .orderBy('created_at', descending: true)
                  .limit(20)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Text(
                    'Could not load audit activity.',
                    style: TextStyle(color: Colors.redAccent),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final documents = snapshot.data!.docs;
                if (documents.isEmpty) {
                  return const Text(
                    'No admin changes recorded yet.',
                    style: TextStyle(color: Colors.black54),
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: documents.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final data = documents[index].data();
                    final timestamp = data['created_at'];
                    final date = timestamp is Timestamp
                        ? timestamp.toDate().toLocal()
                        : null;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: const Icon(Icons.verified_user_outlined),
                      title: Text(
                        _auditActionLabel(data['action']?.toString()),
                      ),
                      subtitle: Text(data['target_id']?.toString() ?? ''),
                      trailing: date == null
                          ? null
                          : Text(
                              '${date.day.toString().padLeft(2, '0')}/'
                              '${date.month.toString().padLeft(2, '0')} '
                              '${date.hour.toString().padLeft(2, '0')}:'
                              '${date.minute.toString().padLeft(2, '0')}',
                              style: const TextStyle(
                                color: Colors.black45,
                                fontSize: 11,
                              ),
                            ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

String _auditActionLabel(String? action) {
  return switch (action) {
    'user_blocked' => 'User blocked',
    'user_unblocked' => 'User unblocked',
    'app_settings_updated' => 'App settings updated',
    'admin_contact_updated' => 'Admin contact updated',
    _ => action ?? 'Admin action',
  };
}

class _StatusText extends StatelessWidget {
  const _StatusText(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    final failed =
        message.toLowerCase().contains('fail') ||
        message.toLowerCase().contains('valid') ||
        message.toLowerCase().contains('must');
    return Text(
      message,
      style: TextStyle(
        color: failed ? Colors.redAccent : const Color(0xFF0F766E),
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, size: 42, color: Colors.redAccent),
        const SizedBox(height: 10),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      ],
    );
  }
}

int _asInt(Object? value, {required int fallback}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

String _friendlyError(Object error) {
  final message = error.toString();
  if (message.contains('permission-denied')) {
    return 'Permission denied. Sign in with the verified admin account.';
  }
  return message.replaceFirst('Exception: ', '');
}
