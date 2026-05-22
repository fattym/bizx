import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/colors.dart';

class SampleReceiptsPage extends StatefulWidget {
  const SampleReceiptsPage({super.key});

  @override
  State<SampleReceiptsPage> createState() => _SampleReceiptsPageState();
}

class _SampleReceiptsPageState extends State<SampleReceiptsPage> {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _receiptRows = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _schoolRows = <Map<String, dynamic>>[];
  DateTimeRange? _dateRange;
  String? _countyFilter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final receiptsRes = await _supabase
          .from('school_sample_distributions')
          .select(
            'id, school_id, agent_id, sample_name, sample_category, quantity, notes, distributed_at, stamped_receipt_url, stamped_receipt_path, schools(name), users(full_name, email)',
          )
          .order('distributed_at', ascending: false)
          .limit(300);

      final schoolsRes = await _supabase
          .from('schools')
          .select('id,name,county,photo_url,sample_proof_url,created_at')
          .order('created_at', ascending: false)
          .limit(400);

      final ordersRes = await _supabase
          .from('orders')
          .select('agent_id, checkout_amount, status')
          .order('created_at', ascending: false)
          .limit(2000);

      final salesRes = await _supabase
          .from('school_sales')
          .select('agent_id, expected_value, sale_status')
          .order('created_at', ascending: false)
          .limit(2000);

