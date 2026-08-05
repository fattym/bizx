import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EventExpensesPage extends StatefulWidget {
  const EventExpensesPage({super.key});

  @override
  State<EventExpensesPage> createState() => _EventExpensesPageState();
}

class _EventExpensesPageState extends State<EventExpensesPage> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _expenses = [];
  bool _loading = true;
  String? get _eventId => ModalRoute.of(context)?.settings.arguments is Map ? (ModalRoute.of(context)!.settings.arguments as Map)['id'] as String? : null;

  final _type = TextEditingController();
  final _amount = TextEditingController();

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
      final data = await _supabase.from('event_expenses').select().eq('event_id', id).order('created_at', ascending: false);
      setState(() => _expenses = (data as List).map((e) => Map<String, dynamic>.from(e)).toList());
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Load failed: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _submitExpense() async {
    final id = _eventId;
    if (id == null) return;
    try {
      await _supabase.from('event_expenses').insert({
        'event_id': id,
        'expense_type': _type.text.trim(),
        'amount': double.tryParse(_amount.text.trim()) ?? 0,
      });
      _type.clear();
      _amount.clear();
      _load();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Submit failed: $e')));
    }
  }

  @override
  void dispose() {
    _type.dispose();
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Expenses')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(children: [
            Expanded(child: TextField(controller: _type, decoration: const InputDecoration(hintText: 'Type'))),
            const SizedBox(width: 8),
            SizedBox(width: 120, child: TextField(controller: _amount, decoration: const InputDecoration(hintText: 'Amount'), keyboardType: TextInputType.number)),
            IconButton(icon: const Icon(Icons.send), onPressed: _submitExpense)
          ]),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  itemCount: _expenses.length,
                  itemBuilder: (ctx, i) {
                    final e = _expenses[i];
                    return ListTile(title: Text(e['expense_type'] ?? ''), trailing: Text('${e['amount'] ?? ''}'));
                  },
                ),
        ),
      ]),
    );
  }
}
