import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Role3SupervisionDashboardPage extends StatefulWidget {
  const Role3SupervisionDashboardPage({super.key});

  @override
  State<Role3SupervisionDashboardPage> createState() =>
      _Role3SupervisionDashboardPageState();
}

class _Role3SupervisionDashboardPageState
    extends State<Role3SupervisionDashboardPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  String? _selectedCounty;

  final List<String> _counties = const [
    'Baringo',
    'Bomet',
    'Bungoma',
    'Busia',
    'Elgeyo-Marakwet',
    'Embu',
    'Garissa',
    'Homa Bay',
    'Isiolo',
    'Kajiado',
    'Kakamega',
    'Kericho',
    'Kiambu',
    'Kilifi',
    'Kirinyaga',
    'Kisii',
    'Kisumu',
    'Kitui',
    'Kwale',
    'Laikipia',
    'Lamu',
    'Machakos',
    'Makueni',
    'Mandera',
    'Marsabit',
    'Meru',
    'Migori',
    'Mombasa',
    'Murang\'a',
    'Nairobi',
    'Nakuru',
    'Nandi',
    'Narok',
    'Nyamira',
    'Nyandarua',
    'Nyeri',
    'Samburu',
    'Siaya',
    'Taita-Taveta',
    'Tana River',
    'Tharaka-Nithi',
    'Trans Nzoia',
    'Turkana',
    'Uasin Gishu',
    'Vihiga',
    'Wajir',
    'West Pokot',
  ];

  List<Map<String, dynamic>> _role5Users = [];
  List<Map<String, dynamic>> _tasks = [];
  List<Map<String, dynamic>> _routes = [];
  List<Map<String, dynamic>> _geofences = [];
  List<Map<String, dynamic>> _alerts = [];
  List<Map<String, dynamic>> _breaches = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return;

      final currentUserRow = await _supabase
          .from('users')
          .select('region, role')
          .eq('id', currentUser.id)
          .maybeSingle();
      final supervisorRegion = (currentUserRow?['region'] ?? '')
          .toString()
          .trim();

      final usersResponse = await _supabase
          .from('users')
          .select('id, full_name, email, role, region')
          .eq('role', 5)
          .eq('region', supervisorRegion);
      final users = List<Map<String, dynamic>>.from(usersResponse);
      final userIds = users.map((u) => u['id'].toString()).toList();

      List<Map<String, dynamic>> tasks = [];
      List<Map<String, dynamic>> routes = [];
      List<Map<String, dynamic>> geofences = [];
      List<Map<String, dynamic>> alerts = [];
      List<Map<String, dynamic>> breaches = [];

      if (userIds.isNotEmpty) {
        final tasksResponse = await _supabase
            .from('tasks')
            .select('id, assigned_to, status, due_at, title')
            .inFilter('assigned_to', userIds);
        tasks = List<Map<String, dynamic>>.from(tasksResponse);

        final routesResponse = await _supabase
            .from('route_plans')
            .select('id, assigned_to, route_date, status')
            .inFilter('assigned_to', userIds)
            .order('route_date', ascending: false);
        routes = List<Map<String, dynamic>>.from(routesResponse);

        final geofenceResponse = await _supabase
            .from('geofences')
            .select('id, name, region, assigned_to, updated_at')
            .inFilter('assigned_to', userIds)
            .order('updated_at', ascending: false);
        geofences = List<Map<String, dynamic>>.from(geofenceResponse);

        try {
          final alertResponse = await _supabase
              .from('supervisor_alerts')
              .select('*')
              .inFilter('user_id', userIds)
              .order('created_at', ascending: false);
          alerts = List<Map<String, dynamic>>.from(alertResponse);
        } catch (_) {}

        try {
          final breachResponse = await _supabase
              .from('geofence_events')
              .select('*')
              .eq('event_type', 'breach')
              .inFilter('user_id', userIds)
              .order('created_at', ascending: false);
          breaches = List<Map<String, dynamic>>.from(breachResponse);
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        _role5Users = users;
        _tasks = tasks;
        _routes = routes;
        _geofences = geofences;
        _alerts = alerts;
        _breaches = breaches;
      });
    } catch (e) {
      debugPrint('Role3 supervision load error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load supervision data: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _healthForUser(String userId) {
    final now = DateTime.now();
    final overdueCount =
        _tasks.where((t) {
          if (t['assigned_to']?.toString() != userId) return false;
          final status = (t['status'] ?? '').toString().toLowerCase();
          final dueAt = DateTime.tryParse((t['due_at'] ?? '').toString());
          return dueAt != null &&
              dueAt.isBefore(now) &&
              status != 'closed' &&
              status != 'completed';
        }).length;

    final activeAlerts =
        _alerts.where((a) {
          return a['user_id']?.toString() == userId &&
              (a['status'] ?? 'open').toString().toLowerCase() == 'open';
        }).length;

    if (activeAlerts > 0 || overdueCount > 2) return 'Red';
    if (overdueCount > 0) return 'Amber';
    return 'Green';
  }

  Color _healthColor(String health) {
    if (health == 'Red') return Colors.red;
    if (health == 'Amber') return Colors.orange;
    return Colors.green;
  }

  List<Map<String, dynamic>> get _filteredUsers {
    if (_selectedCounty == null || _selectedCounty!.isEmpty) return _role5Users;
    return _role5Users
        .where(
          (u) =>
              (u['region'] ?? '').toString().toLowerCase() ==
              _selectedCounty!.toLowerCase(),
        )
        .toList();
  }

  Future<void> _createIncident(String userId) async {
    await _supabase.from('supervisor_incidents').insert({
      'user_id': userId,
      'incident_type': 'escalation',
      'severity': 'high',
      'status': 'open',
      'region': _selectedCounty,
      'notes': 'Escalated by supervisor from command center.',
      'created_by': _supabase.auth.currentUser?.id,
    });
    await _loadData();
  }

  Future<void> _extendDeadlineForLatestTask(String userId) async {
    final candidate = _tasks
        .where((t) => t['assigned_to']?.toString() == userId)
        .cast<Map<String, dynamic>?>()
        .firstWhere((_) => true, orElse: () => null);
    if (candidate == null) return;
    final due = DateTime.tryParse((candidate['due_at'] ?? '').toString());
    if (due == null) return;
    await _supabase
        .from('tasks')
        .update({'due_at': due.add(const Duration(days: 1)).toIso8601String()})
        .eq('id', candidate['id']);
    await _loadData();
  }

  Future<void> _addCoachingNote(String userId) async {
    await _supabase.from('supervisor_notes').insert({
      'supervisor_id': _supabase.auth.currentUser?.id,
      'user_id': userId,
      'region': _selectedCounty,
      'context_type': 'health_review',
      'note': 'Weekly coaching follow-up recorded from dashboard.',
      'follow_up_at':
          DateTime.now().add(const Duration(days: 7)).toIso8601String(),
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Coaching note added.')),
    );
  }

  Future<void> _approvePendingRoute(String userId, bool approve) async {
    final pending = _routes.cast<Map<String, dynamic>?>().firstWhere(
      (r) =>
          r?['assigned_to']?.toString() == userId &&
          (r?['status'] ?? '').toString().toLowerCase() == 'submitted',
      orElse: () => null,
    );
    if (pending == null) return;
    await _supabase
        .from('route_plans')
        .update({
          'status': approve ? 'approved' : 'rejected',
          'reviewed_by': _supabase.auth.currentUser?.id,
          'reviewed_at': DateTime.now().toIso8601String(),
          'review_note': approve
              ? 'Approved by Role 3 supervisor.'
              : 'Rejected. Needs correction.',
        })
        .eq('id', pending['id']);
    await _loadData();
  }

  Future<void> _reassignRoute(String routeId) async {
    final filtered = _filteredUsers;
    if (filtered.isEmpty) return;
    final newAssignee = filtered.first['id']?.toString();
    if (newAssignee == null) return;
    await _supabase
        .from('route_plans')
        .update({'assigned_to': newAssignee})
        .eq('id', routeId);
    await _supabase.from('audit_events').insert({
      'actor_id': _supabase.auth.currentUser?.id,
      'action': 'reassign_route',
      'entity_type': 'route_plans',
      'entity_id': routeId,
      'region': _selectedCounty,
      'after_data': {'assigned_to': newAssignee},
    });
    await _loadData();
  }

  Future<void> _reassignGeofence(String geofenceId) async {
    final filtered = _filteredUsers;
    if (filtered.isEmpty) return;
    final newAssignee = filtered.first['id']?.toString();
    if (newAssignee == null) return;
    await _supabase
        .from('geofences')
        .update({'assigned_to': newAssignee, 'region': _selectedCounty})
        .eq('id', geofenceId);
    await _supabase.from('audit_events').insert({
      'actor_id': _supabase.auth.currentUser?.id,
      'action': 'reassign_geofence',
      'entity_type': 'geofences',
      'entity_id': geofenceId,
      'region': _selectedCounty,
      'after_data': {'assigned_to': newAssignee, 'region': _selectedCounty},
    });
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final filtered = _filteredUsers;
    final filteredIds = filtered.map((u) => u['id'].toString()).toSet();
    final overdueTasks =
        _tasks.where((t) {
          if (!filteredIds.contains(t['assigned_to']?.toString())) return false;
          final dueAt = DateTime.tryParse((t['due_at'] ?? '').toString());
          final status = (t['status'] ?? '').toString().toLowerCase();
          return dueAt != null &&
              dueAt.isBefore(now) &&
              status != 'closed' &&
              status != 'completed';
        }).length;
    final unstartedRoutes =
        _routes.where((r) {
          if (!filteredIds.contains(r['assigned_to']?.toString())) return false;
          return (r['status'] ?? 'assigned').toString().toLowerCase() ==
              'assigned';
        }).length;
    final atRisk =
        filtered.where((u) => _healthForUser(u['id'].toString()) != 'Green').length;
    final activeRole5 = filtered.length;
    final openAlerts =
        _alerts.where((a) {
          if (!filteredIds.contains(a['user_id']?.toString())) return false;
          return (a['status'] ?? 'open').toString().toLowerCase() == 'open';
        }).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Role 3 Supervision Command Center'),
        actions: [
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  DropdownButtonFormField<String>(
                    value: _selectedCounty,
                    decoration: const InputDecoration(
                      labelText: 'County filter',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('All supervised counties'),
                      ),
                      ..._counties.map(
                        (c) => DropdownMenuItem(value: c, child: Text(c)),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedCounty = value);
                    },
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _kpi(
                        'Active Role 5',
                        '$activeRole5',
                        Colors.blue,
                        Icons.groups_2_outlined,
                      ),
                      _kpi(
                        'At Risk Today',
                        '$atRisk',
                        Colors.orange,
                        Icons.warning_amber_outlined,
                      ),
                      _kpi(
                        'Boundary Breaches',
                        '${_breaches.length}',
                        Colors.red,
                        Icons.fmd_bad_outlined,
                      ),
                      _kpi(
                        'Unstarted Routes',
                        '$unstartedRoutes',
                        Colors.purple,
                        Icons.route_outlined,
                      ),
                      _kpi(
                        'Overdue Tasks',
                        '$overdueTasks',
                        Colors.deepOrange,
                        Icons.task_alt_outlined,
                      ),
                      _kpi(
                        'Open Alerts',
                        '$openAlerts',
                        Colors.red.shade700,
                        Icons.notification_important_outlined,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _sectionHeader(
                    'Role 5 Health Status',
                    'Green: on-track, Amber: delayed, Red: urgent intervention',
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: const [
                      Chip(
                        avatar: CircleAvatar(
                          backgroundColor: Colors.green,
                          radius: 6,
                        ),
                        label: Text('Green'),
                      ),
                      Chip(
                        avatar: CircleAvatar(
                          backgroundColor: Colors.orange,
                          radius: 6,
                        ),
                        label: Text('Amber'),
                      ),
                      Chip(
                        avatar: CircleAvatar(backgroundColor: Colors.red, radius: 6),
                        label: Text('Red'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...filtered.map((user) {
                    final userId = user['id'].toString();
                    final health = _healthForUser(userId);
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 6,
                                  backgroundColor: _healthColor(health),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${user['full_name'] ?? user['email']} (${user['region'] ?? 'Unknown'})',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Text(health),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                FilledButton.tonal(
                                  onPressed: () => _approvePendingRoute(userId, true),
                                  child: const Text('Approve'),
                                ),
                                FilledButton.tonal(
                                  onPressed: () => _approvePendingRoute(userId, false),
                                  child: const Text('Reject'),
                                ),
                                FilledButton.tonal(
                                  onPressed: () => _extendDeadlineForLatestTask(userId),
                                  child: const Text('Extend'),
                                ),
                                FilledButton.tonal(
                                  onPressed: () => _createIncident(userId),
                                  child: const Text('Incident'),
                                ),
                                FilledButton.tonal(
                                  onPressed: () => _addCoachingNote(userId),
                                  child: const Text('Coaching'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                  _sectionHeader(
                    'Route Plans (Role 5)',
                    'Daily execution and reassignment controls',
                  ),
                  const SizedBox(height: 8),
                  ..._routes
                      .where(
                        (r) => filteredIds.contains(r['assigned_to']?.toString()),
                      )
                      .map(
                        (route) => Card(
                          child: ListTile(
                            leading: const Icon(Icons.route),
                            title: Text(
                              'Route ${route['route_date']?.toString().split(' ').first ?? 'No date'}',
                            ),
                            subtitle: Text(
                              'Status: ${(route['status'] ?? 'assigned').toString()}',
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'reassign') {
                                  _reassignRoute(route['id'].toString());
                                }
                              },
                              itemBuilder: (context) => const [
                                PopupMenuItem(
                                  value: 'reassign',
                                  child: Text('Reassign Route'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  const SizedBox(height: 12),
                  _sectionHeader(
                    'Geofences (Role 5)',
                    'Boundary ownership and county mapping',
                  ),
                  const SizedBox(height: 8),
                  ..._geofences
                      .where(
                        (g) => filteredIds.contains(g['assigned_to']?.toString()),
                      )
                      .map(
                        (geo) => Card(
                          child: ListTile(
                            leading: const Icon(Icons.map_outlined),
                            title: Text(geo['name']?.toString() ?? 'Geofence'),
                            subtitle: Text(
                              'County: ${geo['region'] ?? 'Not set'}',
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'reassign') {
                                  _reassignGeofence(geo['id'].toString());
                                }
                              },
                              itemBuilder: (context) => const [
                                PopupMenuItem(
                                  value: 'reassign',
                                  child: Text('Reassign Geofence'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  const SizedBox(height: 12),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.timer_outlined),
                      title: const Text('Supervisor SLA Adherence'),
                      subtitle: Text(
                        'Ack < 15 min and resolve < 2 hrs tiles use data from supervisor_alerts.',
                      ),
                      trailing: Text(
                        '${_alerts.where((a) => (a['ack_sla_met'] ?? false) == true).length}'
                        '/${_alerts.length}',
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _kpi(String label, String value, Color color, IconData icon) {
    return Container(
      width: 170,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.09),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        ),
      ],
    );
  }
}
