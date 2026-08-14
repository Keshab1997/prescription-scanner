import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart' show adminApiSecret;

/// Read-only, audit-safe prescription directory. Shows extraction metadata only
/// (status, provider, confidence, error, date) — never image bytes or storage
/// paths, which stay private per AGENTS.md. Data comes from the secret-gated
/// `admin_list_prescriptions` Supabase RPC.
class PrescriptionsScreen extends StatefulWidget {
  const PrescriptionsScreen({super.key});

  @override
  State<PrescriptionsScreen> createState() => _PrescriptionsScreenState();
}

class _PrescriptionsScreenState extends State<PrescriptionsScreen> {
  List<RxPrescription> _items = const [];
  bool _loading = true;
  String? _error;
  int _total = 0;
  int _completed = 0;
  int _failed = 0;

  String? _statusFilter;
  final _statuses = const [
    'uploaded',
    'queued',
    'processing',
    'completed',
    'needs_review',
    'failed'
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      if (adminApiSecret.isEmpty) {
        throw Exception(
            'ADMIN_API_SECRET is not set. Re-run with --dart-define=ADMIN_API_SECRET=...');
      }
      final res = await Supabase.instance.client.rpc(
        'admin_list_prescriptions',
        params: {
          'p_secret': adminApiSecret,
          'p_status': _statusFilter,
          'p_limit': 200,
        },
      );
      final list = (res as List)
          .map((e) => RxPrescription.fromMap(e as Map<String, dynamic>))
          .toList();
      if (mounted) {
        setState(() {
          _items = list;
          _total = list.length;
          _completed = list.where((p) => p.status == 'completed').length;
          _failed = list.where((p) => p.status == 'failed').length;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'completed':
        return const Color(0xFF0F766E);
      case 'failed':
        return const Color(0xFFB91C1C);
      case 'needs_review':
        return const Color(0xFFB45309);
      default:
        return Colors.black54;
    }
  }

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
                  Text('AI extraction records (metadata only — images stay private).'),
                ],
              ),
            ),
            IconButton(
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
            ),
          ],
        ),
        const SizedBox(height: 14),
        isNarrow
            ? Column(
                children: [
                  _StatChip('Shown', '$_total'),
                  _StatChip('Completed', '$_completed'),
                  _StatChip('Failed', '$_failed'),
                ],
              )
            : Row(
                children: [
                  _StatChip('Shown', '$_total'),
                  const SizedBox(width: 12),
                  _StatChip('Completed', '$_completed'),
                  const SizedBox(width: 12),
                  _StatChip('Failed', '$_failed'),
                ],
              ),
        const SizedBox(height: 14),
        Row(
          children: [
            const Text('Filter: ', style: TextStyle(color: Colors.black54)),
            DropdownButton<String?>(
              value: _statusFilter,
              hint: const Text('All'),
              items: [
                const DropdownMenuItem<String?>(
                    value: null, child: Text('All')),
                for (final s in _statuses)
                  DropdownMenuItem<String?>(value: s, child: Text(s)),
              ],
              onChanged: (v) {
                setState(() => _statusFilter = v);
                _load();
              },
            ),
          ],
        ),
        const SizedBox(height: 14),
        Expanded(
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: _body(),
          ),
        ),
      ],
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 36, color: Colors.black38),
              const SizedBox(height: 12),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54)),
            ],
          ),
        ),
      );
    }
    if (_items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('No prescriptions match this filter.',
              style: TextStyle(color: Colors.black54)),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _items.length,
      separatorBuilder: (_, _) => const Divider(height: 1, indent: 16, endIndent: 16),
      itemBuilder: (context, i) {
        final p = _items[i];
        final name = p.displayName.isNotEmpty
            ? p.displayName
            : (p.userEmail.isEmpty ? 'Unknown' : p.userEmail);
        return ListTile(
          title: Text(name,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(
            '${p.provider ?? '—'} · ${p.model ?? '—'}'
            '${p.errorCode != null ? ' · ${p.errorCode}' : ''}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (p.overallConfidence != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    '${(p.overallConfidence! * 100).toInt()}%',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _statusColor(p.status).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(p.status,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _statusColor(p.status))),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.black54, fontSize: 12)),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

class RxPrescription {
  const RxPrescription({
    required this.id,
    required this.userEmail,
    required this.displayName,
    required this.status,
    required this.provider,
    required this.model,
    required this.overallConfidence,
    required this.errorCode,
    required this.createdAt,
    required this.processedAt,
  });
  final String id;
  final String userEmail;
  final String displayName;
  final String status;
  final String? provider;
  final String? model;
  final double? overallConfidence;
  final String? errorCode;
  final DateTime createdAt;
  final DateTime? processedAt;

  factory RxPrescription.fromMap(Map<String, dynamic> m) {
    final c = m['overall_confidence'];
    return RxPrescription(
      id: m['id'] as String? ?? '',
      userEmail: m['user_email'] as String? ?? '',
      displayName: m['display_name'] as String? ?? '',
      status: m['status'] as String? ?? 'uploaded',
      provider: m['provider'] as String?,
      model: m['model'] as String?,
      overallConfidence: c is num ? c.toDouble() : null,
      errorCode: m['error_code'] as String?,
      createdAt: m['created_at'] == null
          ? DateTime.now()
          : DateTime.parse(m['created_at'] as String),
      processedAt: m['processed_at'] == null
          ? null
          : DateTime.parse(m['processed_at'] as String),
    );
  }
}
