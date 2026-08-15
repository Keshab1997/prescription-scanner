import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:admin_api_key_manager/admin_api_key_manager.dart';

import 'keys_screen.dart';
import 'usage_screen.dart';
import 'settings_screen.dart';
import 'users_screen.dart';
import 'prescriptions_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _selected = 'Dashboard';

  static const _menu = [
    ('Dashboard', Icons.dashboard_rounded),
    ('AI Configuration', Icons.auto_awesome_rounded),
    ('Users', Icons.people_outline_rounded),
    ('Prescriptions', Icons.description_outlined),
    ('Usage', Icons.monitor_heart_outlined),
    ('Settings', Icons.settings_outlined),
  ];

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKey);
    super.dispose();
  }

  bool _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    // Digits 1–6 jump to the matching sidebar item.
    final digitKeys = {
      LogicalKeyboardKey.digit1: 0,
      LogicalKeyboardKey.numpad1: 0,
      LogicalKeyboardKey.digit2: 1,
      LogicalKeyboardKey.numpad2: 1,
      LogicalKeyboardKey.digit3: 2,
      LogicalKeyboardKey.numpad3: 2,
      LogicalKeyboardKey.digit4: 3,
      LogicalKeyboardKey.numpad4: 3,
      LogicalKeyboardKey.digit5: 4,
      LogicalKeyboardKey.numpad5: 4,
      LogicalKeyboardKey.digit6: 5,
      LogicalKeyboardKey.numpad6: 5,
    };
    final idx = digitKeys[event.logicalKey];
    if (idx != null && idx < _menu.length) {
      setState(() => _selected = _menu[idx].$1);
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      setState(() => _selected = 'Dashboard');
      return true;
    }
    return false;
  }

  Widget _body() {
    switch (_selected) {
      case 'AI Configuration':
        return const KeysScreen();
      case 'Users':
        return const UsersScreen();
      case 'Prescriptions':
        return const PrescriptionsScreen();
      case 'Usage':
        return const UsageScreen();
      case 'Settings':
        return const SettingsScreen();
      default:
        return const _Overview();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = fb.FirebaseAuth.instance.currentUser;
    final isNarrow = MediaQuery.of(context).size.width < 720;
    return Scaffold(
      body: Row(
        children: [
          if (!isNarrow || _selected != 'Dashboard')
            _Sidebar(
              selected: _selected,
              user: user,
              menu: _menu,
              onSelect: (label) => setState(() => _selected = label),
            ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(isNarrow ? 16 : 28),
              child: _body(),
            ),
          ),
        ],
      ),
      bottomNavigationBar: isNarrow ? _BottomNav(
        selected: _selected,
        menu: _menu,
        onSelect: (label) => setState(() => _selected = label),
      ) : null,
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.selected,
    required this.user,
    required this.menu,
    required this.onSelect,
  });
  final String selected;
  final fb.User? user;
  final List<(String, IconData)> menu;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 230,
      color: const Color(0xFF102F36),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Prescription Scanner',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          const Text('Admin Console', style: TextStyle(color: Colors.white60)),
          const SizedBox(height: 32),
          for (var i = 0; i < menu.length; i++)
            _MenuItem(
              menu[i].$1,
              menu[i].$2,
              selected == menu[i].$1,
              i,
              onTap: () => onSelect(menu[i].$1),
            ),
          const Spacer(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.logout, color: Colors.white60),
            title: const Text('Sign out',
                style: TextStyle(color: Colors.white60)),
            onTap: () => fb.FirebaseAuth.instance.signOut(),
          ),
          if (user?.email != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(user!.email!,
                  style: const TextStyle(color: Colors.white38, fontSize: 12)),
            ),
        ],
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.selected,
    required this.menu,
    required this.onSelect,
  });
  final String selected;
  final List<(String, IconData)> menu;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: menu.indexWhere((e) => e.$1 == selected).clamp(0, menu.length - 1),
      onTap: (i) => onSelect(menu[i].$1),
      type: BottomNavigationBarType.fixed,
      items: [
        for (final (label, icon) in menu)
          BottomNavigationBarItem(icon: Icon(icon), label: label),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem(this.label, this.icon, this.selected, this.index,
      {this.onTap});
  final String label;
  final IconData icon;
  final bool selected;
  final int index;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 7),
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: selected ? Colors.white12 : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? Colors.white : Colors.white60, size: 19),
            const SizedBox(width: 10),
            Text(label,
                style: TextStyle(color: selected ? Colors.white : Colors.white60)),
            const Spacer(),
            Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('${index + 1}',
                  style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Overview extends StatefulWidget {
  const _Overview();

  @override
  State<_Overview> createState() => _OverviewState();
}

class _OverviewState extends State<_Overview> {
  int _totalExtractions = 0;
  int _failedExtractions = 0;
  bool _statsLoading = true;
  String? _statsError;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final profiles = await FirebaseFirestore.instance
          .collection('profiles')
          .count()
          .get();
      final failures = await FirebaseFirestore.instance
          .collection('api_error_logs')
          .count()
          .get();
      if (mounted) {
        setState(() {
          _totalExtractions = profiles.count ?? 0;
          _failedExtractions = failures.count ?? 0;
          _statsLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statsError = e.toString().replaceFirst('Exception: ', '');
          _statsLoading = false;
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
                  Text('Operations overview',
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                  Text('Live metrics from the key pool and extraction logs.'),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF0F766E).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _LiveDot(),
                  SizedBox(width: 6),
                  Text('Live',
                      style: TextStyle(
                          color: Color(0xFF0F766E), fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('admin_api_keys')
              .snapshots(),
          builder: (context, snap) {
            if (snap.hasError) {
              return _StateCard(
                  icon: Icons.error_outline,
                  message: 'Failed to load keys: ${snap.error}');
            }
            var total = 0, active = 0;
            if (snap.hasData) {
              for (final d in snap.data!.docs) {
                final m = d.data() as Map<String, dynamic>;
                total++;
                if (m['isActive'] == true) active++;
              }
            }
            final cards = [
              _MetricCard('Total keys', '$total',
                  icon: Icons.vpn_key_rounded, loading: !snap.hasData),
              _MetricCard('Active keys', '$active',
                  icon: Icons.check_circle_outline, loading: !snap.hasData),
              _MetricCard('Total AI requests', '$_totalExtractions',
                  icon: Icons.call_made_rounded, loading: _statsLoading),
              _MetricCard('Error count', '$_failedExtractions',
                  icon: Icons.error_outline, loading: _statsLoading),
            ];
            return isNarrow
                ? Column(children: cards)
                : Row(children: cards);
          },
        ),
        if (_statsError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Stats source: $_statsError',
                style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
          ),
        const SizedBox(height: 18),
        Expanded(
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Recent activity',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
                const Divider(height: 1),
                Expanded(child: _RecentActivityFeed()),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RecentActivityFeed extends StatelessWidget {
  const _RecentActivityFeed();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('api_error_logs')
          .orderBy('timestamp', descending: true)
          .limit(25)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return _StateCard(
              icon: Icons.error_outline,
              message: 'Failed to load activity: ${snap.error}');
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const _StateCard(
            icon: Icons.check_circle_outline,
            message: 'No errors logged yet. The pipeline is healthy.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: docs.length,
          separatorBuilder: (_, _) => const Divider(height: 1, indent: 16, endIndent: 16),
          itemBuilder: (context, i) {
            final log = ApiErrorLog.fromMap(
                docs[i].data() as Map<String, dynamic>, docs[i].id);
            final time = _formatTime(log.timestamp);
            return ListTile(
              leading: const CircleAvatar(
                radius: 16,
                backgroundColor: Color(0x12B91C1C),
                child: Icon(Icons.warning_amber_rounded,
                    size: 16, color: Color(0xFFB91C1C)),
              ),
              title: Text(
                '${log.keyName.isNotEmpty ? log.keyName : 'Unknown key'}'
                '${log.feature.isNotEmpty ? ' · ${log.feature}' : ''}',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              subtitle: Text(
                '${log.errorType}${log.statusCode != 0 ? ' (HTTP ${log.statusCode})' : ''}'
                ' — ${log.message}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
              trailing: Text(time,
                  style: const TextStyle(color: Colors.black45, fontSize: 12)),
            );
          },
        );
      },
    );
  }
}

class _LiveDot extends StatefulWidget {
  const _LiveDot();
  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: const Duration(seconds: 1))
        ..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _ctrl,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: Color(0xFF0F766E),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard(this.label, this.value,
      {this.icon, this.loading = false});
  final String label;
  final String value;
  final IconData? icon;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.of(context).size.width < 720;
    return SizedBox(
      width: isNarrow ? double.infinity : 190,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 16, color: Colors.black45),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(label,
                        style: const TextStyle(color: Colors.black54)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              loading
                  ? const SizedBox(
                      height: 26,
                      width: 40,
                      child:
                          LinearProgressIndicator(minHeight: 4),
                    )
                  : Text(value,
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: Colors.black38),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}

String _formatTime(DateTime t) {
  final now = DateTime.now();
  final diff = now.difference(t);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}
