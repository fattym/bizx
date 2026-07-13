import 'package:workmanager/workmanager.dart';
import 'package:flutter/widgets.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );

    await Hive.initFlutter();
    final box = await Hive.openBox('school_box');

    final supabase = Supabase.instance.client;
    final unsynced = box.values.where(
      (f) => f['isSynced'] == false || f['is_synced'] == false,
    );

    for (var school in unsynced) {
      try {
        await supabase
            .from('schools')
            .upsert(Map<String, dynamic>.from(school));

        school['isSynced'] = true;
        school['is_synced'] = true;
        await box.put(school['id'], school);
      } catch (_) {
        return Future.value(false);
      }
    }

    return Future.value(true);
  });
}
