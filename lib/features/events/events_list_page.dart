import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EventsListPage extends StatefulWidget {
  const EventsListPage({super.key});

  @override
  State<EventsListPage> createState() => _EventsListPageState();
}

class _EventsListPageState extends State<EventsListPage> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _events = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() => _loading = true);
    try {
      final data = await _supabase.from('events').select().order('start_at', ascending: false);
      setState(() {
        _events = (data as List).map((e) => Map<String, dynamic>.from(e)).toList();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed loading events: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  void _openCreate() async {
    await Navigator.pushNamed(context, '/events/create');
    _loadEvents();
  }

  void _openDetail(String id) {
    Navigator.pushNamed(context, '/events/detail', arguments: {'id': id});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Events')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadEvents,
              child: ListView.builder(
                itemCount: _events.length,
                itemBuilder: (ctx, i) {
                  final e = _events[i];
                  final title = e['name'] ?? 'Untitled event';
                  final region = e['region'] ?? '';
                  final start = e['start_at'] ?? '';
                  return ListTile(
                    title: Text(title),
                    subtitle: Text('$region • $start'),
                    onTap: () => _openDetail(e['id']?.toString() ?? ''),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreate,
        child: const Icon(Icons.add),
      ),
    );
  }
}
