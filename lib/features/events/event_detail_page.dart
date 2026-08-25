import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../database/database_service.dart';

class EventDetailPage extends StatefulWidget {
  const EventDetailPage({super.key});

  @override
  State<EventDetailPage> createState() => _EventDetailPageState();
}

class _EventDetailPageState extends State<EventDetailPage> with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  final DatabaseService _dbService = DatabaseService();
  Map<String, dynamic>? _event;
  bool _loading = true;
  late TabController _tabs;

  String? get _eventId => ModalRoute.of(context)?.settings.arguments is Map ? (ModalRoute.of(context)!.settings.arguments as Map)['id'] as String? : null;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 6, vsync: this);
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

  Future<void> _assignAgent() async {
    // Fetch users and show selection dialog
    try {
      final users = await _dbService.getAllUsers();
      final agents = users.where((u) => u.role == 5).toList();
      if (agents.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No agents found to assign')));
        return;
      }
      final chosen = await showDialog<String?>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: const Text('Assign Agent'),
          children: agents.map((a) => SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, a.id),
            child: Text(a.fullName ?? a.email),
          )).toList(),
        ),
      );
      if (chosen == null) return;
      final eventId = _eventId;
      if (eventId == null) return;
      final currentUser = Supabase.instance.client.auth.currentUser;
      final assignedBy = currentUser?.id;
      await _supabase.from('event_assignments').insert({
        'event_id': eventId,
        'agent_id': chosen,
        'assigned_by': assignedBy,
        'schedule': {},
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Agent assigned')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Assign failed: $e')));
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
      appBar: AppBar(
        title: Text(_event?['name'] ?? 'Event'),
        actions: [
          IconButton(
            tooltip: 'Assign Agent',
            icon: const Icon(Icons.person_add),
            onPressed: _assignAgent,
          ),
        ],
      ),
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
                TabBar(controller: _tabs, isScrollable: true, tabs: const [Tab(text: 'Checkins'), Tab(text: 'Tasks'), Tab(text: 'Leads'), Tab(text: 'Photos'), Tab(text: 'Expenses'), Tab(text: 'Samples')]),
                Expanded(
                  child: TabBarView(controller: _tabs, children: [
                    Center(child: ElevatedButton(onPressed: () => _openSubpage('/events/checkin'), child: const Text('Open Checkins'))),
                    Center(child: ElevatedButton(onPressed: () => _openSubpage('/events/tasks'), child: const Text('Open Tasks'))),
                    Center(child: ElevatedButton(onPressed: () => _openSubpage('/events/leads'), child: const Text('Open Leads'))),
                    Center(child: ElevatedButton(onPressed: () => _openSubpage('/events/photos'), child: const Text('Open Photos'))),
                    Center(child: ElevatedButton(onPressed: () => _openSubpage('/events/expenses'), child: const Text('Open Expenses'))),
                    Center(child: ElevatedButton(onPressed: () => _openSubpage('/events/samples'), child: const Text('Open Samples'))),
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
