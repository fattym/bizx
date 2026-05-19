import 'package:flutter/material.dart';

import '../../core/constants/colors.dart';
import '../../models/farmer_model.dart';
import '../../models/user_model.dart';
import '../database/database_service.dart';

class UserSchoolOnboardingPage extends StatefulWidget {
  const UserSchoolOnboardingPage({super.key});

  @override
  State<UserSchoolOnboardingPage> createState() =>
      _UserSchoolOnboardingPageState();
}

class _UserSchoolOnboardingPageState extends State<UserSchoolOnboardingPage> {
  final DatabaseService _dbService = DatabaseService();
  late Future<_UserSchoolData> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadData();
  }

  Future<_UserSchoolData> _loadData() async {
    final users = await _dbService.getAllUsers();
    final schools = await _dbService.getAllSchools();
    return _UserSchoolData(users: users, schools: schools);
  }

  void _refresh() {
    setState(() {
      _future = _loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Onboarding Tracker'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: FutureBuilder<_UserSchoolData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Failed to load data: ${snapshot.error}'),
            );
          }

          final data =
              snapshot.data ??
              const _UserSchoolData(users: <UserModel>[], schools: <SchoolModel>[]);

          final schoolsByUser = <String, List<SchoolModel>>{};
          for (final school in data.schools) {
            final userId = (school.capturedBy ?? '').trim();
            if (userId.isEmpty) continue;
            schoolsByUser.putIfAbsent(userId, () => <SchoolModel>[]).add(school);
          }

          final userRows =
              data.users.map((user) {
                final userSchools = schoolsByUser[user.id] ?? <SchoolModel>[];
                return _UserSchoolRow(user: user, schools: userSchools);
              }).toList()
                ..sort((a, b) => b.schools.length.compareTo(a.schools.length));

          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSummaryCard(data.users.length, data.schools.length),
                const SizedBox(height: 12),
                if (userRows.isEmpty)
                  _buildEmptyCard('No users found yet.')
                else
                  ...userRows.map((row) => _buildUserCard(row)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard(int userCount, int schoolCount) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: _metric('Users', '$userCount'),
          ),
          Expanded(
            child: _metric('Onboarded Schools', '$schoolCount'),
          ),
        ],
      ),
    );
  }

  Widget _metric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryGreen,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: Colors.grey.shade700)),
      ],
    );
  }

  Widget _buildUserCard(_UserSchoolRow row) {
    final name = (row.user.fullName?.trim().isNotEmpty ?? false)
        ? row.user.fullName!.trim()
        : row.user.email;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.12),
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: const TextStyle(color: AppColors.primaryGreen),
          ),
        ),
        title: Text(name),
        subtitle: Text('Role ${row.user.role} • ${row.schools.length} schools'),
        children: [
          if (row.schools.isEmpty)
            const ListTile(
              title: Text('No schools onboarded yet.'),
            )
          else
            ...row.schools.map(
              (school) => ListTile(
                title: Text(school.name),
                subtitle: Text('${school.county} • ${school.phone}'),
                trailing: Text(
                  school.isSynced ? 'Synced' : 'Pending',
                  style: TextStyle(
                    color:
                        school.isSynced ? AppColors.primaryGreen : Colors.orange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyCard(String message) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(message, textAlign: TextAlign.center),
    );
  }
}

class _UserSchoolData {
  const _UserSchoolData({
    required this.users,
    required this.schools,
  });

  final List<UserModel> users;
  final List<SchoolModel> schools;
}

class _UserSchoolRow {
  const _UserSchoolRow({
    required this.user,
    required this.schools,
  });

  final UserModel user;
  final List<SchoolModel> schools;
}

