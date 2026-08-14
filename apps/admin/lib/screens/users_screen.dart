import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart' show adminApiSecret;

/// Live user directory pulled from Supabase via the `admin_list_users` RPC.
/// The admin app authenticates with Firebase, not Supabase, so it cannot use
/// RLS — the RPC gates access on a shared admin secret passed at call time.
class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  List<AppUser> _users = const [];
  bool _loading = true;
  String? _error;
  int _total = 0;
  int _active = 0;
  int _blocked = 0;

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
      final res = await Supabase.instance.client
          .rpc('admin_list_users', params: {'p_secret': adminApiSecret});
      final list = (res as List)
          .map((e) => AppUser.fromMap(e as Map<String, dynamic>))
          .toList();
      if (mounted) {
        setState(() {
          _users = list;
          _total = list.length;
          _active = list.where((u) => u.status == 'active').length;
          _blocked = list.where((u) => u.status == 'blocked').length;
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
                  Text('Users',
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                  Text('Supabase accounts using the mobile app.'),
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
        const SizedBox(height: 16),
        if (isNarrow)
          Column(
            children: [
              _StatChip('Total', '$_total'),
              _StatChip('Active', '$_active'),
              _StatChip('Blocked', '$_blocked'),
            ],
          )
        else
          Row(
            children: [
              _StatChip('Total', '$_total'),
              const SizedBox(width: 12),
              _StatChip('Active', '$_active'),
              const SizedBox(width: 12),
              _StatChip('Blocked', '$_blocked'),
            ],
          ),
        const SizedBox(height: 16),
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
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
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
    if (_users.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('No users yet.',
              style: TextStyle(color: Colors.black54)),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _users.length,
      separatorBuilder: (_, _) => const Divider(height: 1, indent: 16, endIndent: 16),
      itemBuilder: (context, i) {
        final u = _users[i];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: const Color(0xFF0F766E).withValues(alpha: 0.12),
            child: Text(
              (u.displayName.isNotEmpty ? u.displayName : u.email)
                      .substring(0, 1)
                      .toUpperCase(),
              style: const TextStyle(
                  color: Color(0xFF0F766E), fontWeight: FontWeight.w700),
            ),
          ),
          title: Text(
            u.displayName.isNotEmpty ? u.displayName : (u.email.isEmpty ? 'Unknown' : u.email),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(u.email.isEmpty ? 'no email' : u.email),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: u.status == 'blocked'
                      ? const Color(0xFFB91C1C).withValues(alpha: 0.12)
                      : const Color(0xFF0F766E).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(u.status,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: u.status == 'blocked'
                            ? const Color(0xFFB91C1C)
                            : const Color(0xFF0F766E))),
              ),
              if (u.role != 'user') ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(u.role,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ],
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

class AppUser {
  const AppUser({
    required this.id,
    required this.displayName,
    required this.email,
    required this.role,
    required this.status,
    required this.createdAt,
  });
  final String id;
  final String displayName;
  final String email;
  final String role;
  final String status;
  final DateTime createdAt;

  factory AppUser.fromMap(Map<String, dynamic> m) {
    return AppUser(
      id: m['id'] as String? ?? '',
      displayName: m['display_name'] as String? ?? '',
      email: m['email'] as String? ?? '',
      role: m['role'] as String? ?? 'user',
      status: m['status'] as String? ?? 'active',
      createdAt: m['created_at'] == null
          ? DateTime.now()
          : DateTime.parse(m['created_at'] as String),
    );
  }
}
