import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'keys_screen.dart';
import 'placeholder_screen.dart';

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

  Widget _body() {
    switch (_selected) {
      case 'AI Configuration':
        return const KeysScreen();
      case 'Users':
        return const PlaceholderScreen(title: 'Users');
      case 'Prescriptions':
        return const PlaceholderScreen(title: 'Prescriptions');
      case 'Usage':
        return const PlaceholderScreen(title: 'Usage');
      case 'Settings':
        return const PlaceholderScreen(title: 'Settings');
      default:
        return const _Overview();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      body: Row(
        children: [
          Container(
            width: 230,
            color: const Color(0xFF102F36),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Prescription Scanner',
                    style:
                        TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                const Text('Admin Console',
                    style: TextStyle(color: Colors.white60)),
                const SizedBox(height: 32),
                for (final (label, icon) in _menu)
                  _MenuItem(
                    label,
                    icon,
                    _selected == label,
                    onTap: () => setState(() => _selected = label),
                  ),
                const Spacer(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.logout, color: Colors.white60),
                  title: const Text('Sign out',
                      style: TextStyle(color: Colors.white60)),
                  onTap: () => FirebaseAuth.instance.signOut(),
                ),
                if (user?.email != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(user!.email!,
                        style: const TextStyle(color: Colors.white38, fontSize: 12)),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: _body(),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem(this.label, this.icon, this.selected, {this.onTap});
  final String label;
  final IconData icon;
  final bool selected;
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
          ],
        ),
      ),
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Operations overview',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        const Text('Live metrics from the admin_api_keys pool.'),
        const SizedBox(height: 24),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('admin_api_keys')
              .snapshots(),
          builder: (context, snap) {
            var total = 0, active = 0, errors = 0, usage = 0;
            if (snap.hasData) {
              for (final d in snap.data!.docs) {
                final m = d.data() as Map<String, dynamic>;
                total++;
                if (m['isActive'] == true) active++;
                errors += (m['errorCount'] as int? ?? 0);
                usage += (m['usageCount'] as int? ?? 0);
              }
            }
            return Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                _MetricCard('Total keys', '$total'),
                _MetricCard('Active keys', '$active'),
                _MetricCard('Total AI requests', '$usage'),
                _MetricCard('Error count', '$errors'),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        const Expanded(
          child: Card(
            child: Center(
              child: Text('Recent activity will appear here.'),
            ),
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 10),
              Text(value,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }
}
