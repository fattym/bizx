import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EventDetailPage extends StatefulWidget {
  const EventDetailPage({super.key});

  @override
  State<EventDetailPage> createState() => _EventDetailPageState();
}

class _EventDetailPageState extends State<EventDetailPage> with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  Map<String, dynamic>? _event;
  bool _loading = true;
  late TabController _tabs;

  String? get _eventId => ModalRoute.of(context)?.settings.arguments is Map ? (ModalRoute.of(context)!.settings.arguments as Map)['id'] as String? : null;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final id = _eventId;
    if (id == null) return;
    setState(() => _loading = true);
    try {
      final row = await _supabase.from('events').select().eq('id', id).maybeSingle();
      if (row != null) setState(() => _event = Map<String, dynamic>.from(row));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed loading event: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  void _openSubpage(String path) {
    Navigator.pushNamed(context, path, arguments: {'id': _eventId});
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_event?['name'] ?? 'Event')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_event != null)
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_event!['name'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text('${_event!['venue'] ?? ''} • ${_event!['region'] ?? ''}'),
                    ]),
                  ),
                TabBar(controller: _tabs, tabs: const [Tab(text: 'Checkins'), Tab(text: 'Tasks'), Tab(text: 'Leads'), Tab(text: 'Photos'), Tab(text: 'Expenses')]),
                Expanded(
                  child: TabBarView(controller: _tabs, children: [
                    Center(child: ElevatedButton(onPressed: () => _openSubpage('/events/checkin'), child: const Text('Open Checkins'))),
                    Center(child: ElevatedButton(onPressed: () => _openSubpage('/events/tasks'), child: const Text('Open Tasks'))),
                    Center(child: ElevatedButton(onPressed: () => _openSubpage('/events/leads'), child: const Text('Open Leads'))),
                    Center(child: ElevatedButton(onPressed: () => _openSubpage('/events/photos'), child: const Text('Open Photos'))),
                    Center(child: ElevatedButton(onPressed: () => _openSubpage('/events/expenses'), child: const Text('Open Expenses'))),
                  ]),
                )
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, '/events/reports', arguments: {'id': _eventId}),
        child: const Icon(Icons.picture_as_pdf),
      ),
    );
  }
}
