import 'create_school_screen.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dehus/features/admin/admin_assign_task_screen.dart';
import 'package:dehus/features/admin/admin_create_route_screen.dart';
import 'package:dehus/features/admin/admin_geofence_map_screen.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/',
                  (route) => false,
                );
              }
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildDashboardCard(
            context: context,
            icon: Icons.school_outlined,
            title: 'Onboard New School',
            subtitle: 'Add a new school to the system.',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CreateSchoolScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          // You can add Superadmin-exclusive functions here later, such as User/Role Management.
          _buildDashboardCard(
            context: context,
            icon: Icons.assignment_add,
            title: 'Assign Task',
            subtitle: 'Create and assign a new task to a role or person.',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdminAssignTaskScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          _buildDashboardCard(
            context: context,
            icon: Icons.route,
            title: 'Create Route Plan',
            subtitle: 'Assign a sequence of schools to a user for a date.',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdminCreateRouteScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          _buildDashboardCard(
            context: context,
            icon: Icons.map,
            title: 'Assign Geofence',
            subtitle: 'Define a map area and tag a user to cover it.',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdminGeofenceMapScreen(),
                ),
              );
            },
          ),
        ],
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
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: Theme.of(
            context,
          ).colorScheme.primary.withValues(alpha: 0.1),
          child: Icon(icon, color: Theme.of(context).colorScheme.primary),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}
