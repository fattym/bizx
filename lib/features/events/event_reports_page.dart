import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EventReportsPage extends StatefulWidget {
  const EventReportsPage({super.key});

  @override
  State<EventReportsPage> createState() => _EventReportsPageState();
}

class _EventReportsPageState extends State<EventReportsPage> {
  final _supabase = Supabase.instance.client;
  Map<String, dynamic>? _report;
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
      final data = await _supabase.from('event_reports').select().eq('event_id', id).maybeSingle();
      if (data != null) _report = Map<String, dynamic>.from(data);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Load failed: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Event Report')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(12.0),
              child: _report == null
                  ? const Center(child: Text('No report yet'))
                  : ListView(
                      children: [
                        Text('Summary:\n${_report!['summary'] ?? ''}'),
                        const SizedBox(height: 12),
                        Text('Visitors: ${_report!['visitors_count'] ?? 0}'),
                        Text('Qualified leads: ${_report!['qualified_leads_count'] ?? 0}'),
                        Text('Orders: ${_report!['orders_count'] ?? 0}'),
                        Text('Revenue: ${_report!['revenue'] ?? 0}'),
                      ],
                    ),
            ),
    );
  }
}
