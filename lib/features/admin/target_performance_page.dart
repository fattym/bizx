import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/colors.dart';
import '../../core/config/api_config.dart';
import '../../models/target_model.dart';
import '../../models/region_model.dart';
import '../../models/user_model.dart';
import '../database/database_service.dart';

class TargetPerformancePage extends StatefulWidget {
  const TargetPerformancePage({super.key});

  @override
  State<TargetPerformancePage> createState() => _TargetPerformancePageState();
}

class _TargetPerformancePageState extends State<TargetPerformancePage> with SingleTickerProviderStateMixin {
  final DatabaseService _dbService = DatabaseService();
  bool _isLoading = true;
  int _currentUserRole = 5;
  String? _currentUserId;
  String _selectedScope = 'regional';
  String? _selectedRegionId;
  String? _selectedSubRegion;
  String? _selectedAssigneeId;
  late TabController _tabController;
  List<RegionModel> _regions = [];
  List<UserModel> _agents = [];
  List<UserModel> _businessAdvisors = [];
  List<UserModel> _salesReps = [];
  List<_PerformanceRow> _rows = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser != null) {
        final user = await _dbService.getUser(currentUser.id);
        _currentUserId = currentUser.id;
        _currentUserRole = user?.role ?? 5;
      }

      if (_currentUserRole > 2) {
        _selectedScope = 'individual';
      }

      final regions = await _dbService.getAllRegions();
      final users = await _dbService.getAllUsers();
      final agents = users.where((u) => u.role == 4).toList();
      final businessAdvisors = users.where((u) => u.role == 3).toList();
      final salesReps = users.where((u) => u.role == 5).toList();

      if (!mounted) return;
      setState(() {
        _regions = regions;
        _agents = agents;
        _businessAdvisors = businessAdvisors;
        _salesReps = salesReps;
        _isLoading = false;
      });

      await _loadPerformance();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading performance: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<List<TargetModel>> _loadTargets() async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      var query = Supabase.instance.client.from('targets').select();
      if (_currentUserRole > 2 && currentUser != null) {
        query = query.or('assigned_to.eq.${currentUser.id},assigned_to.is.null');
      }
      final data = await query.order('created_at', ascending: false);
      return (data as List).map((item) => TargetModel.fromMap(Map<String, dynamic>.from(item))).toList();
    } catch (e) {
      debugPrint('Error loading targets: $e');
      return <TargetModel>[];
    }
  }

  Future<void> _loadPerformance() async {
    setState(() => _isLoading = true);
    try {
      final targets = await _loadTargets();
      final assignees = _getAssigneeList();
      final rows = <_PerformanceRow>[];
      for (final user in assignees) {
        rows.add(await _buildRow(user, targets));
      }
      if (!mounted) return;
      setState(() => _rows = rows);
      _isLoading = false;
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading performance: $e'), backgroundColor: Colors.red),
      );
    }
  }

  List<UserModel> _getAssigneeList() {
    if (_currentUserRole > 2) {
      for (final list in [_agents, _businessAdvisors, _salesReps]) {
        for (final u in list) {
          if (u.id == _currentUserId) return [u];
        }
      }
      return <UserModel>[];
    }
    switch (_selectedScope) {
      case 'regional':
        return _agents;
      case 'agent':
        return _selectedAssigneeId == null ? <UserModel>[] : _agents.where((a) => a.id == _selectedAssigneeId).toList();
      case 'business_advisor':
        return _selectedAssigneeId == null ? <UserModel>[] : _businessAdvisors.where((a) => a.id == _selectedAssigneeId).toList();
      case 'sales_rep':
        return _selectedAssigneeId == null ? <UserModel>[] : _salesReps.where((a) => a.id == _selectedAssigneeId).toList();
      case 'individual':
        for (final list in [_agents, _businessAdvisors, _salesReps]) {
          for (final u in list) {
            if (u.id == _selectedAssigneeId) return [u];
          }
        }
        return <UserModel>[];
      default:
        return <UserModel>[];
    }
  }

  bool _targetMatches(TargetModel target) {
    if (_currentUserRole > 2) {
      return target.assignedTo == _currentUserId || target.assignedTo == null;
    }
    if (target.scope != _selectedScope) return false;
    if (_selectedScope == 'regional') {
      final regionMatch = _selectedRegionId == null || target.regionId == _selectedRegionId;
      final subMatch = _selectedSubRegion == null || target.subRegion == _selectedSubRegion;
      return regionMatch && subMatch;
    }
    return target.assignedTo == _selectedAssigneeId || target.assignedTo == null;
  }

  Future<_PerformanceRow> _buildRow(UserModel user, List<TargetModel> targets) async {
    final relevantTargets = targets.where(_targetMatches).toList();

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final startOfWeek = startOfDay.subtract(Duration(days: startOfDay.weekday - 1));
    final startOfMonth = DateTime(now.year, now.month, 1);
    final startOfYear = DateTime(now.year, 1, 1);

    final productTargets = <String, Map<String, int>>{};
    final visitTargets = <String, int>{};
    final collectionTargets = <String, int>{};
    final customerTargets = <String, int>{};
    final sampleTargets = <String, int>{};
    final consignmentTargets = <String, int>{};

    for (final target in relevantTargets) {
      final data = target.targetData;
      switch (target.targetType) {
        case 'product_sales':
          productTargets[target.targetPeriod] = {
            'exercise_books': (data['exercise_books'] as int?) ?? 0,
            'pens': (data['pens'] as int?) ?? 0,
            'rulers': (data['rulers'] as int?) ?? 0,
          };
          break;
        case 'customer_visits':
          visitTargets[target.targetPeriod] = ((data['schools'] as int?) ?? 0) + ((data['institutions'] as int?) ?? 0) + ((data['bookshops'] as int?) ?? 0);
          break;
        case 'collections':
          collectionTargets[target.targetPeriod] = (data['amount'] as int?) ?? 0;
          break;
        case 'new_customers':
          customerTargets[target.targetPeriod] = (data['count'] as int?) ?? 0;
          break;
        case 'sample_distribution':
          sampleTargets[target.targetPeriod] = ((data['exercise_book_samples'] as int?) ?? 0) + ((data['pen_samples'] as int?) ?? 0);
          break;
        case 'consignment':
          consignmentTargets['max_active'] = (data['max_active_consignments'] as int?) ?? 0;
          consignmentTargets['max_overdue'] = (data['max_overdue_consignments'] as int?) ?? 0;
          consignmentTargets['max_value'] = (data['max_consignment_value'] as int?) ?? 0;
          break;
      }
    }

    final dayMetrics = await _dbService.getIndividualPerformance(agentId: user.id, start: startOfDay, end: startOfDay.add(const Duration(days: 1)));
    final weekMetrics = await _dbService.getIndividualPerformance(agentId: user.id, start: startOfWeek, end: startOfWeek.add(const Duration(days: 7)));
    final monthMetrics = await _dbService.getIndividualPerformance(agentId: user.id, start: startOfMonth, end: DateTime(now.year, now.month + 1, 1));
    final yearMetrics = await _dbService.getIndividualPerformance(agentId: user.id, start: startOfYear, end: DateTime(now.year + 1, 1, 1));

    final actualProducts = <String, int>{
      'daily': dayMetrics['wonSales'] ?? 0,
      'weekly': weekMetrics['wonSales'] ?? 0,
      'monthly': monthMetrics['wonSales'] ?? 0,
      'ytd': yearMetrics['wonSales'] ?? 0,
    };

    final actualVisits = <String, int>{
      'daily': dayMetrics['visits'] ?? 0,
      'weekly': weekMetrics['visits'] ?? 0,
      'monthly': monthMetrics['visits'] ?? 0,
      'ytd': yearMetrics['visits'] ?? 0,
    };

    final actualCollections = <String, int>{
      'daily': dayMetrics['orders'] ?? 0,
      'weekly': weekMetrics['orders'] ?? 0,
      'monthly': monthMetrics['orders'] ?? 0,
      'ytd': yearMetrics['orders'] ?? 0,
    };

    final actualCustomers = <String, int>{
      'daily': dayMetrics['visitedSchools'] ?? 0,
      'weekly': weekMetrics['visitedSchools'] ?? 0,
      'monthly': monthMetrics['visitedSchools'] ?? 0,
      'ytd': yearMetrics['visitedSchools'] ?? 0,
    };

    final actualSamples = <String, int>{
      'daily': 0,
      'weekly': 0,
      'monthly': 0,
      'ytd': 0,
    };

    final actualConsignments = <String, int>{
      'max_active': 0,
      'max_overdue': 0,
      'max_value': 0,
    };

    final percentages = <String, double>{};
    for (final period in ['daily', 'weekly', 'monthly', 'ytd']) {
      final productTarget = productTargets[period];
      final productActual = actualProducts[period] ?? 0;
      final productTargetValue = productTarget?.values.fold(0, (s, v) => s + v) ?? 0;
      percentages['$period-products'] = _pct(productActual, productTargetValue);

      final visitTarget = visitTargets[period] ?? 0;
      final visitActual = actualVisits[period] ?? 0;
      percentages['$period-visits'] = _pct(visitActual, visitTarget);

      final collectionTarget = collectionTargets[period] ?? 0;
      final collectionActual = actualCollections[period] ?? 0;
      percentages['$period-collections'] = _pct(collectionActual, collectionTarget);

      final customerTarget = customerTargets[period] ?? 0;
      final customerActual = actualCustomers[period] ?? 0;
      percentages['$period-customers'] = _pct(customerActual, customerTarget);

      final sampleTarget = sampleTargets[period] ?? 0;
      final sampleActual = actualSamples[period] ?? 0;
      percentages['$period-samples'] = _pct(sampleActual, sampleTarget);
    }

    return _PerformanceRow(
      user: user,
      productTargets: productTargets,
      visitTargets: visitTargets,
      collectionTargets: collectionTargets,
      customerTargets: customerTargets,
      sampleTargets: sampleTargets,
      consignmentTargets: consignmentTargets,
      actualProducts: actualProducts,
      actualVisits: actualVisits,
      actualCollections: actualCollections,
      actualCustomers: actualCustomers,
      actualSamples: actualSamples,
      actualConsignments: actualConsignments,
      percentages: percentages,
    );
  }

  double _pct(int actual, int target) {
    if (target == 0) return actual > 0 ? 100.0 : 0.0;
    final raw = (actual / target) * 100;
    return raw > 100.0 ? 100.0 : (raw < 0.0 ? 0.0 : raw);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Performance'),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: AppColors.surfaceWhite,
        actions: [
          if (_currentUserRole <= 2)
            IconButton(
              icon: const Icon(Icons.smart_toy),
              onPressed: _showAiAssistant,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPerformance,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildFilterCard(),
                _buildTabs(),
                Expanded(child: _buildContent()),
              ],
            ),
    );
  }

  Widget _buildFilterCard() {
    final isCompact = MediaQuery.of(context).size.width < 600;
    final isManager = _currentUserRole <= 2;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: isCompact ? 8 : 12, vertical: isCompact ? 8 : 12),
      padding: EdgeInsets.all(isCompact ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isCompact ? 12 : 16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.track_changes, size: 20, color: AppColors.primaryDark),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isManager ? 'Performance Overview' : 'My Performance',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: isCompact ? 14 : 16),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: isCompact ? 10 : 12),
          if (isManager) ...[
            DropdownButtonFormField<String>(
              value: _selectedScope,
              decoration: const InputDecoration(
                labelText: 'Scope',
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              items: const [
                DropdownMenuItem(value: 'regional', child: Text('Regional')),
                DropdownMenuItem(value: 'agent', child: Text('Agent')),
                DropdownMenuItem(value: 'business_advisor', child: Text('Business Advisor')),
                DropdownMenuItem(value: 'sales_rep', child: Text('Sales Rep')),
                DropdownMenuItem(value: 'individual', child: Text('Individual')),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _selectedScope = value;
                  _selectedRegionId = null;
                  _selectedSubRegion = null;
                  _selectedAssigneeId = null;
                });
                _loadPerformance();
              },
            ),
            SizedBox(height: isCompact ? 8 : 12),
            if (_selectedScope == 'regional')
              DropdownButtonFormField<String>(
                value: _selectedRegionId,
                decoration: const InputDecoration(
                  labelText: 'Region',
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                items: _regions.map((r) => DropdownMenuItem(value: r.id, child: Text(r.region))).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedRegionId = value;
                    _selectedSubRegion = null;
                  });
                  _loadPerformance();
                },
              )
            else
              DropdownButtonFormField<String>(
                value: _selectedAssigneeId,
                decoration: InputDecoration(
                  labelText: _selectedScope == 'agent'
                      ? 'Agent'
                      : _selectedScope == 'business_advisor'
                          ? 'Business Advisor'
                          : _selectedScope == 'sales_rep'
                              ? 'Sales Rep'
                              : 'Individual',
                  border: const OutlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                items: [
                  const DropdownMenuItem<String>(value: null, child: Text('Select...')),
                  ...(_selectedScope == 'agent'
                          ? _agents
                          : _selectedScope == 'business_advisor'
                              ? _businessAdvisors
                              : _selectedScope == 'sales_rep'
                                  ? _salesReps
                                  : [..._agents, ..._businessAdvisors, ..._salesReps])
                      .map((u) => DropdownMenuItem(value: u.id, child: Text(u.fullName ?? u.email))),
                ],
                onChanged: (value) {
                  setState(() => _selectedAssigneeId = value);
                  _loadPerformance();
                },
              ),
            if (_selectedScope == 'regional' && _selectedRegionId != null) ...[
              SizedBox(height: isCompact ? 8 : 12),
              DropdownButtonFormField<String>(
                value: _selectedSubRegion,
                decoration: const InputDecoration(
                  labelText: 'Sub Region',
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                items: _regions
                    .where((r) => r.id == _selectedRegionId && r.subRegion.trim().isNotEmpty)
                    .map((r) => DropdownMenuItem(value: r.subRegion.trim(), child: Text(r.subRegion.trim())))
                    .toList(),
                onChanged: (value) {
                  setState(() => _selectedSubRegion = value);
                  _loadPerformance();
                },
              ),
            ],
          ] else ...[
            Container(
              padding: EdgeInsets.symmetric(horizontal: isCompact ? 10 : 12, vertical: isCompact ? 8 : 10),
              decoration: BoxDecoration(
                color: AppColors.primaryDark.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(isCompact ? 10 : 12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person_outline, size: 18, color: AppColors.primaryDark),
                  const SizedBox(width: 8),
                  Text(
                    _currentUserId != null
                        ? 'Viewing your performance'
                        : 'Sign in to view performance',
                    style: TextStyle(fontSize: isCompact ? 13 : 14, color: AppColors.primaryDark, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTabs() {
    final isCompact = MediaQuery.of(context).size.width < 600;
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.grey.shade700,
        indicatorColor: AppColors.primaryGreen,
        indicator: BoxDecoration(
          color: AppColors.primaryGreen,
          borderRadius: BorderRadius.circular(isCompact ? 10 : 12),
        ),
        labelPadding: EdgeInsets.symmetric(horizontal: isCompact ? 12 : 16, vertical: isCompact ? 10 : 12),
        tabs: const [
          Tab(text: 'Products'),
          Tab(text: 'Visits'),
          Tab(text: 'Collections'),
          Tab(text: 'Customers'),
          Tab(text: 'Samples'),
          Tab(text: 'Consignments'),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildTab('product'),
        _buildTab('visit'),
        _buildTab('collection'),
        _buildTab('customer'),
        _buildTab('sample'),
        _buildTab('consignment'),
      ],
    );
  }

  Widget _buildTab(String category) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: _rows.isEmpty
          ? const Center(child: Text('No performance data found.'))
          : Column(
              children: _rows.map((row) {
                final isCompact = MediaQuery.of(context).size.width < 600;
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      title: Row(
                        children: [
                          CircleAvatar(
                            radius: isCompact ? 16 : 20,
                            backgroundColor: AppColors.primaryDark.withValues(alpha: 0.1),
                            child: Text(
                              (row.user.fullName ?? 'U')[0].toUpperCase(),
                              style: TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.bold, fontSize: isCompact ? 13 : 16),
                            ),
                          ),
                          SizedBox(width: isCompact ? 8 : 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(row.user.fullName ?? row.user.email, style: TextStyle(fontWeight: FontWeight.w700, fontSize: isCompact ? 14 : 16)),
                                Text(_roleLabel(row.user.role), style: TextStyle(fontSize: isCompact ? 11 : 12, color: Colors.grey.shade600)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      children: _buildDetails(row, category),
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }

  List<Widget> _buildDetails(_PerformanceRow row, String category) {
    final tiles = <Widget>[];

    switch (category) {
      case 'product':
        for (final period in ['daily', 'weekly', 'monthly', 'ytd']) {
          final target = row.productTargets[period];
          final actual = row.actualProducts[period] ?? 0;
          final percent = row.percentages['$period-products'] ?? 0.0;
          tiles.add(_buildTile('$period Products', target ?? const {}, actual, percent, 'units'));
        }
        break;
      case 'visit':
        for (final period in ['daily', 'weekly', 'monthly', 'ytd']) {
          final target = row.visitTargets[period];
          final actual = row.actualVisits[period] ?? 0;
          final percent = row.percentages['$period-visits'] ?? 0.0;
          tiles.add(_buildTile('$period Visits', target != null ? {'total': target} : const {}, actual, percent, 'visits'));
        }
        break;
      case 'collection':
        for (final period in ['daily', 'weekly', 'monthly']) {
          final target = row.collectionTargets[period];
          final actual = row.actualCollections[period] ?? 0;
          final percent = row.percentages['$period-collections'] ?? 0.0;
          tiles.add(_buildTile('$period Collections', target != null ? {'amount': target} : const {}, actual, percent, 'KES'));
        }
        break;
      case 'customer':
        for (final period in ['daily', 'weekly', 'monthly']) {
          final target = row.customerTargets[period];
          final actual = row.actualCustomers[period] ?? 0;
          final percent = row.percentages['$period-customers'] ?? 0.0;
          tiles.add(_buildTile('$period New Customers', target != null ? {'count': target} : const {}, actual, percent, 'customers'));
        }
        break;
      case 'sample':
        for (final period in ['weekly', 'monthly']) {
          final target = row.sampleTargets[period];
          final actual = row.actualSamples[period] ?? 0;
          final percent = row.percentages['$period-samples'] ?? 0.0;
          tiles.add(_buildTile('$period Samples', target != null ? {'total': target} : const {}, actual, percent, 'items'));
        }
        break;
      case 'consignment':
        tiles.add(_buildTile('Max Active Consignments', row.consignmentTargets['max_active'] != null ? {'limit': row.consignmentTargets['max_active']!} : const {}, row.actualConsignments['max_active'] ?? 0, 0.0, 'consignments'));
        tiles.add(_buildTile('Max Overdue Consignments', row.consignmentTargets['max_overdue'] != null ? {'limit': row.consignmentTargets['max_overdue']!} : const {}, row.actualConsignments['max_overdue'] ?? 0, 0.0, 'consignments'));
        tiles.add(_buildTile('Max Consignment Value', row.consignmentTargets['max_value'] != null ? {'limit': row.consignmentTargets['max_value']!} : const {}, row.actualConsignments['max_value'] ?? 0, 0.0, 'KES'));
        break;
    }

    return tiles;
  }

  Widget _buildTile(String title, Map<String, int> target, int actualValue, double percent, String unit) {
    final targetValue = target.values.fold(0, (sum, v) => sum + v);
    final color = percent >= 80 ? Colors.green : percent >= 50 ? Colors.orange : Colors.red;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 4),
                Text('Target: $targetValue $unit | Actual: $actualValue $unit', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${percent.round()}%',
              style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAiAssistant() async {
    final messages = <Map<String, String>>[];
    final controller = TextEditingController();
    final contextSummary = _buildPerformanceContext();
    bool isWaiting = false;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.smart_toy, color: AppColors.primaryDark),
                  const SizedBox(width: 8),
                  Expanded(child: Text('AI Assistant')),
                ],
              ),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                height: MediaQuery.of(context).size.height * 0.6,
                child: Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final msg = messages[index];
                          final isUser = msg['role'] == 'user';
                          return Align(
                            alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isUser ? AppColors.primaryDark : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                msg['content'] ?? '',
                                style: TextStyle(color: isUser ? Colors.white : Colors.black87),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    if (isWaiting)
                      const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: CircularProgressIndicator(),
                      ),
                  ],
                ),
              ),
              actions: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        decoration: const InputDecoration(
                          hintText: 'Ask about performance...',
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (value) {
                          if (value.trim().isEmpty || isWaiting) return;
                          _sendAiMessage(controller, messages, setState, contextSummary, (v) {
                            setState(() => isWaiting = v);
                          }).then((_) {
                            controller.clear();
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: isWaiting
                          ? null
                          : () {
                              if (controller.text.trim().isEmpty) return;
                              _sendAiMessage(controller, messages, setState, contextSummary, (v) {
                                setState(() => isWaiting = v);
                              }).then((_) {
                                controller.clear();
                              });
                            },
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _sendAiMessage(
    TextEditingController controller,
    List<Map<String, String>> messages,
    StateSetter setState,
    String contextSummary,
    void Function(bool) setWaiting,
  ) async {
    final userMessage = controller.text.trim();
    if (userMessage.isEmpty) return;

    setState(() {
      messages.add({'role': 'user', 'content': userMessage});
    });

    try {
      setWaiting(true);
      final response = await http.post(
        Uri.parse(ApiConfig.aiChatUrl()),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'messages': messages.map((m) => {'role': m['role'], 'content': m['content']}).toList(),
          'context': contextSummary,
        }),
      );

      setWaiting(false);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final assistantMessage = data['choices']?[0]?['message']?['content'] ?? 'Sorry, I could not generate a response.';
        setState(() {
          messages.add({'role': 'assistant', 'content': assistantMessage});
        });
      } else {
        setState(() {
          messages.add({'role': 'assistant', 'content': 'Error: ${response.statusCode}'});
        });
      }
    } catch (e) {
      setWaiting(false);
      setState(() {
        messages.add({'role': 'assistant', 'content': 'Error: $e'});
      });
    }
  }

  String _buildPerformanceContext() {
    final buffer = StringBuffer();
    buffer.writeln('Current Scope: $_selectedScope');
    if (_selectedScope == 'regional' && _selectedRegionId != null) {
      final region = _regions.firstWhere((r) => r.id == _selectedRegionId, orElse: () => _regions.first);
      buffer.writeln('Region: ${region.region}');
      if (_selectedSubRegion != null) {
        buffer.writeln('Sub Region: $_selectedSubRegion');
      }
    }
    if (_selectedAssigneeId != null) {
      final assignee = _getAssigneeList().firstWhere((u) => u.id == _selectedAssigneeId, orElse: () => _getAssigneeList().first);
      buffer.writeln('Assignee: ${assignee.fullName ?? _selectedAssigneeId}');
    }
    buffer.writeln('\nPerformance Summary:');
    for (final row in _rows) {
      buffer.writeln('\n- ${row.user.fullName ?? row.user.email} (${_roleLabel(row.user.role)}):');
      for (final period in ['daily', 'weekly', 'monthly', 'ytd']) {
        final pProduct = row.percentages['$period-products'] ?? 0.0;
        final pVisit = row.percentages['$period-visits'] ?? 0.0;
        final pCollection = row.percentages['$period-collections'] ?? 0.0;
        buffer.writeln('  $period: Products ${pProduct.toStringAsFixed(1)}%, Visits ${pVisit.toStringAsFixed(1)}%, Collections ${pCollection.toStringAsFixed(1)}%');
      }
    }
    return buffer.toString();
  }

  String _roleLabel(int role) {
    switch (role) {
      case 2:
        return 'Sales Manager';
      case 3:
        return 'BAS';
      case 4:
        return 'Agent';
      case 5:
        return 'Grounds Person';
      default:
        return 'Role $role';
    }
  }
}

class _PerformanceRow {
  final UserModel user;
  final Map<String, Map<String, int>> productTargets;
  final Map<String, int> visitTargets;
  final Map<String, int> collectionTargets;
  final Map<String, int> customerTargets;
  final Map<String, int> sampleTargets;
  final Map<String, int> consignmentTargets;
  final Map<String, int> actualProducts;
  final Map<String, int> actualVisits;
  final Map<String, int> actualCollections;
  final Map<String, int> actualCustomers;
  final Map<String, int> actualSamples;
  final Map<String, int> actualConsignments;
  final Map<String, double> percentages;

  _PerformanceRow({
    required this.user,
    required this.productTargets,
    required this.visitTargets,
    required this.collectionTargets,
    required this.customerTargets,
    required this.sampleTargets,
    required this.consignmentTargets,
    required this.actualProducts,
    required this.actualVisits,
    required this.actualCollections,
    required this.actualCustomers,
    required this.actualSamples,
    required this.actualConsignments,
    required this.percentages,
  });
}
