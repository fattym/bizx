import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'colors.dart';
import '../../features/dashboard/school_sell_page.dart';

class AgentRoutePlanScreen extends StatefulWidget {
  const AgentRoutePlanScreen({super.key});

  @override
  State<AgentRoutePlanScreen> createState() => _AgentRoutePlanScreenState();
}

class _AgentRoutePlanScreenState extends State<AgentRoutePlanScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _routePlans = [];

  @override
  void initState() {
    super.initState();
    _fetchRoutePlans();
  }

  Future<void> _fetchRoutePlans() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final response = await Supabase.instance.client
          .from('route_plans')
          .select()
          .eq('assigned_to', userId)
          .order('route_date', ascending: true);

      setState(() {
        _routePlans = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading route plans: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Route Plan'),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: AppColors.surfaceWhite,
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _routePlans.isEmpty
              ? const Center(child: Text('No route plans assigned to you.'))
              : ListView.builder(
                itemCount: _routePlans.length,
                itemBuilder: (context, index) {
                  final plan = _routePlans[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    color: AppColors.surfaceWhite,
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: AppColors.primaryPale,
                        child: Icon(
                          Icons.directions_car,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                      title: Text(
                        plan['title'] ?? 'Route Plan',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Date: ${plan['route_date']} \nStatus: ${plan['status']} \nNotes: ${plan['notes'] ?? 'None'}',
                      ),
                      isThreeLine: true,
                    ),
                  );
                },
              ),
    );
  }
}

class AgentSchoolVisitsScreen extends StatefulWidget {
  const AgentSchoolVisitsScreen({super.key});

  @override
  State<AgentSchoolVisitsScreen> createState() =>
      _AgentSchoolVisitsScreenState();
}

class _AgentSchoolVisitsScreenState extends State<AgentSchoolVisitsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _visits = [];

  @override
  void initState() {
    super.initState();
    _fetchVisits();
  }

  Future<void> _fetchVisits() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final response = await Supabase.instance.client
          .from('school_visits')
          .select('*, schools(name)')
          .eq('agent_id', userId)
          .order('visited_at', ascending: false);

      setState(() {
        _visits = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading visits: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('School Visits'),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: AppColors.surfaceWhite,
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _visits.isEmpty
              ? const Center(child: Text('No visits recorded.'))
              : ListView.builder(
                itemCount: _visits.length,
                itemBuilder: (context, index) {
                  final visit = _visits[index];
                  final schoolName =
                      visit['schools']?['name'] ?? 'Unknown School';
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    color: AppColors.surfaceWhite,
                    child: ListTile(
                      leading: const Icon(
                        Icons.school_outlined,
                        color: AppColors.infoBlue,
                        size: 36,
                      ),
                      title: Text(
                        schoolName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Outcome: ${visit['outcome'] ?? 'N/A'}\nNotes: ${visit['notes'] ?? ''}',
                      ),
                      trailing: Text(
                        visit['visit_status']?.toString().toUpperCase() ?? '',
                        style: const TextStyle(
                          color: AppColors.primaryGreen,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      isThreeLine: true,
                    ),
                  );
                },
              ),
    );
  }
}

class AgentSubmitOrderScreen extends StatefulWidget {
  const AgentSubmitOrderScreen({super.key});

  @override
  State<AgentSubmitOrderScreen> createState() => _AgentSubmitOrderScreenState();
}

