import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';

class SchoolFollowUpPage extends StatefulWidget {
  const SchoolFollowUpPage({super.key, required this.school});

  final Map<String, dynamic> school;

  @override
  State<SchoolFollowUpPage> createState() => _SchoolFollowUpPageState();
}

class _SchoolFollowUpPageState extends State<SchoolFollowUpPage> {
  final _contactController = TextEditingController();
  final _nextStepController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _contactController.dispose();
    _nextStepController.dispose();
    super.dispose();
  }

  Future<void> _saveFollowUp() async {
    setState(() => _saving = true);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;

    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${widget.school['name']} follow up saved'),
        backgroundColor: AppColors.secondaryOrange,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final schoolName = widget.school['name']?.toString() ?? 'School';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Follow Up'),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _HeaderCard(
            title: schoolName,
            subtitle: 'Capture the next follow-up contact and action.',
            icon: Icons.follow_the_signs,
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _contactController,
            decoration: const InputDecoration(
              labelText: 'Contact Person',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nextStepController,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Next Follow Up Step',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _saving ? null : _saveFollowUp,
            icon:
                _saving
                    ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.update),
            label: const Text('Save Follow Up'),
          ),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.secondaryOrange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: AppColors.secondaryOrange.withValues(alpha: 0.15),
            child: Icon(icon, color: AppColors.secondaryOrange),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(subtitle),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
