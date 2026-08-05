import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EventAssignmentsPage extends StatefulWidget {
  const EventAssignmentsPage({super.key});

  @override
  State<EventAssignmentsPage> createState() => _EventAssignmentsPageState();
}

class _EventAssignmentsPageState extends State<EventAssignmentsPage> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _assignments = [];
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
      final data = await _supabase.from('event_assignments').select().eq('event_id', id);
      setState(() => _assignments = (data as List).map((e) => Map<String, dynamic>.from(e)).toList());
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Load failed: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Assignments')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _assignments.length,
              itemBuilder: (ctx, i) {
                final a = _assignments[i];
                return ListTile(
                  title: Text(a['agent_id']?.toString() ?? 'Agent'),
                  subtitle: Text((a['targets'] ?? {}).toString()),
                );
              },
            ),
    );
  }
}
