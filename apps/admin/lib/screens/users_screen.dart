import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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
  String _query = '';
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('profiles')
          .orderBy('createdAt', descending: true)
          .get();
      final list = snapshot.docs
          .map((doc) => AppUser.fromMap(doc.data(), doc.id))
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

  Future<void> _setBlocked(AppUser user, bool blocked) async {
    if (user.id == FirebaseAuth.instance.currentUser?.uid) {
      _showMessage('You cannot block your own administrator account.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(blocked ? 'Block this user?' : 'Unblock this user?'),
        content: Text(
          blocked
              ? '${user.email} will lose scan/cloud access immediately and will be signed out when the app refreshes or restarts.'
              : '${user.email} will regain access after signing in again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(blocked ? 'Block user' : 'Unblock user'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final firestore = FirebaseFirestore.instance;
      final profile = firestore.collection('profiles').doc(user.id);
      final audit = firestore.collection('admin_audit_logs').doc();
      final batch = firestore.batch();
      batch.update(profile, {
        'status': blocked ? 'blocked' : 'active',
        'blockedReason': blocked
            ? 'Blocked by administrator'
            : FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      batch.set(audit, {
        'admin_uid': FirebaseAuth.instance.currentUser!.uid,
        'action': blocked ? 'user_blocked' : 'user_unblocked',
        'target_id': user.id,
        'changed_fields': ['status', 'blockedReason'],
        'created_at': FieldValue.serverTimestamp(),
      });
      await batch.commit();
      await _load();
      _showMessage(blocked ? 'User blocked.' : 'User unblocked.');
    } catch (error) {
      _showMessage('Could not update the user: $error');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
                  Text(
                    'Users',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                  ),
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
        if (isNarrow)
          Column(
            children: [
              _UserSearch(onChanged: (value) => setState(() => _query = value)),
              const SizedBox(height: 10),
              _StatusFilter(
                value: _statusFilter,
                onChanged: (value) => setState(() => _statusFilter = value),
              ),
            ],
          )
        else
          Row(
            children: [
              Expanded(
                child: _UserSearch(
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 190,
                child: _StatusFilter(
                  value: _statusFilter,
                  onChanged: (value) => setState(() => _statusFilter = value),
                ),
              ),
            ],
          ),
        const SizedBox(height: 12),
        Expanded(
          child: Card(clipBehavior: Clip.antiAlias, child: _body()),
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
    final normalizedQuery = _query.trim().toLowerCase();
    final visibleUsers = _users.where((user) {
      final matchesStatus =
          _statusFilter == 'all' || user.status == _statusFilter;
      final searchable = '${user.displayName} ${user.email}'.toLowerCase();
      return matchesStatus &&
          (normalizedQuery.isEmpty || searchable.contains(normalizedQuery));
    }).toList();
    if (visibleUsers.isEmpty) {
      return const Center(
        child: Text(
          'No matching users.',
          style: TextStyle(color: Colors.black54),
        ),
      );
    }
    return ListView.separated(
      itemCount: visibleUsers.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final u = visibleUsers[index];
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
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
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
              PopupMenuButton<String>(
                tooltip: 'User actions',
                onSelected: (value) {
                  if (value == 'block') _setBlocked(u, true);
                  if (value == 'unblock') _setBlocked(u, false);
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: blocked ? 'unblock' : 'block',
                    child: Row(
                      children: [
                        Icon(
                          blocked
                              ? Icons.lock_open_rounded
                              : Icons.block_rounded,
                          color: blocked ? Colors.green : Colors.redAccent,
                        ),
                        const SizedBox(width: 9),
                        Text(blocked ? 'Unblock user' : 'Block user'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _UserSearch extends StatelessWidget {
  const _UserSearch({required this.onChanged});
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      decoration: const InputDecoration(
        hintText: 'Search by name or email',
        prefixIcon: Icon(Icons.search_rounded),
        border: OutlineInputBorder(),
        isDense: true,
      ),
    );
  }
}

class _StatusFilter extends StatelessWidget {
  const _StatusFilter({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: const InputDecoration(
        labelText: 'Status',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      items: const [
        DropdownMenuItem(value: 'all', child: Text('All users')),
        DropdownMenuItem(value: 'active', child: Text('Active')),
        DropdownMenuItem(value: 'blocked', child: Text('Blocked')),
      ],
      onChanged: (selected) => onChanged(selected ?? 'all'),
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

  factory AppUser.fromMap(Map<String, dynamic> m, String documentId) {
    final created = m['createdAt'];
    return AppUser(
      id: documentId,
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
