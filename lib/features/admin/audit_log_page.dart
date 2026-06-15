import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuditLogPage extends StatefulWidget {
  const AuditLogPage({super.key, this.entityId});

  final String? entityId; // Optional: filter for a specific entity

  @override
  State<AuditLogPage> createState() => _AuditLogPageState();
}

class _AuditLogPageState extends State<AuditLogPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _logs = [];

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  Future<void> _fetchLogs() async {
    setState(() => _isLoading = true);
    try {
      // 1. Fetch from audit_events
      var query = _supabase.from('audit_events').select('*, users!actor_id(full_name)');
      if (widget.entityId != null) {
        query = query.eq('entity_id', widget.entityId!);
      }
      final auditRes = await query.order('created_at', ascending: false).limit(100);

      // 2. Fetch from pipeline_history
      var pipeQuery = _supabase.from('pipeline_history').select('*, users!changed_by(full_name)');
      if (widget.entityId != null) {
        pipeQuery = pipeQuery.eq('pipeline_id', widget.entityId!);
      }
      final pipeRes = await pipeQuery.order('changed_at', ascending: false).limit(100);

      final List<Map<String, dynamic>> combined = [];

      for (var a in auditRes) {
        combined.add({
          'date': DateTime.parse(a['created_at'].toString()),
          'title': '${a['action']} ${a['entity_type']}',
          'subtitle': 'By ${a['users']?['full_name'] ?? 'System'}',
          'details': 'ID: ${a['entity_id']}',
          'icon': Icons.history,
          'color': Colors.blue,
        });
      }

      for (var p in pipeRes) {
        combined.add({
          'date': DateTime.parse(p['changed_at'].toString()),
          'title': 'Pipeline Stage Change',
          'subtitle': '${p['old_stage'] ?? 'Lead'} → ${p['new_stage']}',
          'details': 'By ${p['users']?['full_name'] ?? 'System'}',
          'icon': Icons.swap_horiz,
          'color': Colors.purple,
        });
      }

      combined.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));
      _logs = combined;
    } catch (e) {
      debugPrint('Error fetching audit logs: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.entityId != null ? 'Audit History' : 'Global Audit Log')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _logs.isEmpty
              ? const Center(child: Text('No audit events found.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    final log = _logs[index];
                    final date = log['date'] as DateTime;
                    return Card(
                      child: ListTile(
                        leading: Icon(log['icon'] as IconData, color: log['color'] as Color),
                        title: Text(log['title'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(log['subtitle'] as String),
                            Text(log['details'] as String, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                            const SizedBox(height: 4),
                            Text(
                              '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour}:${date.minute.toString().padLeft(2, '0')}',
                              style: const TextStyle(fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
