import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/constants/colors.dart';
import 'crm_settings_page.dart';

class CrmNotificationService {
  static Future<bool> isEnabled() async {
    final box = await Hive.openBox(CrmSettingsPage.settingsBoxName);
    final stored = box.get(CrmSettingsPage.crmPushEnabledKey);
    return stored is bool ? stored : true;
  }

  static Future<void> showIfEnabled(
    BuildContext context, {
    required String message,
    Color backgroundColor = AppColors.primaryGreen,
  }) async {
    if (!await isEnabled()) return;
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: backgroundColor),
    );
  }
}
