import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:admin_api_key_manager/admin_api_key_manager.dart';

import '../main.dart' show adminApiSecret;

/// Real usage analytics. Two real failure sources are merged:
///  • `api_error_logs` (Firestore) — failures from the mobile app's direct
///    Gemini path via the key-manager (auto-retry stats live here).
///  • `prescriptions` (Supabase) — extraction failures from the Edge Function
///    flow (status = 'failed', error_code set). This is where real failures
///    currently land, so it makes the page meaningful.
class UsageScreen extends StatelessWidget {
  const UsageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.of(context).size.width < 720;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Usage',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        const Text('AI request health from live error logs and extraction failures.'),
        const SizedBox(height: 24),
        Expanded(
          child: _UsageBody(isNarrow: isNarrow),
        ),
      ],
    );
  }
}

class _UsageBody extends StatefulWidget {
  const _UsageBody({required this.isNarrow});
  final bool isNarrow;

  @override
  State<_UsageBody> createState() => _UsageBodyState();
}

class _UsageBodyState extends State<_UsageBody> {
  List<Map<String, dynamic>> _rxFailures = const [];
  bool _rxLoading = true;
  String? _rxError;

  @override
  void initState() {
    super.initState();
    _loadRxFailures();
  }

  Future<void> _loadRxFailures() async {
    if (adminApiSecret.isEmpty) {
      if (mounted) setState(() => _rxError = 'ADMIN_API_SECRET not set.');
      return;
    }
    try {
      final res = await Supabase.instance.client.rpc(
        'admin_prescription_failures',
        params: {'p_secret': adminApiSecret, 'p_limit': 200},
      );
      if (mounted) {
        setState(() {
          _rxFailures = (res as List)
              .map((e) => e as Map<String, dynamic>)
              .toList();
          _rxLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _rxError = e.toString().replaceFirst('Exception: ', '');
          _rxLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('api_error_logs')
          .orderBy('timestamp', descending: true)
          .limit(200)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return const Center(child: Text('Failed to load usage data.'));
        }
        if (!snap.hasData || _rxLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final logs = snap.data!.docs
            .map((d) =>
                ApiErrorLog.fromMap(d.data() as Map<String, dynamic>, d.id))
            .toList();

        final total = logs.length + _rxFailures.length;
        final retried = logs.where((l) => l.retried).length;
        final recovered = logs.where((l) => l.retried && l.retrySuccess).length;

        // Merge failures-by-type from both sources.
        final byType = <String, int>{};
        for (final l in logs) {
          final type = l.errorType.isNotEmpty ? l.errorType : 'unknown';
          byType[type] = (byType[type] ?? 0) + 1;
        }
        for (final f in _rxFailures) {
          final code = (f['error_code'] as String?)?.isNotEmpty == true
              ? f['error_code'] as String
              : 'unknown';
          byType[code] = (byType[code] ?? 0) + 1;
        }

        // Key-manager failures by key name.
        final byKey = <String, int>{};
        for (final l in logs) {
          final key = l.keyName.isNotEmpty ? l.keyName : 'Unknown key';
          byKey[key] = (byKey[key] ?? 0) + 1;
        }

        final topTypes = byType.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final topKeys = byKey.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        final stats = [
          _Stat('Total failures', '$total'),
          _Stat('Extraction failures', '${_rxFailures.length}'),
          _Stat('Auto-retried (key pool)', '$retried'),
          _Stat('Recovered after retry', '$recovered'),
        ];

        final children = [
          if (_rxError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text('Extraction-failure source: $_rxError',
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
            ),
          widget.isNarrow
              ? Column(
                  children: stats
                      .map((s) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _StatCard(s)))
                      .toList())
              : Row(
                  children: stats
                      .map((s) => Expanded(child: _StatCard(s)))
                      .toList()),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: _BreakdownList(
                      title: 'Failures by error type',
                      entries: topTypes,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: _BreakdownList(
                      title: 'Failures by key (key pool)',
                      entries: topKeys,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ];

        return widget.isNarrow
            ? ListView(children: children)
            : Column(children: children);
      },
    );
  }
}

class _Stat {
  const _Stat(this.label, this.value);
  final String label;
  final String value;
}

class _StatCard extends StatelessWidget {
  const _StatCard(this.stat);
  final _Stat stat;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(stat.label, style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 10),
            Text(stat.value,
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

class _BreakdownList extends StatelessWidget {
  const _BreakdownList({required this.title, required this.entries});
  final String title;
  final List<MapEntry<String, int>> entries;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(title,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ),
        const Divider(height: 1),
        Expanded(
          child: entries.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No data yet.',
                        style: TextStyle(color: Colors.black54)),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: entries.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, indent: 16, endIndent: 16),
                  itemBuilder: (context, i) {
                    final e = entries[i];
                    return ListTile(
                      title: Text(e.key, style: const TextStyle(fontSize: 14)),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F766E).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('${e.value}',
                            style: const TextStyle(
                                color: Color(0xFF0F766E),
                                fontWeight: FontWeight.w700)),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
