// import 'package:flutter/material.dart';
// import '../../core/constants/colors.dart';
// import '../dashboard/agrovet_onboarding.dart';
// import '../dashboard/farmer_profiling.dart';
// import '../dashboard/my_orders_page.dart';
// import '../dashboard/inventory_page.dart';
// import '../dashboard/clock_in_page.dart';
// import '../dashboard/my_shops_page.dart';

// class SalesDashboard extends StatelessWidget {
//   const SalesDashboard({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFFF9F9F7),
//       body: Column(
//         children: [
//           _buildSalesHeader(),
//           Expanded(
//             child: SingleChildScrollView(
//               padding: const EdgeInsets.all(20),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   const Text(
//                     "PERFORMANCE",
//                     style: TextStyle(
//                       fontWeight: FontWeight.bold,
//                       color: Colors.grey,
//                       letterSpacing: 1.2,
//                     ),
//                   ),
//                   const SizedBox(height: 12),
//                   _buildMetricsGrid(),
//                   const SizedBox(height: 30),
//                   const Text(
//                     "QUICK ACTIONS",
//                     style: TextStyle(
//                       fontWeight: FontWeight.bold,
//                       color: Colors.grey,
//                       letterSpacing: 1.2,
//                     ),
//                   ),
//                   const SizedBox(height: 16),
//                   _buildQuickActions(context),
//                   const SizedBox(height: 30),
//                   const Text(
//                     "MY LATEST ORDERS",
//                     style: TextStyle(
//                       fontWeight: FontWeight.bold,
//                       color: Colors.grey,
//                       letterSpacing: 1.2,
//                     ),
//                   ),
//                   const SizedBox(height: 20),
//                   _buildEmptyState(),
//                   const SizedBox(height: 40),
//                 ],
//               ),
//             ),
//           ),
//           // Pass context to the helper method
//           _buildClockInButton(context),
//         ],
//       ),
//       bottomNavigationBar: _buildBottomNav(),
//     );
//   }

