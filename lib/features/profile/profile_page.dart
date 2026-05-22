import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../dashboard/agrovet_onboarding.dart';
import '../dashboard/farmer_profiling.dart';
import '../dashboard/my_orders_page.dart';
import '../dashboard/sample_distribution_page.dart';
import '../dashboard/grounds_quotation_page.dart';
import '../dashboard/my_shops_page.dart';
import 'bas_alerts_page.dart';
import 'crm_settings_page.dart';
import 'user_profile_page.dart';
import 'messages_page.dart';
import '../../core/constants/grounds_screens.dart';
import '../../core/constants/agent_screens.dart';
import '../../features/database/database_service.dart';
import '../../models/task_model.dart';
import '../project/role5_project_forms_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SalesDashboard extends StatefulWidget {
  const SalesDashboard({super.key});

  @override
  State<SalesDashboard> createState() => _SalesDashboardState();
}

class _SalesDashboardState extends State<SalesDashboard> {
  final DatabaseService _dbService = DatabaseService();
  bool _showAssignedTasks = false;
  bool _autoHideAssignedTasks = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEAF5EE), Color(0xFFF8FCF9)],
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isSmall = constraints.maxWidth < 700;
            final contentWidth = constraints.maxWidth >= 1200 ? 1100.0 : 900.0;
            return SingleChildScrollView(
              child: Column(
                children: [
                  _buildSalesHeader(context),
                  Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: contentWidth),
                      child: Padding(
                        padding: EdgeInsets.all(isSmall ? 16 : 20),
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
                            Row(
                              children: [
                                const Text(
                                  "ASSIGNED TASKS",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const Spacer(),
                                const Text(
                                  "Auto-hide",
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textMuted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Switch.adaptive(
                                  value: _autoHideAssignedTasks,
                                  onChanged: (value) {
                                    setState(() {
                                      _autoHideAssignedTasks = value;
                                    });
                                  },
                                ),
                                IconButton(
                                  tooltip:
                                      _showAssignedTasks
                                          ? 'Hide tasks'
                                          : 'Show tasks',
                                  icon: Icon(
                                    _showAssignedTasks
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: AppColors.primaryDark,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _showAssignedTasks = !_showAssignedTasks;
                                    });
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (_showAssignedTasks)
                              FutureBuilder<List<TaskModel>>(
                                future: _loadAssignedTasks(),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 24,
                                      ),
                                      child: Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    );
                                  }

                                  if (snapshot.hasError) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 20,
                                      ),
                                      child: Text(
                                        'Failed to load tasks: ${snapshot.error}',
                                        style: const TextStyle(
                                          color: Colors.red,
                                        ),
                                      ),
                                    );
                                  }

                                  final tasks =
                                      snapshot.data ?? const <TaskModel>[];
                                  if (tasks.isEmpty) {
                                    return _buildEmptyTaskState();
                                  }
                                  return _buildAssignedTasks(context, tasks);
                                },
                              )
                            else
                              _buildAssignedTasksHiddenState(),
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
                  ),
                ],
              ),
            );
          },
        ),
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
        _actionBtn(
          "Survey",
          Icons.assignment_turned_in_outlined,
          AppColors.infoBlue,
          onTap:
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const Role5ProjectFormsPage(),
                ),
              ),
        ),
        _actionBtn(
          "Quotation",
          Icons.request_quote_outlined,
          AppColors.primaryGreen,
          onTap: () async {
            final role = await _dbService.getCurrentUserRole();
            if (!context.mounted) return;
            if (role != 5) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Only Role 5 can create quotations.'),
                ),
              );
              return;
            }
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const GroundsQuotationPage(),
              ),
            );
          },
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
            backgroundColor: color.withValues(alpha: 0.1),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 420;
        return Container(
          padding: EdgeInsets.only(
            top: isCompact ? 48 : 60,
            left: isCompact ? 16 : 24,
            right: isCompact ? 16 : 24,
            bottom: isCompact ? 24 : 32,
          ),
          decoration: const BoxDecoration(
            color: Color(0xFF81BD42),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(32),
              bottomRight: Radius.circular(32),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                offset: Offset(0, 4),
                blurRadius: 8,
              ),
            ],
          ),
          child: Column(
            children: [
              // Top Action Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const UserProfilePage(),
                            ),
                          );
                        },
                        child: CircleAvatar(
                          backgroundColor: Colors.white.withValues(alpha: 0.15),
                          radius: isCompact ? 20 : 24,
                          child: Icon(
                            Icons.person,
                            color: AppColors.textDark,
                            size: isCompact ? 22 : 26,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Welcome Back,",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: isCompact ? 12 : 14,
                            ),
                          ),
                          Text(
                            "Agent",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isCompact ? 15 : 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.sync,
                          color: Colors.white,
                          size: isCompact ? 24 : 28,
                        ),
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
                      PopupMenuButton<String>(
                        icon: Icon(
                          Icons.more_vert,
                          color: Colors.white,
                          size: isCompact ? 24 : 28,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        onSelected: (value) async {
                          if (value == 'settings') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const CrmSettingsPage(),
                              ),
                            );
                          } else if (value == 'logout') {
                            await Supabase.instance.client.auth.signOut();
                            if (context.mounted) {
                              Navigator.pushNamedAndRemoveUntil(
                                context,
                                '/',
                                (route) => false,
                              );
                            }
                          }
                        },
                        itemBuilder:
                            (BuildContext context) => [
                              PopupMenuItem(
                                value: 'settings',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.settings_outlined,
                                      color: AppColors.primaryDark,
                                    ),
                                    const SizedBox(width: 12),
                                    const Text('Settings'),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'logout',
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.logout,
                                      color: Colors.redAccent,
                                    ),
                                    const SizedBox(width: 12),
                                    const Text(
                                      'Logout',
                                      style: TextStyle(color: Colors.redAccent),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: isCompact ? 24 : 32),
              // Main Value Area
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(isCompact ? 12 : 16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Today's School Visits",
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: isCompact ? 13 : 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isCompact ? 10 : 12,
                            vertical: isCompact ? 4 : 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.textDark.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                color: AppColors.textDark,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                "12 Visits",
                                style: TextStyle(
                                  color: AppColors.surfaceWhite,
                                  fontWeight: FontWeight.bold,
                                  fontSize: isCompact ? 11 : 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isCompact ? 12 : 16),
                    Text(
                      "KES 45,250",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isCompact ? 26 : 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricsGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isCompact = width < 380;
        final isWide = width >= 980;
        final crossAxisCount = isCompact ? 1 : (isWide ? 5 : 2);
        final aspectRatio = isCompact ? 2.15 : (isWide ? 1.0 : 1.18);

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: aspectRatio,
          children: [
            _metricCard(
              "Daily Performance",
              "87%",
              Icons.today_outlined,
              AppColors.primaryGreen,
              compact: isCompact,
              schoolTarget: '15',
              weeklyTarget: '80',
              institutionLeads: '08',
              weeklyVisits: '12',
            ),
            _metricCard(
              "Weekly Performance",
              "90%",
              Icons.view_week_outlined,
              AppColors.primaryDark,
              compact: isCompact,
              schoolTarget: '35',
              weeklyTarget: '200',
              institutionLeads: '20',
              weeklyVisits: '30',
            ),
            _metricCard(
              "Monthly Performance",
              "91%",
              Icons.calendar_month_outlined,
              AppColors.secondaryOrange,
              compact: isCompact,
              schoolTarget: '60',
              weeklyTarget: '320',
              institutionLeads: '34',
              weeklyVisits: '48',
            ),
            _metricCard(
              "Quarterly Performance",
              "89%",
              Icons.date_range_outlined,
              AppColors.primaryGreen,
              compact: isCompact,
              schoolTarget: '180',
              weeklyTarget: '960',
              institutionLeads: '102',
              weeklyVisits: '144',
            ),
            _metricCard(
              "Yearly Performance",
              "93%",
              Icons.insights_outlined,
              AppColors.secondaryOrange,
              compact: isCompact,
              schoolTarget: '720',
              weeklyTarget: '3840',
              institutionLeads: '408',
              weeklyVisits: '576',
            ),
          ],
        );
      },
    );
  }

  Future<void> _markTaskComplete(BuildContext context, TaskModel task) async {
    try {
      await _dbService.updateTaskStatus(task.id, 'closed');
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Task marked as complete.')));
      setState(() {
        if (_autoHideAssignedTasks) _showAssignedTasks = false;
      });
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update task: $e')));
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Task deleted.')));
      setState(() {
        if (_autoHideAssignedTasks) _showAssignedTasks = false;
      });
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
            return LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 420;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: EdgeInsets.all(isCompact ? 12 : 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: isCompact ? 38 : 44,
                        height: isCompact ? 38 : 44,
                        decoration: BoxDecoration(
                          color: AppColors.longhornMaroon.withValues(
                            alpha: 0.1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.checklist_rounded,
                          color: AppColors.longhornMaroon,
                          size: 20,
                        ),
                      ),
                      SizedBox(width: isCompact ? 10 : 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              task.title,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: isCompact ? 14 : 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              task.description,
                              style: TextStyle(
                                color: Colors.black87,
                                fontSize: isCompact ? 12 : 13,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.schedule_outlined,
                                      size: 15,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      dueText,
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: isCompact ? 11 : 12,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.leafGreen.withValues(
                                      alpha: 0.12,
                                    ),
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
                            const SizedBox(height: 10),
                            if (task.status.toLowerCase() != 'closed')
                              isCompact
                                  ? Column(
                                    children: [
                                      SizedBox(
                                        width: double.infinity,
                                        child: FilledButton.icon(
                                          onPressed:
                                              () => _markTaskComplete(
                                                context,
                                                task,
                                              ),
                                          icon: const Icon(
                                            Icons.check_circle_outline,
                                          ),
                                          label: const Text('Mark Complete'),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      SizedBox(
                                        width: double.infinity,
                                        child: OutlinedButton.icon(
                                          onPressed:
                                              () => _deleteTask(context, task),
                                          icon: const Icon(
                                            Icons.delete_outline,
                                          ),
                                          label: const Text('Delete'),
                                        ),
                                      ),
                                    ],
                                  )
                                  : Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      FilledButton.icon(
                                        onPressed:
                                            () => _markTaskComplete(
                                              context,
                                              task,
                                            ),
                                        icon: const Icon(
                                          Icons.check_circle_outline,
                                        ),
                                        label: const Text('Mark Complete'),
                                      ),
                                      const SizedBox(width: 8),
                                      OutlinedButton.icon(
                                        onPressed:
                                            () => _deleteTask(context, task),
                                        icon: const Icon(Icons.delete_outline),
                                        label: const Text('Delete'),
                                      ),
                                    ],
                                  )
                            else
                              SizedBox(
                                width: isCompact ? double.infinity : null,
                                child: Align(
                                  alignment:
                                      isCompact
                                          ? Alignment.centerLeft
                                          : Alignment.centerRight,
                                  child: OutlinedButton.icon(
                                    onPressed: () => _deleteTask(context, task),
                                    icon: const Icon(Icons.delete_outline),
                                    label: const Text('Delete'),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
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
            color: Colors.black.withValues(alpha: 0.03),
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

  Widget _buildAssignedTasksHiddenState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderGrey),
      ),
      child: const Text(
        'Assigned tasks are hidden. Use the eye icon to show.',
        style: TextStyle(color: AppColors.textMuted, fontSize: 12),
      ),
    );
  }

  Widget _metricCard(
    String label,
    String value,
    IconData icon,
    Color color, {
    required bool compact,
    required String schoolTarget,
    required String weeklyTarget,
    required String institutionLeads,
    required String weeklyVisits,
  }) {
    return Container(
      padding: EdgeInsets.all(compact ? 8 : 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: compact ? 11 : 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryDark,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 4 : 6),
          Text(
            value,
            style: TextStyle(
              fontSize: compact ? 18 : 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: compact ? 2 : 4),
          _periodMetricRow('School Target', schoolTarget, compact: compact),
          _periodMetricRow('Weekly Target', weeklyTarget, compact: compact),
          _periodMetricRow(
            'Institution Leads',
            institutionLeads,
            compact: compact,
          ),
          _periodMetricRow('Weekly Visits', weeklyVisits, compact: compact),
        ],
      ),
    );
  }

  Widget _periodMetricRow(String label, String value, {required bool compact}) {
    return Padding(
      padding: EdgeInsets.only(top: compact ? 1 : 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: compact ? 9 : 10,
                color: AppColors.textMuted,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: compact ? 9 : 10,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryDark,
            ),
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
