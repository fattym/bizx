import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EventCheckinPage extends StatefulWidget {
  const EventCheckinPage({super.key});

  @override
  State<EventCheckinPage> createState() => _EventCheckinPageState();
}

class _EventCheckinPageState extends State<EventCheckinPage> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _checkins = [];
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
      final data = await _supabase.from('event_checkins').select().eq('event_id', id).order('checkin_at', ascending: false);
      setState(() => _checkins = (data as List).map((e) => Map<String, dynamic>.from(e)).toList());
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Load failed: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _performCheckin() async {
    final id = _eventId;
    if (id == null) return;
    
    setState(() => _loading = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied, we cannot request permissions.');
      } 

      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

      final currentUser = Supabase.instance.client.auth.currentUser;
      await _supabase.from('event_checkins').insert({
        'event_id': id,
        'agent_id': currentUser?.id,
        'latitude': position.latitude,
        'longitude': position.longitude,
      });

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Successfully checked in!')));
      _load();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Check-in failed: $e')));
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Check-ins'),
        actions: [
          IconButton(
            icon: const Icon(Icons.location_on),
            tooltip: 'Check In (GPS)',
            onPressed: _performCheckin,
          )
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _checkins.length,
              itemBuilder: (ctx, i) {
                final c = _checkins[i];
                return ListTile(
                  title: Text(c['agent_id']?.toString() ?? 'Agent'),
                  subtitle: Text(c['checkin_at']?.toString() ?? ''),
                );
              },
            ),
    );
  }
}