      final receiptRows = List<Map<String, dynamic>>.from(
        (receiptsRes as List).map((e) => Map<String, dynamic>.from(e as Map)),
      );
      if (!mounted) return;
      setState(() {
        _receiptRows = receiptRows;
        _schoolRows = List<Map<String, dynamic>>.from(
          (schoolsRes as List).map((e) => Map<String, dynamic>.from(e as Map)),
        );
        _ordersCache = List<Map<String, dynamic>>.from(
          (ordersRes as List).map((e) => Map<String, dynamic>.from(e as Map)),
        );
        _salesCache = List<Map<String, dynamic>>.from(
          (salesRes as List).map((e) => Map<String, dynamic>.from(e as Map)),
        );
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load photos: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final schoolById = <String, Map<String, dynamic>>{
      for (final row in _schoolRows)
        if ((row['id']?.toString() ?? '').isNotEmpty) row['id'].toString(): row,
    };

    final filteredReceipts =
        _receiptRows.where((row) {
          final schoolId = row['school_id']?.toString() ?? '';
          final school = schoolById[schoolId];
          if (_countyFilter != null && _countyFilter!.trim().isNotEmpty) {
            final county = school?['county']?.toString() ?? '';
            if (county.toLowerCase() != _countyFilter!.toLowerCase()) {
              return false;
            }
          }
          if (_dateRange != null) {
            final raw = row['distributed_at']?.toString();
            final when = raw == null ? null : DateTime.tryParse(raw);
            if (when == null) return false;
            final start = DateTime(
              _dateRange!.start.year,
              _dateRange!.start.month,
              _dateRange!.start.day,
            );
            final end = DateTime(
              _dateRange!.end.year,
              _dateRange!.end.month,
              _dateRange!.end.day,
              23,
              59,
              59,
            );
            if (when.isBefore(start) || when.isAfter(end)) return false;
          }
          return true;
        }).toList();

    final filteredSchools =
        _schoolRows.where((row) {
          if (_countyFilter == null || _countyFilter!.trim().isEmpty) {
            return true;
          }
          final county = row['county']?.toString() ?? '';
          return county.toLowerCase() == _countyFilter!.toLowerCase();
        }).toList();

    final schoolPhotos =
        filteredSchools
            .where(
              (row) =>
                  (row['photo_url']?.toString().trim().isNotEmpty ?? false),
            )
            .toList();
    final sampleProofPhotos =
        filteredSchools
            .where(
              (row) =>
                  (row['sample_proof_url']?.toString().trim().isNotEmpty ??
                      false),
            )
            .toList();
    final stampedReceipts =
        filteredReceipts
            .where(
              (row) =>
                  (row['stamped_receipt_url']?.toString().trim().isNotEmpty ??
                      false),
            )
            .toList();
    final roiRows = _buildRoiRows(filteredReceipts, _ordersCache, _salesCache);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('All Photos'),
          actions: [
            IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'School Photos'),
              Tab(text: 'Sample Proofs'),
              Tab(text: 'Stamped Receipts'),
            ],
          ),
        ),
        body:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                )
                : Column(
                  children: [
                    _buildFiltersBar(),
                    _buildRoiSection(roiRows),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _load,
                        child: TabBarView(
                          children: [
                            _buildSchoolPhotoGrid(schoolPhotos),
                            _buildSampleProofGrid(sampleProofPhotos),
                            _buildReceiptsList(stampedReceipts),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
      ),
    );
  }

  Widget _buildFiltersBar() {
    final counties =
        _schoolRows
            .map((e) => (e['county']?.toString() ?? '').trim())
            .where((c) => c.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: _pickDateRange,
            icon: const Icon(Icons.calendar_month_outlined),
            label: Text(
              _dateRange == null
                  ? 'Date Range'
                  : '${_dateRange!.start.year}-${_dateRange!.start.month.toString().padLeft(2, '0')}-${_dateRange!.start.day.toString().padLeft(2, '0')} -> ${_dateRange!.end.year}-${_dateRange!.end.month.toString().padLeft(2, '0')}-${_dateRange!.end.day.toString().padLeft(2, '0')}',
            ),
          ),
          SizedBox(
            width: 210,
            child: DropdownButtonFormField<String?>(
              initialValue: _countyFilter,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'County',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('All Counties'),
                ),
                ...counties.map(
                  (c) => DropdownMenuItem<String?>(value: c, child: Text(c)),
                ),
              ],
              onChanged: (value) => setState(() => _countyFilter = value),
            ),
          ),
          if (_dateRange != null || _countyFilter != null)
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _dateRange = null;
                  _countyFilter = null;
                });
              },
              icon: const Icon(Icons.clear),
              label: const Text('Clear Filters'),
            ),
        ],
      ),
    );
  }

  Widget _buildRoiSection(List<_RoiRow> rows) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ROI By Person',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            'Samples given, schools reached, revenue earned.',
            style: TextStyle(color: Colors.grey[700], fontSize: 12),
          ),
          const SizedBox(height: 10),
          if (rows.isEmpty)
            const Text('No ROI data yet.')
          else
            ...rows.map(
              (row) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  radius: 14,
                  child: Text(
                    row.name.isNotEmpty ? row.name[0].toUpperCase() : '?',
                  ),
                ),
                title: Text(
                  row.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  'Samples: ${row.samplesGiven} • Schools: ${row.schoolsReached} • Revenue: KES ${row.revenueEarned.toStringAsFixed(0)}',
                ),
                trailing: Text(
                  'Won: ${row.wonValue.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSchoolPhotoGrid(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) {
      return const Center(child: Text('No school photos found.'));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.88,
      ),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        final url = row['photo_url']?.toString() ?? '';
        final schoolName = row['name']?.toString() ?? 'School';
        final county = row['county']?.toString() ?? 'Unknown County';
        return _photoCard(url: url, title: schoolName, subtitle: county);
      },
    );
  }

  Widget _buildSampleProofGrid(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) {
      return const Center(child: Text('No stamped sample proof photos found.'));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.88,
      ),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        final url = row['sample_proof_url']?.toString() ?? '';
        final schoolName = row['name']?.toString() ?? 'School';
        return _photoCard(
          url: url,
          title: schoolName,
          subtitle: 'Stamped Document',
        );
      },
    );
  }

  Widget _buildReceiptsList(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) {
      return const Center(child: Text('No stamped sample receipts found.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        final schoolName =
            row['schools']?['name']?.toString() ?? 'Unknown School';
        final sampleName = row['sample_name']?.toString() ?? 'Sample';
        final qty = row['quantity']?.toString() ?? '1';
        final url = row['stamped_receipt_url']?.toString() ?? '';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$sampleName -> $schoolName',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text('Qty: $qty'),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    url,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder:
                        (_, __, ___) => Container(
                          height: 120,
                          color: Colors.grey.shade200,
                          alignment: Alignment.center,
                          child: const Text('Could not load receipt image'),
                        ),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _openPreview(url),
                  icon: const Icon(Icons.open_in_full),
                  label: const Text('Open Receipt'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _photoCard({
    required String url,
    required String title,
    required String subtitle,
  }) {
    return InkWell(
      onTap: () => _openPreview(url),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Image.network(
                url,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder:
                    (_, __, ___) => Container(
                      color: Colors.grey.shade200,
                      alignment: Alignment.center,
                      child: const Text('Could not load'),
                    ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.longhornMaroon,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openPreview(String url) {
    showDialog<void>(
      context: context,
      builder:
          (_) => Dialog(child: InteractiveViewer(child: Image.network(url))),
    );
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5, 1, 1),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: _dateRange,
      helpText: 'Filter ROI By Date',
    );
    if (picked == null) return;
    setState(() => _dateRange = picked);
  }

  List<Map<String, dynamic>> _ordersCache = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _salesCache = <Map<String, dynamic>>[];

  List<_RoiRow> _buildRoiRows(
    List<Map<String, dynamic>> receiptRows,
    List<Map<String, dynamic>> orderRows,
    List<Map<String, dynamic>> salesRows,
  ) {
    final byAgent = <String, _RoiAccumulator>{};

    for (final row in receiptRows) {
      final agentId = row['agent_id']?.toString() ?? '';
      if (agentId.isEmpty) continue;
      final user = row['users'] as Map<String, dynamic>?;
      final displayName =
          user?['full_name']?.toString().trim().isNotEmpty == true
              ? user!['full_name'].toString().trim()
              : (user?['email']?.toString() ?? 'Unknown User');
      final qty = (row['quantity'] as num?)?.toInt() ?? 1;
      final schoolId = row['school_id']?.toString() ?? '';

      final acc = byAgent.putIfAbsent(
        agentId,
        () => _RoiAccumulator(displayName),
      );
      acc.samples += qty;
      if (schoolId.isNotEmpty) {
        acc.schools.add(schoolId);
      }
    }

    for (final row in orderRows) {
      final agentId = row['agent_id']?.toString() ?? '';
      if (agentId.isEmpty || !byAgent.containsKey(agentId)) continue;
      final status = (row['status']?.toString().toLowerCase() ?? '');
      if (status == 'approved' || status == 'paid') {
        final amount = (row['checkout_amount'] as num?)?.toDouble() ?? 0.0;
        byAgent[agentId]!.revenue += amount;
      }
    }

    for (final row in salesRows) {
      final agentId = row['agent_id']?.toString() ?? '';
      if (agentId.isEmpty || !byAgent.containsKey(agentId)) continue;
      final stage = (row['sale_status']?.toString().toLowerCase() ?? '');
      if (stage == 'won') {
        final amount = (row['expected_value'] as num?)?.toDouble() ?? 0.0;
        byAgent[agentId]!.won += amount;
      }
    }

    final rows =
        byAgent.entries
            .map(
              (entry) => _RoiRow(
                name: entry.value.name,
                samplesGiven: entry.value.samples,
                schoolsReached: entry.value.schools.length,
                revenueEarned: entry.value.revenue,
                wonValue: entry.value.won,
              ),
            )
            .toList()
          ..sort((a, b) => b.revenueEarned.compareTo(a.revenueEarned));

    return rows;
  }
}

class _RoiAccumulator {
  _RoiAccumulator(this.name);

  final String name;
  int samples = 0;
  final Set<String> schools = <String>{};
  double revenue = 0.0;
  double won = 0.0;
}

class _RoiRow {
  const _RoiRow({
    required this.name,
    required this.samplesGiven,
    required this.schoolsReached,
    required this.revenueEarned,
    required this.wonValue,
  });

  final String name;
  final int samplesGiven;
  final int schoolsReached;
  final double revenueEarned;
  final double wonValue;
}