//   Widget _buildQuickActions(BuildContext context) {
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//       children: [
//         _actionBtn(
//           "Agrovet",
//           Icons.storefront,
//           AppColors.primaryGreen,
//           onTap: () => Navigator.push(
//             context,
//             MaterialPageRoute(builder: (context) => const AgrovetOnboarding()),
//           ),
//         ),
//         _actionBtn(
//           "Farmer",
//           Icons.person_add_alt,
//           AppColors.primaryGreen,
//           onTap: () => Navigator.push(
//             context,
//             MaterialPageRoute(builder: (context) => const FarmerProfiling()),
//           ),
//         ),
//         _actionBtn(
//           "My Orders",
//           Icons.assignment_outlined,
//           AppColors.secondaryOrange,
//           onTap: () => Navigator.push(
//             context,
//             MaterialPageRoute(builder: (context) => const MyOrdersPage()),
//           ),
//         ),
//         _actionBtn(
//           "Inventory",
//           Icons.inventory_2_outlined,
//           AppColors.primaryGreen,
//           onTap: () => Navigator.push(
//             context,
//             MaterialPageRoute(builder: (context) => const InventoryPage()),
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _actionBtn(String label, IconData icon, Color color,
//       {required VoidCallback onTap}) {
//     return GestureDetector(
//       onTap: onTap,
//       child: Column(
//         children: [
//           CircleAvatar(
//             radius: 30,
//             backgroundColor: color.withOpacity(0.1),
//             child: Icon(icon, color: color, size: 28),
//           ),
//           const SizedBox(height: 8),
//           Text(
//             label,
//             style: const TextStyle(
//               fontSize: 11,
//               fontWeight: FontWeight.w600,
//               color: Colors.black87,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildSalesHeader() {
//     return Container(
//       padding: const EdgeInsets.only(top: 60, left: 24, right: 24, bottom: 30),
//       decoration: const BoxDecoration(
//         gradient: LinearGradient(
//           colors: [AppColors.primaryGreen, Color(0xFF004D2E)],
//           begin: Alignment.topLeft,
//           end: Alignment.bottomRight,
//         ),
//         borderRadius: BorderRadius.only(
//           bottomLeft: Radius.circular(30),
//           bottomRight: Radius.circular(30),
//         ),
//       ),
//       child: Column(
//         children: [
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               const Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text("Today's Sales",
//                       style: TextStyle(color: Colors.white70, fontSize: 16)),
//                   Text("KES 45,250",
//                       style: TextStyle(
//                           color: Colors.white,
//                           fontSize: 32,
//                           fontWeight: FontWeight.bold)),
//                 ],
//               ),
//               IconButton(
//                 icon: const Icon(Icons.account_balance_wallet_outlined,
//                     color: AppColors.accentYellow, size: 30),
//                 onPressed: () {},
//               ),
//             ],
//           ),
//           const SizedBox(height: 20),
//           Align(
//             alignment: Alignment.centerLeft,
//             child: Container(
//               padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//               decoration: BoxDecoration(
//                 color: Colors.white.withOpacity(0.2),
//                 borderRadius: BorderRadius.circular(20),
//               ),
//               child: const Text("● 12 Orders Today",
//                   style: TextStyle(
//                       color: AppColors.accentYellow,
//                       fontWeight: FontWeight.bold,
//                       fontSize: 12)),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildMetricsGrid() {
//     return GridView.count(
//       shrinkWrap: true,
//       physics: const NeverScrollableScrollPhysics(),
//       crossAxisCount: 2,
//       crossAxisSpacing: 15,
//       mainAxisSpacing: 15,
//       childAspectRatio: 1.3,
//       children: [
//         _metricCard("Daily Target", "15", Icons.ads_click, AppColors.secondaryOrange),
//         _metricCard("Weekly Target", "80", Icons.flag_outlined, AppColors.primaryGreen),
//         _metricCard("Visitations", "08", Icons.location_on_outlined, AppColors.secondaryOrange),
//         _metricCard("Weekly Visits", "42", Icons.trending_up, AppColors.primaryGreen),
//       ],
//     );
//   }

//   Widget _metricCard(String label, String value, IconData icon, Color color) {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(16),
//         boxShadow: [
//           BoxShadow(
//               color: Colors.black.withOpacity(0.03),
//               blurRadius: 10,
//               offset: const Offset(0, 4))
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Icon(icon, color: color, size: 24),
//           Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(value,
//                   style: const TextStyle(
//                       fontSize: 22, fontWeight: FontWeight.bold)),
//               Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildEmptyState() {
//     return Center(
//       child: Column(
//         children: [
//           Icon(Icons.inventory_outlined, size: 60, color: Colors.grey[300]),
//           const SizedBox(height: 10),
//           const Text("No orders found for today.",
//               style: TextStyle(color: Colors.grey)),
//         ],
//       ),
//     );
//   }

//   // UPDATED: Accepting context to enable navigation
//   Widget _buildClockInButton(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.all(20.0),
//       child: ElevatedButton.icon(
//         onPressed: () {
//           Navigator.push(
//             context,
//             MaterialPageRoute(builder: (context) => const ClockInPage()),
//           );
//         },
//         icon: const Icon(Icons.timer_outlined),
//         label: const Text(
//           "CLOCK IN FOR TODAY",
//           style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
//         ),
//         style: ElevatedButton.styleFrom(
//           backgroundColor: AppColors.secondaryOrange,
//           foregroundColor: Colors.white,
//           minimumSize: const Size(double.infinity, 60),
//           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//         ),
//       ),
//     );
//   }

//   Widget _buildBottomNav() {
//     return BottomNavigationBar(
//       selectedItemColor: AppColors.primaryGreen,
//       unselectedItemColor: Colors.grey,
//       showUnselectedLabels: true,
//       onTap: (index) {
//         if (index == 1) {
//           // Navigates to the MyShopsPage created earlier
//           Navigator.push(
//             context,
//             MaterialPageRoute(builder: (context) => const MyShopsPage()),
//           );
//         } else if (index == 2) {
//           // Placeholder for Alerts
//           ScaffoldMessenger.of(context).showSnackBar(
//             const SnackBar(content: Text("No new alerts")),
//           );
//         }
//       },
//       items: const [
//         BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: "Home"),
//         BottomNavigationBarItem(icon: Icon(Icons.store), label: "My Shops"),
//         BottomNavigationBarItem(
//             icon: Icon(Icons.notifications_none), label: "Alerts"),
//       ],
//     );
//   }
// }
import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../dashboard/agrovet_onboarding.dart';
import '../dashboard/farmer_profiling.dart';
import '../dashboard/my_orders_page.dart';
import '../dashboard/sample_distribution_page.dart';
import '../dashboard/my_shops_page.dart';
import 'bas_alerts_page.dart';
import 'user_profile_page.dart';
import 'messages_page.dart';
import '../../core/constants/grounds_screens.dart';
import '../../core/constants/agent_screens.dart';
import '../../features/database/database_service.dart';
import '../../models/task_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SalesDashboard extends StatelessWidget {
  const SalesDashboard({super.key});

  static final DatabaseService _dbService = DatabaseService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F7),
      body: Column(
        children: [
          _buildSalesHeader(context),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "PERFORMANCE",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildMetricsGrid(),
                  const SizedBox(height: 30),
                  const Text(
                    "ASSIGNED TASKS",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FutureBuilder<List<TaskModel>>(
                    future: _loadAssignedTasks(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      if (snapshot.hasError) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Text(
                            'Failed to load tasks: ${snapshot.error}',
                            style: const TextStyle(color: Colors.red),
                          ),
                        );
                      }

                      final tasks = snapshot.data ?? const <TaskModel>[];
                      if (tasks.isEmpty) {
                        return _buildEmptyTaskState();
                      }
                      return _buildAssignedTasks(context, tasks);
                    },
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    "QUICK ACTIONS",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildQuickActions(context),
                  const SizedBox(height: 30),
                  const Text(
                    "MY LATEST ORDERS",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildEmptyState(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
      // Passed context here to enable navigation within the BottomNav
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  Future<List<TaskModel>> _loadAssignedTasks() async {
    final role = await _dbService.getCurrentUserRole();
    return _dbService.getTasksForRole(role);
  }

  // --- UI Components ---

  Widget _buildQuickActions(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      alignment: WrapAlignment.spaceBetween,
      children: [
        _actionBtn(
          "Schools",
          Icons.school_outlined,
          AppColors.primaryGreen,
          onTap:
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SchoolOnboarding(),
                ),
              ),
        ),
        _actionBtn(
          "Profiles",
          Icons.person_search_outlined,
          AppColors.primaryGreen,
          onTap:
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SchoolProfiling(),
                ),
              ),
        ),
        _actionBtn(
          "Samples",
          Icons.inventory_2_outlined,
          AppColors.secondaryOrange,
          onTap:
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SampleDistributionPage(),
                ),
              ),
        ),
        _actionBtn(
          "Orders",
          Icons.assignment_outlined,
          AppColors.primaryGreen,
          onTap:
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MyOrdersPage()),
              ),
        ),
        _actionBtn(
          "Messages",
          Icons.chat_bubble_outline,
          AppColors.secondaryOrange,
          onTap:
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MessagesPage()),
              ),
        ),
        _actionBtn(
          "Deliveries",
          Icons.local_shipping_outlined,
          AppColors.infoBlue,
          onTap:
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const GroundsDeliveriesScreen(),
                ),
              ),
        ),
      ],
    );
  }

  Widget _actionBtn(
    String label,
    IconData icon,
    Color color, {
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: color.withOpacity(0.1),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 60, left: 24, right: 24, bottom: 30),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryGreen, Color(0xFF004D2E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Today's School Visits",
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      "KES 45,250",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.sync, color: Colors.white, size: 30),
                    onPressed: () async {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Syncing data...')),
                      );
                      try {
                        await _dbService.syncData();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Data synced successfully!'),
                              backgroundColor: AppColors.primaryGreen,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Sync failed: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.person_outline,
                      color: AppColors.accentYellow,
                      size: 30,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const UserProfilePage(),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.logout,
                      color: Colors.white,
                      size: 30,
                    ),
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
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                "● 12 Visits Today",
                style: TextStyle(
                  color: AppColors.accentYellow,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 15,
      mainAxisSpacing: 15,
      childAspectRatio: 1.3,
      children: [
        _metricCard(
          "School Target",
          "15",
          Icons.ads_click,
          AppColors.secondaryOrange,
        ),
        _metricCard(
          "Weekly Target",
          "80",
          Icons.flag_outlined,
          AppColors.primaryGreen,
        ),
        _metricCard(
          "Institution Leads",
          "08",
          Icons.location_on_outlined,
          AppColors.secondaryOrange,
        ),
        _metricCard(
          "Weekly Visits",
          "42",
          Icons.trending_up,
          AppColors.primaryGreen,
        ),
      ],
    );
  }

  Future<void> _markTaskComplete(BuildContext context, TaskModel task) async {
    try {
      await _dbService.updateTaskStatus(task.id, 'closed');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task marked as complete.')),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const SalesDashboard()),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update task: $e')),
      );
    }
  }

  Future<void> _deleteTask(BuildContext context, TaskModel task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Task'),
            content: Text('Delete "${task.title}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (confirmed != true) return;

    try {
      await _dbService.deleteTask(task.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task deleted.')),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const SalesDashboard()),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete task: $e')));
    }
  }

  Widget _buildAssignedTasks(BuildContext context, List<TaskModel> tasks) {
    return Column(
      children:
          tasks.map((task) {
            final dueText =
                task.dueAt == null
                    ? 'No due date'
                    : '${task.dueAt!.year}-${task.dueAt!.month.toString().padLeft(2, '0')}-${task.dueAt!.day.toString().padLeft(2, '0')}';
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.longhornMaroon.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.checklist_rounded,
                      color: AppColors.longhornMaroon,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          task.description,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(
                              Icons.schedule_outlined,
                              size: 16,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              dueText,
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.leafGreen.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                task.status,
                                style: const TextStyle(
                                  color: AppColors.longhornMaroon,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (task.status.toLowerCase() != 'closed') ...[
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              FilledButton.icon(
                                onPressed: () => _markTaskComplete(context, task),
                                icon: const Icon(Icons.check_circle_outline),
                                label: const Text('Mark Complete'),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                onPressed: () => _deleteTask(context, task),
                                icon: const Icon(Icons.delete_outline),
                                label: const Text('Delete'),
                              ),
                            ],
                          ),
                        ] else ...[
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerRight,
                            child: OutlinedButton.icon(
                              onPressed: () => _deleteTask(context, task),
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Delete'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
    );
  }

  Widget _buildEmptyTaskState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(Icons.assignment_outlined, size: 56, color: Colors.grey[300]),
          const SizedBox(height: 8),
          const Text(
            'No tasks assigned to your role yet.',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _metricCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        children: [
          Icon(Icons.inventory_outlined, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 10),
          const Text(
            "No visits found for today.",
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  // --- UPDATED BOTTOM NAVIGATION ---
  Widget _buildBottomNav(BuildContext context) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      selectedItemColor: AppColors.primaryGreen,
      unselectedItemColor: Colors.grey,
      showUnselectedLabels: true,
      currentIndex: 0, // Since this is the Dashboard, index 0 is active
      onTap: (index) {
        if (index == 1) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const SampleDistributionPage(),
            ),
          );
        } else if (index == 2) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const MyShopsPage()),
          );
        } else if (index == 3) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const BasAlertsPage()),
          );
        } else if (index == 4) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AgentSubmitOrderScreen(),
            ),
          );
        }
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: "Home"),
        BottomNavigationBarItem(
          icon: Icon(Icons.inventory_2_outlined),
          label: "Samples",
        ),
        BottomNavigationBarItem(icon: Icon(Icons.school), label: "My Schools"),
        BottomNavigationBarItem(
          icon: Icon(Icons.notifications_none),
          label: "Alerts",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.point_of_sale_outlined),
          label: "Pipeline",
        ),
      ],
    );
  }
}
