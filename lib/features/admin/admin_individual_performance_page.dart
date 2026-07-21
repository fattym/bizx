import 'package:flutter/material.dart';
import '../database/database_service.dart';
import '../../../models/user_model.dart';
import 'utils/csv_download_stub.dart'
    if (dart.library.html) 'utils/csv_download_web.dart'
    if (dart.library.io) 'utils/csv_download_io.dart';

class AdminIndividualPerformancePage extends StatefulWidget {
  const AdminIndividualPerformancePage({super.key});

  @override
  State<AdminIndividualPerformancePage> createState() =>
      _AdminIndividualPerformancePageState();
}

class _AdminIndividualPerformancePageState
    extends State<AdminIndividualPerformancePage> {
  final DatabaseService _dbService = DatabaseService();

  bool _isLoading = false;
  DateTime _selectedDate = DateTime.now();
  String? _selectedUserId;
  bool _weeklyMode = false;
  int _loadToken = 0;
  List<UserModel> _users = [];
  List<_UserDailyPerformance> _rows = [];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    final users = await _dbService.getAllUsers();
    if (mounted) {
      setState(() {
        _users = users.where((u) => u.role != 1).toList();
        _isLoading = false;
      });
      _loadPerformance();
    }
  }

  Future<void> _loadPerformance() async {
    if (_users.isEmpty) return;
    final token = ++_loadToken;
    setState(() => _isLoading = true);

    final dayStart = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    final start = _weeklyMode ? _startOfWeek(dayStart) : dayStart;
    final end = _weeklyMode
        ? start.add(const Duration(days: 5))
        : dayStart.add(const Duration(days: 1));

    final selected = _selectedUserId == null
        ? _users
        : _users.where((u) => u.id == _selectedUserId).toList();

    // Fetch every user's metrics concurrently instead of one-by-one so the
    // whole roster loads in a single batched round-trip rather than N serial
    // round-trips (which made the page feel slow / "loading too much").
    final futures = selected.map((user) async {
      final metrics = await _dbService.getIndividualPerformance(
        agentId: user.id,
        start: start,
        end: end,
      );
      return _UserDailyPerformance(
        user: user,
        visits: metrics['visits'] ?? 0,
        orders: metrics['orders'] ?? 0,
        wonSales: metrics['wonSales'] ?? 0,
        visitedSchools: metrics['visitedSchools'] ?? 0,
        percent: metrics['percent'] ?? 0,
      );
    });

    List<_UserDailyPerformance> rows;
    try {
      rows = await Future.wait(futures);
    } catch (e) {
      if (token != _loadToken) return;
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load data: $e')));
      }
      return;
    }

    if (token != _loadToken) return;
    if (mounted) {
      setState(() {
        _rows = rows;
        _isLoading = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _loadPerformance();
    }
  }

  String _csvEscape(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }

  Future<void> _exportExcel() async {
    if (_rows.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No data to export.')));
      return;
    }

    final headers = [
      'Name',
      'Email',
      'Role',
      _weeklyMode ? 'Week Of (5-Day)' : 'Date',
      'Visits',
      'Orders',
      'Won Sales',
      'Schools Visited',
      'Target %',
    ];
    final buffer = StringBuffer('${headers.map(_csvEscape).join(',')}\n');

    for (final row in _rows) {
      final values = [
        row.user.fullName ?? '',
        row.user.email,
        _roleLabel(row.user.role),
        _periodLabel(),
        row.visits.toString(),
        row.orders.toString(),
        row.wonSales.toString(),
        row.visitedSchools.toString(),
        '${row.percent}%',
      ];
      buffer.writeln(values.map(_csvEscape).join(','));
    }

    final fileName =
        'individual_performance_${_weeklyMode ? '5day_' : ''}${_formatDate(_selectedDate)}.csv';

    try {
      await downloadCsvTemplate(fileName, buffer.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved to Downloads: $fileName')),
        );
      }
    } on UnsupportedError {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Download not supported on this device.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  DateTime _startOfWeek(DateTime dt) {
    final weekday = dt.weekday; // Monday = 1 ... Sunday = 7
    return dt.subtract(Duration(days: weekday - 1));
  }

  String _periodLabel() {
    if (!_weeklyMode) return _formatDate(_selectedDate);
    final start = _startOfWeek(
      DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day),
    );
    final end = start.add(const Duration(days: 6));
    return '${_formatDate(start)} to ${_formatDate(end)}';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_weeklyMode ? 'Individual 5-Day Performance' : 'Individual Daily Performance'),
        backgroundColor: const Color(0xFF6D273F),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Export to Excel',
            onPressed: _exportExcel,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFilters(),
            const SizedBox(height: 8),
            Text(
              _weeklyMode
                  ? 'Showing 5-day week (Mon-Fri): ${_periodLabel()}'
                  : 'Showing day: ${_periodLabel()}',
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _rows.isEmpty
                  ? const Center(child: Text('No performance data found.'))
                  : _buildTable(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: _pickDate,
          icon: const Icon(Icons.calendar_today),
          label: Text(
            _weeklyMode ? 'Week of: ${_formatDate(_startOfWeek(_selectedDate))}' : 'Date: ${_formatDate(_selectedDate)}',
          ),
        ),
        SegmentedButton<bool>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment<bool>(value: false, label: Text('Day')),
            ButtonSegment<bool>(value: true, label: Text('5-Day')),
          ],
          selected: {_weeklyMode},
          onSelectionChanged: (selection) {
            final weekly = selection.first;
            if (weekly != _weeklyMode) {
              setState(() => _weeklyMode = weekly);
              _loadPerformance();
            }
          },
        ),
        DropdownButton<String?>(
          value: _selectedUserId,
          hint: const Text('All Individuals'),
          underline: const SizedBox.shrink(),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('All Individuals'),
            ),
            ..._users.map(
              (u) => DropdownMenuItem<String?>(
                value: u.id,
                child: Text(u.fullName ?? u.email),
              ),
            ),
          ],
          onChanged: (value) {
            setState(() => _selectedUserId = value);
            _loadPerformance();
          },
        ),
        ElevatedButton.icon(
          onPressed: _loadPerformance,
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh'),
        ),
      ],
    );
  }

  Widget _buildTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Name')),
          DataColumn(label: Text('Role')),
          DataColumn(label: Text('Visits')),
          DataColumn(label: Text('Orders')),
          DataColumn(label: Text('Won Sales')),
          DataColumn(label: Text('Schools Visited')),
          DataColumn(label: Text('Target %')),
        ],
        rows: _rows.map((row) {
          return DataRow(
            cells: [
              DataCell(Text(row.user.fullName ?? row.user.email)),
              DataCell(Text(_roleLabel(row.user.role))),
              DataCell(Text(row.visits.toString())),
              DataCell(Text(row.orders.toString())),
              DataCell(Text(row.wonSales.toString())),
              DataCell(Text(row.visitedSchools.toString())),
              DataCell(Text('${row.percent}%')),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _UserDailyPerformance {
  final UserModel user;
  final int visits;
  final int orders;
  final int wonSales;
  final int visitedSchools;
  final int percent;

  _UserDailyPerformance({
    required this.user,
    required this.visits,
    required this.orders,
    required this.wonSales,
    required this.visitedSchools,
    required this.percent,
  });
}
