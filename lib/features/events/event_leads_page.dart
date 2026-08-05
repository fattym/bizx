import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EventLeadsPage extends StatefulWidget {
  const EventLeadsPage({super.key});

  @override
  State<EventLeadsPage> createState() => _EventLeadsPageState();
}

class _EventLeadsPageState extends State<EventLeadsPage> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _leads = [];
  bool _loading = true;
  String? get _eventId => ModalRoute.of(context)?.settings.arguments is Map ? (ModalRoute.of(context)!.settings.arguments as Map)['id'] as String? : null;

  final _name = TextEditingController();
  final _phone = TextEditingController();

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
      final data = await _supabase.from('event_leads').select().eq('event_id', id).order('created_at', ascending: false);
      setState(() => _leads = (data as List).map((e) => Map<String, dynamic>.from(e)).toList());
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Load failed: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _createLead() async {
    final id = _eventId;
    if (id == null) return;
    try {
      await _supabase.from('event_leads').insert({
        'event_id': id,
        'lead_name': _name.text.trim(),
        'phone': _phone.text.trim(),
      });
      _name.clear();
      _phone.clear();
      _load();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Create failed: $e')));
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Event Leads')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(children: [
            Expanded(child: TextField(controller: _name, decoration: const InputDecoration(hintText: 'Name'))),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: _phone, decoration: const InputDecoration(hintText: 'Phone'))),
            IconButton(icon: const Icon(Icons.add), onPressed: _createLead)
          ]),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  itemCount: _leads.length,
                  itemBuilder: (ctx, i) {
                    final l = _leads[i];
                    return ListTile(
                      title: Text(l['lead_name'] ?? ''),
                      subtitle: Text(l['phone'] ?? ''),
                    );
                  },
                ),
        )
      ]),
    );
  }
}
