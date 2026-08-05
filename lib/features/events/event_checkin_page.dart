import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EventCheckinPage extends StatefulWidget {
  const EventCheckinPage({super.key});

  @override
  State<EventCheckinPage> createState() => _EventCheckinPageState();
}

class _EventCheckinPageState extends State<EventCheckinPage> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _checkins = [];
  bool _loading = true;
  String? get _eventId => ModalRoute.of(context)?.settings.arguments is Map ? (ModalRoute.of(context)!.settings.arguments as Map)['id'] as String? : null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final id = _eventId;
    if (id == null) return;
    setState(() => _loading = true);
    try {
      final data = await _supabase.from('event_checkins').select().eq('event_id', id).order('checkin_at', ascending: false);
      setState(() => _checkins = (data as List).map((e) => Map<String, dynamic>.from(e)).toList());
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Load failed: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Check-ins')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _checkins.length,
              itemBuilder: (ctx, i) {
                final c = _checkins[i];
                return ListTile(
                  title: Text(c['agent_id']?.toString() ?? 'Agent'),
                  subtitle: Text(c['checkin_at']?.toString() ?? ''),
                );
              },
            ),
    );
  }
}
