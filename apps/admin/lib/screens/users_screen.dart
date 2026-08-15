import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Live user directory pulled from the Firestore `profiles` collection. Mobile
/// users are written a profile doc on signup, so this reflects every account.
/// Read access is gated by Firestore security rules (admin-only).
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
      final snapshot = await FirebaseFirestore.instance
          .collection('profiles')
          .orderBy('createdAt', descending: true)
          .get();
      final list = snapshot.docs
          .map((doc) => AppUser.fromMap(doc.data()))
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
                  Text('Accounts created from the mobile app.'),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 36, color: Colors.black38),
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.black54)),
          ],
        ),
      );
    }
    if (_users.isEmpty) {
      return const Center(
        child: Text('No users yet.', style: TextStyle(color: Colors.black54)),
      );
    }
    return ListView.separated(
      itemCount: _users.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final u = _users[index];
        final blocked = u.status == 'blocked';
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: blocked ? Colors.red.shade50 : Colors.teal.shade50,
            child: Text(
              (u.displayName.isNotEmpty ? u.displayName[0] : '?').toUpperCase(),
              style: TextStyle(
                color: blocked ? Colors.red : Colors.teal.shade700,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          title: Text(u.displayName.isEmpty ? 'Unnamed user' : u.displayName),
          subtitle: Text(u.email),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: blocked
                  ? Colors.red.withValues(alpha: 0.1)
                  : Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              blocked ? 'Blocked' : 'Active',
              style: TextStyle(
                color: blocked ? Colors.red : Colors.green.shade700,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
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
    final created = m['createdAt'];
    return AppUser(
      id: m['id'] as String? ?? '',
      displayName: m['displayName'] as String? ?? '',
      email: m['email'] as String? ?? '',
      role: m['role'] as String? ?? 'user',
      status: m['status'] as String? ?? 'active',
      createdAt: created is Timestamp
          ? created.toDate()
          : m['created_at'] == null
          ? DateTime.now()
          : DateTime.parse(m['created_at'] as String),
    );
  }
}
