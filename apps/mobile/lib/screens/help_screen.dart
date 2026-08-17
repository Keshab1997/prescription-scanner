import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prescription_scanner/legal/legal_copy.dart';
import 'package:prescription_scanner/theme.dart';
import 'package:prescription_scanner/widgets/about_card.dart';
import 'package:prescription_scanner/widgets/ui_animations.dart';

class HelpScreen extends ConsumerStatefulWidget {
  const HelpScreen({super.key});

  @override
  ConsumerState<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends ConsumerState<HelpScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
          children: [
            Entrance(
              child: Text(
                'Help & Support',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            const SizedBox(height: 6),
            Entrance(
              delay: const Duration(milliseconds: 80),
              child: const Text(
                'Everything you need to get the most out of Prescription Scanner.',
                style: TextStyle(color: AppColors.muted, fontSize: 14),
              ),
            ),
            const SizedBox(height: 24),
            Entrance(
              delay: const Duration(milliseconds: 120),
              child: const _SectionHeader(title: 'Frequently asked questions'),
            ),
            const SizedBox(height: 8),
            ..._faqItems.map(
              (item) => Entrance(
                delay: Duration(
                  milliseconds: 160 + _faqItems.indexOf(item) * 40,
                ),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _FaqCard(question: item.question, answer: item.answer),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Entrance(
              delay: const Duration(milliseconds: 400),
              child: const _SectionHeader(title: 'Privacy & security'),
            ),
            const SizedBox(height: 8),
            Entrance(
              delay: const Duration(milliseconds: 440),
              child: _InfoCard(
                icon: Icons.shield_outlined,
                children: [
                  const Text(
                    LegalCopy.privacySummary,
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    LegalCopy.medicalShort,
                    style: TextStyle(
                      color: AppColors.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      TextButton(
                        onPressed: () => context.push('/privacy'),
                        child: const Text('Privacy Policy'),
                      ),
                      TextButton(
                        onPressed: () => context.push('/terms'),
                        child: const Text('Terms'),
                      ),
                      TextButton(
                        onPressed: () => context.push('/disclaimer'),
                        child: const Text('Disclaimer'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Entrance(
              delay: const Duration(milliseconds: 480),
              child: const _SectionHeader(title: 'Contact & feedback'),
            ),
            const SizedBox(height: 8),
            Entrance(
              delay: const Duration(milliseconds: 520),
              child: _ContactCard(
                icon: Icons.mail_outline_rounded,
                title: 'Send us an email',
                subtitle: 'We usually respond within 1–2 business days.',
                buttonText: 'Contact support',
                onTap: () => _launchEmail(
                  context,
                  subject: 'Prescription Scanner support',
                ),
              ),
            ),
            const SizedBox(height: 12),
            Entrance(
              delay: const Duration(milliseconds: 560),
              child: _ContactCard(
                icon: Icons.bug_report_outlined,
                title: 'Report a problem',
                subtitle:
                    'Let us know what went wrong so we can improve the app.',
                buttonText: 'Report issue',
                onTap: () => _launchEmail(
                  context,
                  subject: 'Prescription Scanner bug report',
                ),
              ),
            ),
            const SizedBox(height: 24),
            Entrance(
              delay: const Duration(milliseconds: 600),
              child: const _SectionHeader(title: 'About'),
            ),
            const SizedBox(height: 8),
            Entrance(
              delay: const Duration(milliseconds: 640),
              child: const AboutCard(),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  void _launchEmail(BuildContext context, {required String subject}) {
    final email = 'keshabsarkar2018@gmail.com';
    Clipboard.setData(ClipboardData(text: email));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Email address copied: $email'),
        action: SnackBarAction(label: 'OK', onPressed: () {}),
      ),
    );
  }
}

// ─── Data ─────────────────────────────────────────────────────────

final _faqItems = <_FaqItemData>[
  _FaqItemData(
    question: 'How do I scan a prescription?',
    answer:
        'Tap the large scan button in the centre of the home screen. You can take a photo with your camera or pick an image from your gallery. The app automatically compresses and validates the image, then sends it for AI-powered transcription. The result appears in seconds.',
  ),
  _FaqItemData(
    question: 'Can I scan without creating an account?',
    answer:
        'Yes! You can try the app with 1 free scan per day right away — no sign-up needed. Just tap "Try a free scan without signing in" on the login screen or use the scan button on home as a guest.',
  ),
  _FaqItemData(
    question: 'How many free scans do I get after signing in?',
    answer:
        'After signing in (and verifying your email), you receive 3 free scans per day. If you first used the guest scan earlier that day, you still have 2 more remaining — so a guest scan + login unlock the full daily allowance.',
  ),
  _FaqItemData(
    question: 'I did not receive the verification email. What should I do?',
    answer:
        'First, check your Spam or Junk folder — many email filters accidentally redirect verification messages there. If you find it there, mark it as "Not spam" to ensure future messages reach your inbox. If it is still missing, go to Profile → Verify email to request a new link.',
  ),
  _FaqItemData(
    question: 'How does the AI transcription work?',
    answer:
        'The prepared image is sent to Google Gemini for transcription only. The app is not a medical device and does not diagnose or prescribe. Unclear text is left blank. The local image copy is deleted after processing; the structured list stays on this device.',
  ),
  _FaqItemData(
    question: 'Is my medical data stored in the cloud?',
    answer:
        'No. The prescription image itself is sent for AI transcription but is not saved by the app beyond the moment of processing. The structured transcription result stays on your device in an encrypted Hive store, scoped to your account (or guest namespace). Only anonymous usage counters (how many scans you used today) are synced to Firestore so the app can enforce daily limits.',
  ),
  _FaqItemData(
    question: 'How do I delete my scan results?',
    answer:
        'Open the History tab, find the prescription you want to remove, and tap the delete icon. You can also request full account deletion from Profile → Delete account, which removes your auth account and all local data. Guest scans can be cleared by deleting the app data or uninstalling.',
  ),
];

// ─── Widgets ──────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 17,
        color: AppColors.ink,
      ),
    );
  }
}

class _FaqItemData {
  const _FaqItemData({required this.question, required this.answer});
  final String question;
  final String answer;
}

class _FaqCard extends StatefulWidget {
  const _FaqCard({required this.question, required this.answer});
  final String question;
  final String answer;
  @override
  State<_FaqCard> createState() => _FaqCardState();
}

class _FaqCardState extends State<_FaqCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _controller;
  late final Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _toggle,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.help_outline,
                        size: 20,
                        color: AppColors.teal,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.question,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14.5,
                          ),
                        ),
                      ),
                      RotationTransition(
                        turns: _expandAnimation,
                        child: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 22,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    // Anchors the growing answer to the top. Uses 'alignment'
                    // (available on every Flutter version) instead of the
                    // deprecated SizeTransition.axisAlignment.
                    alignment: Alignment.topCenter,
                    child: _expanded
                        ? Padding(
                            padding: const EdgeInsets.only(top: 12, left: 30),
                            child: Text(
                              widget.answer,
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 13.5,
                                height: 1.5,
                              ),
                            ),
                          )
                        : const SizedBox(width: double.infinity),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({this.icon, required this.children});
  final IconData? icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 22, color: AppColors.teal),
            const SizedBox(height: 10),
          ],
          ...children,
        ],
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.tealSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 22, color: AppColors.teal),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: onTap,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.teal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              visualDensity: VisualDensity.compact,
            ),
            child: Text(buttonText, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
