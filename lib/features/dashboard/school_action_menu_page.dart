import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/colors.dart';
import 'school_follow_up_page.dart';
import 'school_sell_page.dart';
import 'school_visit_page.dart';
import 'collect_debt_page.dart';

class SchoolActionMenuPage extends StatelessWidget {
  const SchoolActionMenuPage({super.key, required this.school});

  final Map<String, dynamic> school;

  @override
  Widget build(BuildContext context) {
    final schoolName = school['name']?.toString() ?? 'School';
    final actionPoint = _deriveActionPoint();
    final focusAreas = List<String>.from(school['focusAreas'] ?? const []);

    return Scaffold(
      appBar: AppBar(
        title: const Text('School Actions'),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primaryGreen.withOpacity(0.95),
                  AppColors.primaryGreen.withOpacity(0.7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Selected School',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Text(
                  schoolName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Recommended action: $actionPoint',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _infoChip('County', school['county']?.toString()),
                    _infoChip('Phone', school['phone']?.toString()),
                    _infoChip('SOP', school['book_category']?.toString()),
                    _infoChip(
                      'Focus',
                      focusAreas.isEmpty ? 'General' : focusAreas.first,
                    ),
                  ],
                ),
              ],
            ),
          ),
                const SizedBox(height: 24),
          if (_hasPhoneNumber()) ...[
            _ActionCard(
              title: 'Message on WhatsApp',
              subtitle:
                  'Open WhatsApp with a prefilled message for this school.',
              icon: Icons.chat,
              color: Colors.green,
              onTap: () => _openWhatsApp(context),
            ),
            const SizedBox(height: 8),
          ],
          const Text(
            'Choose an action',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _ActionCard(
            title: 'Visit School',
            subtitle: 'Log a field visit, notes, and visit outcome.',
            icon: Icons.directions_walk,
            color: AppColors.primaryGreen,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SchoolVisitPage(school: school),
                ),
              );
            },
          ),
          _ActionCard(
            title: 'Follow Up',
            subtitle: 'Plan the next conversation and contact owner.',
            icon: Icons.follow_the_signs,
            color: AppColors.secondaryOrange,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SchoolFollowUpPage(school: school),
                ),
              );
            },
          ),
          _ActionCard(
            title: 'Sales Pipeline & Checkout',
            subtitle:
                'Update stage, next action, and create order when ready.',
            icon: Icons.point_of_sale,
            color: Colors.green,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SchoolSellPage(school: school),
                ),
              );
            },
          ),
          _ActionCard(
            title: 'Collect Debt',
            subtitle: 'Capture debt payments and record proof details.',
            icon: Icons.payments_outlined,
            color: AppColors.longhornMaroon,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CollectDebtPage(school: school),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _infoChip(String label, String? value) {
    return Chip(
      backgroundColor: Colors.white.withOpacity(0.16),
      side: BorderSide(color: Colors.white.withOpacity(0.2)),
      label: Text(
        '$label: ${value?.isNotEmpty == true ? value : "N/A"}',
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }

  String _deriveActionPoint() {
    final nextAction = school['nextAction']?.toString();
    if (nextAction != null && nextAction.isNotEmpty) return nextAction;

    final bookCategory = school['book_category']?.toString().toLowerCase();
    final focusAreas = List<String>.from(school['focusAreas'] ?? const []);
    if (bookCategory == 'book fund') return 'Sales Pipeline';
    if (focusAreas.isNotEmpty) return 'Follow Up';
    return 'Visit';
  }

  bool _hasPhoneNumber() {
    return _normalizedPhoneNumber() != null;
  }

  String? _normalizedPhoneNumber() {
    final rawPhone = school['phone']?.toString().trim();
    if (rawPhone == null || rawPhone.isEmpty) return null;

    final digits = rawPhone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digits.isEmpty) return null;

    if (digits.startsWith('+')) {
      return digits.substring(1);
    }
    if (digits.startsWith('0')) {
      return '254${digits.substring(1)}';
    }
    if (digits.startsWith('254')) {
      return digits;
    }
    return null;
  }

  Future<void> _openWhatsApp(BuildContext context) async {
    final phone = _normalizedPhoneNumber();
    if (phone == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No valid school phone number found.')),
      );
      return;
    }

    final schoolName = school['name']?.toString() ?? 'school';
    final actionPoint = _deriveActionPoint();
    final message =
        'Hello ${schoolName}, I am reaching out from Dehus regarding the $actionPoint action. '
        'Please let me know the best time to continue.';
    final deepLink = Uri.parse(
      'whatsapp://send?phone=$phone&text=${Uri.encodeComponent(message)}',
    );
    final webFallback = Uri.parse(
      'https://wa.me/$phone?text=${Uri.encodeComponent(message)}',
    );

    final openedDeepLink = await launchUrl(
      deepLink,
      mode: LaunchMode.externalApplication,
    );
    if (openedDeepLink) return;

    final openedWeb = await launchUrl(
      webFallback,
      mode: LaunchMode.externalApplication,
    );
    if (!openedWeb && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open WhatsApp.')),
      );
    }
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: color.withOpacity(0.18)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.12),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}
