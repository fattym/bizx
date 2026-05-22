import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';

class SchoolVisitPage extends StatefulWidget {
  const SchoolVisitPage({super.key, required this.school});

  final Map<String, dynamic> school;

  @override
  State<SchoolVisitPage> createState() => _SchoolVisitPageState();
}

class _SchoolVisitPageState extends State<SchoolVisitPage> {
  final _notesController = TextEditingController();
  final _outcomeController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _notesController.dispose();
    _outcomeController.dispose();
    super.dispose();
  }

  Future<void> _saveVisit() async {
    setState(() => _saving = true);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;

    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${widget.school['name']} visit saved'),
        backgroundColor: AppColors.primaryGreen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final schoolName = widget.school['name']?.toString() ?? 'School';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Visit School'),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _HeaderCard(
            title: schoolName,
            subtitle: 'Log the field visit and store the outcome.',
            icon: Icons.directions_walk,
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _outcomeController,
            decoration: const InputDecoration(
              labelText: 'Visit Outcome',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _notesController,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Visit Notes',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _saving ? null : _saveVisit,
            icon:
                _saving
                    ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.check_circle_outline),
            label: const Text('Save Visit'),
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
        color: AppColors.primaryGreen.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.12),
            child: Icon(icon, color: AppColors.primaryGreen),
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
