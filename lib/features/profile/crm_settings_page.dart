import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/constants/colors.dart';

class CrmSettingsPage extends StatefulWidget {
  const CrmSettingsPage({super.key});

  static const String settingsBoxName = 'app_settings_box';
  static const String crmPushEnabledKey = 'crm_push_notifications_enabled';

  @override
  State<CrmSettingsPage> createState() => _CrmSettingsPageState();
}

class _CrmSettingsPageState extends State<CrmSettingsPage> {
  bool _loading = true;
  bool _crmPushEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final box = await Hive.openBox(CrmSettingsPage.settingsBoxName);
    final stored = box.get(CrmSettingsPage.crmPushEnabledKey);
    if (!mounted) return;
    setState(() {
      _crmPushEnabled = stored is bool ? stored : true;
      _loading = false;
    });
  }

  Future<void> _setCrmPushEnabled(bool value) async {
    setState(() => _crmPushEnabled = value);
    final box = await Hive.openBox(CrmSettingsPage.settingsBoxName);
    await box.put(CrmSettingsPage.crmPushEnabledKey, value);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          value
              ? 'CRM push notifications enabled.'
              : 'CRM push notifications disabled.',
        ),
        backgroundColor: AppColors.primaryGreen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'CRM Notifications',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Card(
                  child: SwitchListTile(
                    value: _crmPushEnabled,
                    onChanged: _setCrmPushEnabled,
                    title: const Text('Push Notifications'),
                    subtitle: const Text(
                      'Receive push alerts for CRM leads, follow-ups, and stage updates.',
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
