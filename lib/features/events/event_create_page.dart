import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EventCreatePage extends StatefulWidget {
  const EventCreatePage({super.key});

  @override
  State<EventCreatePage> createState() => _EventCreatePageState();
}

class _EventCreatePageState extends State<EventCreatePage> {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _venue = TextEditingController();
  final _region = TextEditingController();
  DateTime? _start;
  DateTime? _end;
  bool _saving = false;

  Future<void> _pickDate(BuildContext ctx, bool isStart) async {
    final now = DateTime.now();
    final picked = await showDatePicker(context: ctx, initialDate: now, firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (picked == null) return;
    final time = await showTimePicker(context: ctx, initialTime: const TimeOfDay(hour: 9, minute: 0));
    if (time == null) return;
    final dt = DateTime(picked.year, picked.month, picked.day, time.hour, time.minute);
    setState(() {
      if (isStart) _start = dt; else _end = dt;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await _supabase.from('events').insert({
        'name': _name.text.trim(),
        'venue': _venue.text.trim(),
        'region': _region.text.trim(),
        'start_at': _start?.toUtc(),
        'end_at': _end?.toUtc(),
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _venue.dispose();
    _region.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Event')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Event name'), validator: (v) => (v ?? '').isEmpty ? 'Required' : null),
              TextFormField(controller: _venue, decoration: const InputDecoration(labelText: 'Venue')),
              TextFormField(controller: _region, decoration: const InputDecoration(labelText: 'Region')),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: Text(_start == null ? 'Start' : _start!.toLocal().toString())),
                TextButton(onPressed: () => _pickDate(context, true), child: const Text('Pick')),
              ]),
              Row(children: [
                Expanded(child: Text(_end == null ? 'End' : _end!.toLocal().toString())),
                TextButton(onPressed: () => _pickDate(context, false), child: const Text('Pick')),
              ]),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: _saving ? null : _save, child: _saving ? const CircularProgressIndicator() : const Text('Save')),
            ],
          ),
        ),
      ),
    );
  }
}
