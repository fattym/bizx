import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminCrmPage extends StatefulWidget {
  const AdminCrmPage({super.key});

  @override
  State<AdminCrmPage> createState() => _AdminCrmPageState();
}

class _AdminCrmPageState extends State<AdminCrmPage> {
  final _supabase = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _schoolController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _ownerController = TextEditingController();
  final TextEditingController _valueController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  final List<_CrmRecord> _records = <_CrmRecord>[];
  final Map<String, Map<String, dynamic>> _schoolsById = {};
  final Map<String, Map<String, dynamic>> _usersById = {};
  bool _isLoading = true;

  final List<String> _stages = <String>[
    'All',
    'Lead',
    'Qualified',
    'Proposal',
    'Negotiation',
    'Won',
    'Lost',
  ];

  String _selectedStage = 'All';
  bool _sortAscending = false;

  @override
  void initState() {
    super.initState();
    _loadCrmData();
  }

  Future<void> _loadCrmData() async {
    setState(() => _isLoading = true);
    try {
      final schoolsRes = await _supabase
          .from('schools')
          .select('id,name,phone');
      final usersRes = await _supabase
          .from('users')
          .select('id,full_name,email');
      final salesRes = await _supabase
          .from('school_sales')
          .select(
            'id,school_id,agent_id,expected_value,notes,sale_status,probability,next_action_date,stage_updated_at,created_at',
          )
          .order('updated_at', ascending: false);

      _schoolsById
        ..clear()
        ..addEntries(
          List<Map<String, dynamic>>.from(schoolsRes).map(
            (s) => MapEntry(s['id'].toString(), s),
          ),
        );
      _usersById
        ..clear()
        ..addEntries(
          List<Map<String, dynamic>>.from(usersRes).map(
            (u) => MapEntry(u['id'].toString(), u),
          ),
        );

      _records
        ..clear()
        ..addAll(
          List<Map<String, dynamic>>.from(salesRes).map((row) {
            final school = _schoolsById[row['school_id']?.toString()] ?? {};
            final owner = _usersById[row['agent_id']?.toString()] ?? {};
            final stageDb = (row['sale_status'] ?? 'lead').toString();
            final stage = _fromDbStage(stageDb);
            return _CrmRecord(
              id: row['id'].toString(),
              schoolId: row['school_id']?.toString() ?? '',
              ownerId: row['agent_id']?.toString(),
              school: (school['name'] ?? 'Unknown School').toString(),
              contact: 'N/A',
              phone: (school['phone'] ?? '').toString(),
              stage: stage,
              owner:
                  (owner['full_name'] ?? owner['email'] ?? 'Unassigned')
                      .toString(),
              dealValue: ((row['expected_value'] ?? 0) as num).toDouble(),
              lastContact:
                  DateTime.tryParse(
                    (row['stage_updated_at'] ?? row['created_at'] ?? '')
                        .toString(),
                  ) ??
                  DateTime.now(),
              nextActionDate:
                  DateTime.tryParse(
                    (row['next_action_date'] ?? '').toString(),
                  ) ??
                  DateTime.now().add(const Duration(days: 2)),
              probability: (row['probability'] as num?)?.toInt() ?? 0,
              notes: (row['notes'] ?? '').toString(),
            );
          }),
        );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load CRM data: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _schoolController.dispose();
    _contactController.dispose();
    _phoneController.dispose();
    _ownerController.dispose();
    _valueController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  List<_CrmRecord> get _visibleRecords {
    final query = _searchController.text.trim().toLowerCase();
    final rows =
        _records.where((record) {
          final stageMatch =
              _selectedStage == 'All' || record.stage == _selectedStage;
          final textMatch =
              query.isEmpty ||
              record.school.toLowerCase().contains(query) ||
              record.contact.toLowerCase().contains(query) ||
              record.owner.toLowerCase().contains(query) ||
              record.notes.toLowerCase().contains(query);
          return stageMatch && textMatch;
        }).toList();
    rows.sort(
      (a, b) =>
          _sortAscending
              ? a.lastContact.compareTo(b.lastContact)
              : b.lastContact.compareTo(a.lastContact),
    );
    return rows;
  }

  double get _pipelineValue =>
      _visibleRecords.fold(0, (sum, record) => sum + record.dealValue);
  double get _weightedForecast => _visibleRecords.fold(
    0,
    (sum, record) => sum + record.dealValue * (record.probability / 100),
  );
  int get _atRiskCount =>
      _visibleRecords.where((record) => record.riskLevel == 'High').length;

  int _countByStage(String stage) =>
      _visibleRecords.where((r) => r.stage == stage).length;

  Future<void> _openAddDialog() async {
    _schoolController.clear();
    _contactController.clear();
    _phoneController.clear();
    _ownerController.clear();
    _valueController.clear();
    _notesController.clear();
    String selectedStage = 'Lead';

    final created = await showDialog<bool>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: const Text('Add CRM Record'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _field(_schoolController, 'School'),
                        _field(_contactController, 'Contact Person'),
                        _field(_phoneController, 'Phone'),
                        DropdownButtonFormField<String>(
                          value: selectedStage,
                          items:
                              _stages
                                  .where((stage) => stage != 'All')
                                  .map(
                                    (stage) => DropdownMenuItem(
                                      value: stage,
                                      child: Text(stage),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setDialogState(() => selectedStage = value);
                            }
                          },
                          decoration: const InputDecoration(
                            labelText: 'Stage',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _field(_ownerController, 'Owner'),
                        _field(
                          _valueController,
                          'Deal Value',
                          inputType: TextInputType.number,
                        ),
                        _field(_notesController, 'Notes', maxLines: 2),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () {
                        final parsed = double.tryParse(_valueController.text);
                        if (_schoolController.text.trim().isEmpty ||
                            _contactController.text.trim().isEmpty ||
                            _ownerController.text.trim().isEmpty ||
                            parsed == null) {
                          return;
                        }
                        final schoolEntry = _schoolsById.values.firstWhere(
                          (s) =>
                              (s['name'] ?? '').toString().toLowerCase() ==
                              _schoolController.text.trim().toLowerCase(),
                          orElse: () => const {},
                        );
                        if (schoolEntry.isEmpty) return;
                        final ownerEntry = _usersById.values.firstWhere(
                          (u) =>
                              (u['full_name'] ?? u['email'] ?? '')
                                  .toString()
                                  .toLowerCase() ==
                              _ownerController.text.trim().toLowerCase(),
                          orElse: () => const {},
                        );
                        _supabase.from('school_sales').insert({
                          'school_id': schoolEntry['id'],
                          'agent_id': ownerEntry['id'],
                          'package_name': 'CRM Opportunity',
                          'expected_value': parsed,
                          'notes': _notesController.text.trim(),
                          'sale_status': _toDbStage(selectedStage),
                          'probability': _probabilityByStage(selectedStage),
                          'next_action': 'Follow up call',
                          'next_action_date':
                              DateTime.now().add(const Duration(days: 2)).toIso8601String(),
                        }).then((_) async {
                          if (mounted) {
                            Navigator.pop(context, true);
                            await _loadCrmData();
                          }
                        });
                      },
                      child: const Text('Save'),
                    ),
                  ],
                ),
          ),
    );

    if (created == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CRM record added')),
      );
    }
  }

  Future<void> _openEditDialog(_CrmRecord record) async {
    _schoolController.text = record.school;
    _contactController.text = record.contact;
    _phoneController.text = record.phone;
    _ownerController.text = record.owner;
    _valueController.text = record.dealValue.toStringAsFixed(0);
    _notesController.text = record.notes;
    String selectedStage = record.stage;

    await showDialog<void>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: const Text('Edit CRM Record'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _field(_schoolController, 'School'),
                        _field(_contactController, 'Contact Person'),
                        _field(_phoneController, 'Phone'),
                        DropdownButtonFormField<String>(
                          value: selectedStage,
                          items:
                              _stages
                                  .where((stage) => stage != 'All')
                                  .map(
                                    (stage) => DropdownMenuItem(
                                      value: stage,
                                      child: Text(stage),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setDialogState(() => selectedStage = value);
                            }
                          },
                          decoration: const InputDecoration(
                            labelText: 'Stage',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _field(_ownerController, 'Owner'),
                        _field(
                          _valueController,
                          'Deal Value',
                          inputType: TextInputType.number,
                        ),
                        _field(_notesController, 'Notes', maxLines: 2),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () {
                        final parsed = double.tryParse(_valueController.text);
                        if (parsed == null) return;
                        _supabase
                            .from('school_sales')
                            .update({
                              'expected_value': parsed,
                              'notes': _notesController.text.trim(),
                              'sale_status': _toDbStage(selectedStage),
                              'probability': _probabilityByStage(selectedStage),
                              'stage_updated_at': DateTime.now().toIso8601String(),
                              'next_action': 'Follow up call',
                              'next_action_date':
                                  DateTime.now().add(const Duration(days: 2)).toIso8601String(),
                            })
                            .eq('id', record.id)
                            .then((_) async {
                              if (mounted) {
                                Navigator.pop(context);
                                await _loadCrmData();
                              }
                            });
                      },
                      child: const Text('Update'),
                    ),
                  ],
                ),
          ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType inputType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: inputType,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final records = _visibleRecords;
    return Scaffold(
      appBar: AppBar(
        title: const Text('CRM Workspace'),
        actions: [
          IconButton(
            tooltip: 'Toggle date sort',
            onPressed: () => setState(() => _sortAscending = !_sortAscending),
            icon: Icon(
              _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddDialog,
        icon: const Icon(Icons.add),
        label: const Text('New Record'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _MetricTile(label: 'Total Records', value: '${records.length}'),
                _MetricTile(
                  label: 'Pipeline Value',
                  value: 'KES ${_pipelineValue.toStringAsFixed(0)}',
                ),
                _MetricTile(
                  label: 'Weighted Forecast',
                  value: 'KES ${_weightedForecast.toStringAsFixed(0)}',
                ),
                _MetricTile(label: 'Leads', value: '${_countByStage('Lead')}'),
                _MetricTile(
                  label: 'Proposals',
                  value: '${_countByStage('Proposal')}',
                ),
                _MetricTile(label: 'High Risk', value: '$_atRiskCount'),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'Search by school, contact, owner or notes',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<String>(
                    value: _selectedStage,
                    items:
                        _stages
                            .map(
                              (stage) => DropdownMenuItem(
                                value: stage,
                                child: Text(stage),
                              ),
                            )
                            .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedStage = value);
                      }
                    },
                    decoration: const InputDecoration(
                      labelText: 'Stage',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child:
                  records.isEmpty
                      ? const Center(child: Text('No CRM records match filters'))
                      : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('School')),
                              DataColumn(label: Text('Contact')),
                              DataColumn(label: Text('Phone')),
                              DataColumn(label: Text('Stage')),
                              DataColumn(label: Text('Owner')),
                              DataColumn(label: Text('Deal Value')),
                              DataColumn(label: Text('Prob%')),
                              DataColumn(label: Text('Next Action')),
                              DataColumn(label: Text('Risk')),
                              DataColumn(label: Text('Last Contact')),
                              DataColumn(label: Text('Actions')),
                            ],
                            rows:
                                records
                                    .map(
                                      (record) => DataRow(
                                        cells: [
                                          DataCell(Text(record.school)),
                                          DataCell(Text(record.contact)),
                                          DataCell(Text(record.phone)),
                                          DataCell(_StageChip(stage: record.stage)),
                                          DataCell(Text(record.owner)),
                                          DataCell(
                                            Text(
                                              'KES ${record.dealValue.toStringAsFixed(0)}',
                                            ),
                                          ),
                                          DataCell(Text('${record.probability}%')),
                                          DataCell(
                                            Text(
                                              '${record.nextActionDate.year}-${record.nextActionDate.month.toString().padLeft(2, '0')}-${record.nextActionDate.day.toString().padLeft(2, '0')}',
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              record.riskLevel,
                                              style: TextStyle(
                                                color: record.riskLevel == 'High'
                                                    ? Colors.red
                                                    : record.riskLevel == 'Medium'
                                                    ? Colors.orange
                                                    : Colors.green,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              '${record.lastContact.year}-${record.lastContact.month.toString().padLeft(2, '0')}-${record.lastContact.day.toString().padLeft(2, '0')}',
                                            ),
                                          ),
                                          DataCell(
                                            Row(
                                              children: [
                                                IconButton(
                                                  icon: const Icon(Icons.edit),
                                                  tooltip: 'Edit',
                                                  onPressed:
                                                      () => _openEditDialog(
                                                        record,
                                                      ),
                                                ),
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.delete_outline,
                                                  ),
                                                  tooltip: 'Delete',
                                                  onPressed: () {
                                                    _supabase
                                                        .from('school_sales')
                                                        .delete()
                                                        .eq('id', record.id)
                                                        .then((_) {
                                                          _loadCrmData();
                                                        });
                                                  },
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                    .toList(),
                          ),
                        ),
                      ),
            ),
          ],
        ),
      ),
    );
  }

  int _probabilityByStage(String stage) {
    switch (stage) {
      case 'Lead':
        return 15;
      case 'Qualified':
        return 35;
      case 'Proposal':
        return 65;
      case 'Negotiation':
        return 80;
      case 'Won':
        return 100;
      case 'Lost':
        return 0;
      default:
        return 20;
    }
  }

  String _toDbStage(String uiStage) {
    switch (uiStage) {
      case 'Lead':
        return 'lead';
      case 'Qualified':
        return 'contacted';
      case 'Proposal':
        return 'quotation_sent';
      case 'Negotiation':
        return 'negotiation';
      case 'Won':
        return 'won';
      case 'Lost':
        return 'lost';
      default:
        return 'lead';
    }
  }

  String _fromDbStage(String dbStage) {
    switch (dbStage) {
      case 'lead':
        return 'Lead';
      case 'contacted':
      case 'meeting_scheduled':
      case 'sample_issued':
      case 'decision_pending':
        return 'Qualified';
      case 'quotation_sent':
        return 'Proposal';
      case 'negotiation':
        return 'Negotiation';
      case 'won':
        return 'Won';
      case 'lost':
        return 'Lost';
      default:
        return 'Lead';
    }
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 170,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade700)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _StageChip extends StatelessWidget {
  const _StageChip({required this.stage});

  final String stage;

  @override
  Widget build(BuildContext context) {
    final color = switch (stage) {
      'Lead' => Colors.blue,
      'Qualified' => Colors.orange,
      'Proposal' => Colors.purple,
      'Negotiation' => Colors.teal,
      'Won' => Colors.green,
      'Lost' => Colors.red,
      _ => Colors.grey,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        stage,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _CrmRecord {
  _CrmRecord({
    required this.id,
    required this.schoolId,
    required this.ownerId,
    required this.school,
    required this.contact,
    required this.phone,
    required this.stage,
    required this.owner,
    required this.dealValue,
    required this.lastContact,
    required this.nextActionDate,
    required this.probability,
    required this.notes,
  });

  String id;
  String schoolId;
  String? ownerId;
  String school;
  String contact;
  String phone;
  String stage;
  String owner;
  double dealValue;
  DateTime lastContact;
  DateTime nextActionDate;
  int probability;
  String notes;

  String get riskLevel {
    final now = DateTime.now();
    final daysSinceContact = now.difference(lastContact).inDays;
    final daysToAction = nextActionDate.difference(now).inDays;
    if (stage == 'Won' || stage == 'Lost') return 'Low';
    if (daysSinceContact > 7 || daysToAction < 0) return 'High';
    if (daysSinceContact > 3 || daysToAction <= 1) return 'Medium';
    return 'Low';
  }
}
