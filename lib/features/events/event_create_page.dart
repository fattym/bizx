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
  final _eventType = TextEditingController();
  final _venue = TextEditingController();
  final _region = TextEditingController();
  final _expectedAttendance = TextEditingController();
  final _budget = TextEditingController();
  final _objectives = TextEditingController();
  final _productsPromoted = TextEditingController();
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
    if (_start == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please pick a start date/time')));
      setState(() => _saving = false);
      return;
    }

    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      final payload = <String, dynamic>{
        'name': _name.text.trim(),
        'event_type': _eventType.text.trim(),
        'venue': _venue.text.trim(),
        'region': _region.text.trim(),
        'expected_attendance': int.tryParse(_expectedAttendance.text.trim()),
        'budget': double.tryParse(_budget.text.trim()),
        'objectives': _objectives.text.trim(),
        'products_promoted': _productsPromoted.text.trim(),
      };
      // Include timestamps only when present; send DateTime objects (Supabase client serializes them)
      if (_start != null) payload['start_at'] = _start!.toUtc().toIso8601String();
      if (_end != null) payload['end_at'] = _end!.toUtc().toIso8601String();
      // Link creator when available
      if (currentUser != null) payload['created_by'] = currentUser.id;

      await _supabase.from('events').insert(payload);
      
      if (mounted) Navigator.pop(context);
    } on PostgrestException catch (e) {
      debugPrint('Event insert error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Save failed: ${e.message} (${e.details ?? 'no details'})'),
        ));
      }
    } catch (e, st) {
      debugPrint('Save exception: $e\n$st');
      final msg = e.toString();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $msg')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _eventType.dispose();
    _venue.dispose();
    _region.dispose();
    _expectedAttendance.dispose();
    _budget.dispose();
    _objectives.dispose();
    _productsPromoted.dispose();
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
              TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Event Name'), validator: (v) => (v ?? '').isEmpty ? 'Required' : null),
              TextFormField(controller: _eventType, decoration: const InputDecoration(labelText: 'Event Type')),
              TextFormField(controller: _venue, decoration: const InputDecoration(labelText: 'Venue')),
              TextFormField(controller: _region, decoration: const InputDecoration(labelText: 'Region')),
              TextFormField(controller: _expectedAttendance, decoration: const InputDecoration(labelText: 'Expected Attendance'), keyboardType: TextInputType.number),
              TextFormField(controller: _budget, decoration: const InputDecoration(labelText: 'Budget (KES)'), keyboardType: TextInputType.number),
              TextFormField(controller: _objectives, decoration: const InputDecoration(labelText: 'Objectives'), maxLines: 3),
              TextFormField(controller: _productsPromoted, decoration: const InputDecoration(labelText: 'Products Promoted')),
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
