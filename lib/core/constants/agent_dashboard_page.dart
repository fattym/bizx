import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/agent_screens.dart';
import '../../core/constants/colors.dart';
import '../../features/dashboard/my_shops_page.dart';
import '../../features/admin/target_performance_page.dart';

class AgentDashboardPage extends StatelessWidget {
  const AgentDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Field Agent Portal'),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: AppColors.surfaceWhite,
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
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Welcome, Field Agent!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Check your route plans and school visits.',
              style: TextStyle(fontSize: 16, color: AppColors.textMuted),
            ),
            const SizedBox(height: 30),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _buildDashboardCard(
                    context,
                    Icons.school_outlined,
                    'My Schools (100km)',
                    AppColors.infoBlue,
                    const MyShopsPage(),
                  ),
                  _buildDashboardCard(
                    context,
                    Icons.directions_car_outlined,
                    'My Route Plan',
                    AppColors.primaryGreen,
                    const AgentRoutePlanScreen(),
                  ),
                  _buildDashboardCard(
                    context,
                    Icons.school_outlined,
                    'School Visits',
                    AppColors.infoBlue,
                    const AgentSchoolVisitsScreen(),
                  ),
                  _buildDashboardCard(
                    context,
                    Icons.shopping_bag_outlined,
                    'Submit Order',
                    AppColors.accentOrange,
                    const AgentSubmitOrderScreen(),
                  ),
                  _buildDashboardCard(
                    context,
                    Icons.menu_book_outlined,
                    'Distribute Samples',
                    AppColors.softGold,
                    const AgentDistributeSamplesScreen(),
                  ),
                  _buildDashboardCard(
                    context,
                    Icons.insights,
                    'Performance',
                    AppColors.primaryDark,
                    const TargetPerformancePage(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardCard(
    BuildContext context,
    IconData icon,
    String title,
    Color color,
    Widget destination,
  ) {
    return Card(
      color: AppColors.surfaceWhite,
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => destination),
          );
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
