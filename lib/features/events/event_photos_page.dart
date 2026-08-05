import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EventPhotosPage extends StatefulWidget {
  const EventPhotosPage({super.key});

  @override
  State<EventPhotosPage> createState() => _EventPhotosPageState();
}

class _EventPhotosPageState extends State<EventPhotosPage> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _photos = [];
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
      final data = await _supabase.from('event_photos').select().eq('event_id', id).order('uploaded_at', ascending: false);
      setState(() => _photos = (data as List).map((e) => Map<String, dynamic>.from(e)).toList());
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Load failed: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Event Photos')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3),
              itemCount: _photos.length,
              itemBuilder: (ctx, i) {
                final p = _photos[i];
                final url = p['photo_url'] ?? '';
                return Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: url.isEmpty ? const Card(child: Center(child: Icon(Icons.image))) : Image.network(url, fit: BoxFit.cover),
                );
              },
            ),
    );
  }
}