class _AgentSubmitOrderScreenState extends State<AgentSubmitOrderScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _schools = [];
  final Map<String, String> _stageBySchoolId = <String, String>{};

  @override
  void initState() {
    super.initState();
    _fetchSchools();
  }

  Future<void> _fetchSchools() async {
    try {
      final response = await Supabase.instance.client
          .from('schools')
          .select()
          .order('name');

      final salesResponse = await Supabase.instance.client
          .from('school_sales')
          .select('school_id,sale_status,stage_updated_at')
          .order('stage_updated_at', ascending: false);

      final stageMap = <String, String>{};
      for (final row in List<Map<String, dynamic>>.from(salesResponse)) {
        final schoolId = (row['school_id'] ?? '').toString();
        if (schoolId.isEmpty || stageMap.containsKey(schoolId)) continue;
        final rawStage = (row['sale_status'] ?? '').toString().trim();
        if (rawStage.isEmpty) continue;
        stageMap[schoolId] = _formatStage(rawStage);
      }

      setState(() {
        _schools = List<Map<String, dynamic>>.from(response);
        _stageBySchoolId
          ..clear()
          ..addAll(stageMap);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading schools: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select School for Pipeline'),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: AppColors.surfaceWhite,
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _schools.isEmpty
              ? const Center(child: Text('No schools available.'))
              : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 10),
                itemCount: _schools.length,
                itemBuilder: (context, index) {
                  final school = _schools[index];
                  final schoolName = school['name']?.toString() ?? 'Unknown School';
                  final county = school['county']?.toString() ?? 'Unknown County';
                  final phone = school['phone']?.toString();
                  final category = school['book_category']?.toString();
                  final source =
                      school['source']?.toString().isNotEmpty == true
                          ? school['source'].toString()
                          : 'manual';
                  final captureStatus =
                      school['capture_status']?.toString().isNotEmpty == true
                          ? school['capture_status'].toString()
                          : 'active';
                  final schoolId = school['id']?.toString() ?? '';
                  final pipelineStage = _stageBySchoolId[schoolId];

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SchoolSellPage(school: school),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const CircleAvatar(
                                  backgroundColor: AppColors.primaryPale,
                                  child: Icon(
                                    Icons.shopping_bag_outlined,
                                    color: AppColors.accentOrange,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    schoolName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_ios, size: 16),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _schoolMetaChip(Icons.location_on_outlined, county),
                                _schoolMetaChip(
                                  Icons.phone_outlined,
                                  (phone != null && phone.trim().isNotEmpty)
                                      ? phone
                                      : 'No phone',
                                ),
                                _schoolMetaChip(
                                  Icons.menu_book_outlined,
                                  (category != null && category.trim().isNotEmpty)
                                      ? category
                                      : 'General',
                                ),
                                _schoolMetaChip(
                                  Icons.source_outlined,
                                  'Source: $source',
                                ),
                                _schoolMetaChip(
                                  Icons.verified_outlined,
                                  'Status: $captureStatus',
                                ),
                                if (pipelineStage != null)
                                  _schoolMetaChip(
                                    Icons.timeline_outlined,
                                    'Stage: $pipelineStage',
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
    );
  }

  Widget _schoolMetaChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.blueGrey),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  String _formatStage(String stage) {
    return stage
        .replaceAll('_', ' ')
        .split(' ')
        .map((part) {
          if (part.isEmpty) return part;
          return '${part[0].toUpperCase()}${part.substring(1)}';
        })
        .join(' ');
  }
}

class AgentDistributeSamplesScreen extends StatefulWidget {
  const AgentDistributeSamplesScreen({super.key});

  @override
  State<AgentDistributeSamplesScreen> createState() =>
      _AgentDistributeSamplesScreenState();
}

class _AgentDistributeSamplesScreenState
    extends State<AgentDistributeSamplesScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _samples = [];

  @override
  void initState() {
    super.initState();
    _fetchSamples();
  }

  Future<void> _fetchSamples() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final response = await Supabase.instance.client
          .from('school_sample_distributions')
          .select('*, schools(name)')
          .eq('agent_id', userId)
          .order('distributed_at', ascending: false);

      setState(() {
        _samples = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading samples: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Distributed Samples'),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: AppColors.surfaceWhite,
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _samples.isEmpty
              ? const Center(child: Text('No samples distributed yet.'))
              : ListView.builder(
                itemCount: _samples.length,
                itemBuilder: (context, index) {
                  final sample = _samples[index];
                  final schoolName =
                      sample['schools']?['name'] ?? 'Unknown School';
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    color: AppColors.surfaceWhite,
                    child: ListTile(
                      leading: const Icon(
                        Icons.menu_book,
                        color: AppColors.softGold,
                        size: 36,
                      ),
                      title: Text(
                        sample['sample_name'] ?? 'Sample',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'School: $schoolName\nQty Distributed: ${sample['quantity']}\nNotes: ${sample['notes']}',
                      ),
                      isThreeLine: true,
                    ),
                  );
                },
              ),
    );
  }
}
