import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EventSamplesPage extends StatefulWidget {
  const EventSamplesPage({super.key});

  @override
  State<EventSamplesPage> createState() => _EventSamplesPageState();
}

class _EventSamplesPageState extends State<EventSamplesPage> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _samples = [];
  bool _loading = true;
  String? get _eventId => ModalRoute.of(context)?.settings.arguments is Map ? (ModalRoute.of(context)!.settings.arguments as Map)['id'] as String? : null;

  final _productName = TextEditingController();
  final _quantity = TextEditingController();
  final _recipientName = TextEditingController();

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
      final data = await _supabase.from('event_samples').select().eq('event_id', id).order('created_at', ascending: false);
      setState(() => _samples = (data as List).map((e) => Map<String, dynamic>.from(e)).toList());
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Load failed: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _createSample() async {
    final id = _eventId;
    if (id == null) return;
    try {
      final currentUser = _supabase.auth.currentUser;
      await _supabase.from('event_samples').insert({
        'event_id': id,
        'agent_id': currentUser?.id,
        'product_name': _productName.text.trim(),
        'quantity': int.tryParse(_quantity.text.trim()) ?? 0,
        'recipient_name': _recipientName.text.trim(),
      });
      _productName.clear();
      _quantity.clear();
      _recipientName.clear();
      _load();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Create failed: $e')));
    }
  }

  @override
  void dispose() {
    _productName.dispose();
    _quantity.dispose();
    _recipientName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sample Distribution')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: ExpansionTile(
            title: const Text('Distribute New Sample'),
            children: [
              TextField(controller: _productName, decoration: const InputDecoration(hintText: 'Product Name')),
              TextField(controller: _quantity, decoration: const InputDecoration(hintText: 'Quantity'), keyboardType: TextInputType.number),
              TextField(controller: _recipientName, decoration: const InputDecoration(hintText: 'Recipient Name (Teacher/Parent)')),
              const SizedBox(height: 8),
              ElevatedButton(onPressed: _createSample, child: const Text('Record Sample'))
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  itemCount: _samples.length,
                  itemBuilder: (ctx, i) {
                    final s = _samples[i];
                    return ListTile(
                      title: Text('${s['quantity']}x ${s['product_name']}'),
                      subtitle: Text('Recipient: ${s['recipient_name'] ?? 'Unknown'}'),
                    );
                  },
                ),
        )
      ]),
    );
  }
}
