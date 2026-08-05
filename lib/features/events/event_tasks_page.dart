import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EventTasksPage extends StatefulWidget {
  const EventTasksPage({super.key});

  @override
  State<EventTasksPage> createState() => _EventTasksPageState();
}

class _EventTasksPageState extends State<EventTasksPage> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _tasks = [];
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
      final data = await _supabase.from('event_tasks').select().eq('event_id', id).order('sort_order');
      setState(() => _tasks = (data as List).map((e) => Map<String, dynamic>.from(e)).toList());
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Load failed: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _toggleComplete(Map<String, dynamic> task) async {
    try {
      await _supabase.from('event_tasks').update({'completed': !(task['completed'] ?? false)}).eq('id', task['id']);
      _load();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Event Tasks')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _tasks.length,
              itemBuilder: (ctx, i) {
                final t = _tasks[i];
                return CheckboxListTile(
                  title: Text(t['title'] ?? ''),
                  value: t['completed'] ?? false,
                  onChanged: (_) => _toggleComplete(t),
                );
              },
            ),
    );
  }
}
