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
  final _school = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _products = TextEditingController();
  final _timeline = TextEditingController();
  final _notes = TextEditingController();

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
        'school_name': _school.text.trim(),
        'phone': _phone.text.trim(),
        'email': _email.text.trim(),
        'interested_products': _products.text.trim(),
        'purchase_timeline': _timeline.text.trim(),
        'notes': _notes.text.trim(),
      });
      _name.clear();
      _school.clear();
      _phone.clear();
      _email.clear();
      _products.clear();
      _timeline.clear();
      _notes.clear();
      _load();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Create failed: $e')));
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _school.dispose();
    _phone.dispose();
    _email.dispose();
    _products.dispose();
    _timeline.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Event Leads')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: ExpansionTile(
            title: const Text('Add New Lead'),
            children: [
              TextField(controller: _name, decoration: const InputDecoration(hintText: 'Lead Name')),
              TextField(controller: _school, decoration: const InputDecoration(hintText: 'School Name')),
              TextField(controller: _phone, decoration: const InputDecoration(hintText: 'Phone')),
              TextField(controller: _email, decoration: const InputDecoration(hintText: 'Email')),
              TextField(controller: _products, decoration: const InputDecoration(hintText: 'Interested Products')),
              TextField(controller: _timeline, decoration: const InputDecoration(hintText: 'Purchase Timeline')),
              TextField(controller: _notes, decoration: const InputDecoration(hintText: 'Notes'), maxLines: 2),
              const SizedBox(height: 8),
              ElevatedButton(onPressed: _createLead, child: const Text('Save Lead'))
            ],
          ),
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
