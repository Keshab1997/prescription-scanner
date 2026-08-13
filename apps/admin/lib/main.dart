import 'package:flutter/material.dart';

void main() => runApp(const AdminApp());

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Prescription Scanner Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F766E)),
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
      ),
      home: const AdminFoundationScreen(),
    );
  }
}

class AdminFoundationScreen extends StatelessWidget {
  const AdminFoundationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          Container(
            width: 230,
            color: const Color(0xFF102F36),
            padding: const EdgeInsets.all(20),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Prescription Scanner',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                ),
                Text('Admin Console', style: TextStyle(color: Colors.white60)),
                SizedBox(height: 32),
                _MenuItem('Dashboard', Icons.dashboard_rounded, true),
                _MenuItem('AI Configuration', Icons.auto_awesome_rounded, false),
                _MenuItem('Users', Icons.people_outline_rounded, false),
                _MenuItem('Prescriptions', Icons.description_outlined, false),
                _MenuItem('Usage', Icons.monitor_heart_outlined, false),
                _MenuItem('Settings', Icons.settings_outlined, false),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Operations overview',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                  const Text('Admin foundation · Supabase integration comes in Phase 3'),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: const [
                      _MetricCard('Total users', '—'),
                      _MetricCard('Processed today', '—'),
                      _MetricCard('AI requests', '—'),
                      _MetricCard('Error count', '—'),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Expanded(
                    child: Card(
                      child: Center(
                        child: Text('Secure admin data will load through admin-only Edge Functions.'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem(this.label, this.icon, this.selected);
  final String label;
  final IconData icon;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
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
          Text(label, style: TextStyle(color: selected ? Colors.white : Colors.white60)),
        ],
      ),
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
              Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }
}
