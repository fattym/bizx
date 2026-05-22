import 'create_school_screen.dart';
import 'package:flutter/material.dart';
import 'admin_assign_task_screen.dart';
import 'admin_create_route_screen.dart';
import 'analytics_page.dart';
import 'catalog_import_page.dart';
import 'import_schools_page.dart';
import 'add_sample_book_page.dart';
import 'assign_books_page.dart';
import 'admin_geofence_map_screen.dart';
import 'admin_agent_tracker_screen.dart';
import 'admin_pipeline_data_page.dart';
import 'admin_social_pipeline_page.dart';
import 'sample_receipts_page.dart';
import 'project_form_builder_page.dart';
import 'role3_supervision_dashboard_page.dart';
import '../profile/messages_page.dart';
import '../welcome/auth/login_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _supabase = Supabase.instance.client;
  int _totalTasks = 0;
  int _totalGeofences = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    try {
      final taskCount = await _supabase.from('tasks').count(CountOption.exact);
      final geofenceCount = await _supabase
          .from('geofences')
          .count(CountOption.exact);
      if (mounted) {
        setState(() {
          _totalTasks = taskCount;
          _totalGeofences = geofenceCount;
        });
      }
    } catch (e) {
      debugPrint('Error fetching dashboard counts: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Management Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const DeHeusLogin()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AdminAssignTaskScreen(),
            ),
          );
          _refreshData();
        },
        icon: const Icon(Icons.add_task),
        label: const Text('Add Task'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Dashboard Statistics Cards
            Row(
              children: [
                Expanded(
                  child: Card(
                    color: Theme.of(
                      context,
                    ).primaryColor.withValues(alpha: 0.1),
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          const Text(
                            'Assigned Tasks',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _isLoading
                              ? const CircularProgressIndicator()
                              : Text(
                                '$_totalTasks',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Card(
                    color: Colors.green.withValues(alpha: 0.1),
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          const Text(
                            'Active Geofences',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _isLoading
                              ? const CircularProgressIndicator()
                              : Text(
                                '$_totalGeofences',
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildDashboardCard(
              context: context,
              icon: Icons.assignment_outlined,
              title: 'Project',
              subtitle: 'Create a Google Form-style project form.',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProjectFormBuilderPage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            _buildDashboardCard(
              context: context,
              icon: Icons.school_outlined,
              title: 'Onboard New School',
              subtitle: 'Add a new school to the system.',
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CreateSchoolScreen(),
                  ),
                );
                _refreshData();
              },
            ),
            const SizedBox(height: 16),
            _buildDashboardCard(
              context: context,
              icon: Icons.local_shipping_outlined,
              title: 'Assign Delivery Books',
              subtitle: 'Assign books to Grounds (Role 5) personnel.',
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AssignBooksPage(),
                  ),
                );
                _refreshData();
              },
            ),
            const SizedBox(height: 16),
            _buildDashboardCard(
              context: context,
              icon: Icons.domain_add,
              title: 'Import Schools CSV',
              subtitle: 'Upload a list of schools to onboard them in bulk.',
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ImportSchoolsPage(),
                  ),
                );
                _refreshData();
              },
            ),
            const SizedBox(height: 16),
            _buildDashboardCard(
              context: context,
              icon: Icons.auto_stories,
              title: 'Add Sample Book',
              subtitle: 'Manually add a new sample book to the catalog.',
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddSampleBookPage(),
                  ),
                );
                _refreshData();
              },
            ),
            const SizedBox(height: 16),
            _buildDashboardCard(
              context: context,
              icon: Icons.upload_file,
              title: 'Import Catalog CSV',
              subtitle: 'Upload sale and sample book lists from CSV.',
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CatalogImportPage(),
                  ),
                );
                _refreshData();
              },
            ),
            const SizedBox(height: 16),
            _buildDashboardCard(
              context: context,
              icon: Icons.route,
              title: 'Create Route Plan',
              subtitle: 'Assign a sequence of schools to a user for a date.',
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AdminCreateRouteScreen(),
                  ),
                );
                _refreshData();
              },
            ),
            const SizedBox(height: 16),
            _buildDashboardCard(
              context: context,
              icon: Icons.supervisor_account_outlined,
              title: 'Role 3 Command Center',
              subtitle:
                  'Regional supervision for Role 5 with health, SLA and escalations.',
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const Role3SupervisionDashboardPage(),
                  ),
                );
                _refreshData();
              },
            ),
            const SizedBox(height: 16),
            _buildDashboardCard(
              context: context,
              icon: Icons.map,
              title: 'Assign Geofence',
              subtitle: 'Define a map area and tag a user to cover it.',
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AdminGeofenceMapScreen(),
                  ),
                );
                _refreshData();
              },
            ),
            const SizedBox(height: 16),
            _buildDashboardCard(
              context: context,
              icon: Icons.person_pin_circle,
              title: 'Agent Tracker',
              subtitle:
                  'Check assigned route plans and geofences for an agent.',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AdminAgentTrackerScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            _buildDashboardCard(
              context: context,
              icon: Icons.chat_bubble_outline,
              title: 'Messages',
              subtitle: 'Send and read in-app messages with your team.',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const MessagesPage()),
                );
              },
            ),
            const SizedBox(height: 16),
            _buildDashboardCard(
              context: context,
              icon: Icons.analytics_outlined,
              title: 'Analytics',
              subtitle: 'Review trends and operational metrics.',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AnalyticsPage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            _buildDashboardCard(
              context: context,
              icon: Icons.account_tree_outlined,
              title: 'Pipeline Data',
              subtitle: 'View pipeline stage records and stage field details.',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AdminPipelineDataPage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            _buildDashboardCard(
              context: context,
              icon: Icons.campaign_outlined,
              title: 'FB & WhatsApp Pipeline',
              subtitle:
                  'View leads and stages captured from Facebook and WhatsApp.',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AdminSocialPipelinePage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            _buildDashboardCard(
              context: context,
              icon: Icons.receipt_long_outlined,
              title: 'Stamped Sample Receipts',
              subtitle: 'Review stamped proof images for sample distributions.',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SampleReceiptsPage(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      child: ListTile(
        leading: Icon(icon, size: 40, color: Theme.of(context).primaryColor),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: onTap,
      ),
    );
  }
}
