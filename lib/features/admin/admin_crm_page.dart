import 'package:flutter/material.dart';

class AdminCrmPage extends StatefulWidget {
  const AdminCrmPage({super.key});

  @override
  State<AdminCrmPage> createState() => _AdminCrmPageState();
}

class _AdminCrmPageState extends State<AdminCrmPage> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _schoolController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _ownerController = TextEditingController();
  final TextEditingController _valueController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  final List<_CrmRecord> _records = <_CrmRecord>[
    _CrmRecord(
      school: 'Green Valley Academy',
      contact: 'Grace Wanjiku',
      phone: '+254 712 001 102',
      stage: 'Lead',
      owner: 'Mercy',
      dealValue: 120000,
      lastContact: DateTime(2026, 5, 10),
      notes: 'Interested in lower primary set books',
    ),
    _CrmRecord(
      school: 'Blue Ridge School',
      contact: 'Samuel Kibet',
      phone: '+254 723 887 212',
      stage: 'Qualified',
      owner: 'Evans',
      dealValue: 265000,
      lastContact: DateTime(2026, 5, 12),
      notes: 'Requested bundle quotation',
    ),
    _CrmRecord(
      school: 'Sunrise Junior',
      contact: 'Anne Chebet',
      phone: '+254 701 442 983',
      stage: 'Proposal',
      owner: 'Mercy',
      dealValue: 310000,
      lastContact: DateTime(2026, 5, 14),
      notes: 'Proposal shared, follow up next week',
    ),
    _CrmRecord(
      school: 'Hilltop Learning Center',
      contact: 'John Mutiso',
      phone: '+254 734 772 100',
      stage: 'Won',
      owner: 'Brian',
      dealValue: 420000,
      lastContact: DateTime(2026, 5, 9),
      notes: 'Confirmed term 2 order',
    ),
  ];

  final List<String> _stages = <String>[
    'All',
    'Lead',
    'Qualified',
    'Proposal',
    'Won',
    'Lost',
  ];

  String _selectedStage = 'All';
  bool _sortAscending = false;

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
                        setState(() {
                          _records.insert(
                            0,
                            _CrmRecord(
                              school: _schoolController.text.trim(),
                              contact: _contactController.text.trim(),
                              phone: _phoneController.text.trim(),
                              stage: selectedStage,
                              owner: _ownerController.text.trim(),
                              dealValue: parsed,
                              lastContact: DateTime.now(),
                              notes: _notesController.text.trim(),
                            ),
                          );
                        });
                        Navigator.pop(context, true);
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
                        setState(() {
                          record.school = _schoolController.text.trim();
                          record.contact = _contactController.text.trim();
                          record.phone = _phoneController.text.trim();
                          record.stage = selectedStage;
                          record.owner = _ownerController.text.trim();
                          record.dealValue = parsed;
                          record.notes = _notesController.text.trim();
                          record.lastContact = DateTime.now();
                        });
                        Navigator.pop(context);
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
      body: Padding(
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
                _MetricTile(label: 'Leads', value: '${_countByStage('Lead')}'),
                _MetricTile(
                  label: 'Proposals',
                  value: '${_countByStage('Proposal')}',
                ),
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
                                                    setState(() {
                                                      _records.remove(record);
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
    required this.school,
    required this.contact,
    required this.phone,
    required this.stage,
    required this.owner,
    required this.dealValue,
    required this.lastContact,
    required this.notes,
  });

  String school;
  String contact;
  String phone;
  String stage;
  String owner;
  double dealValue;
  DateTime lastContact;
  String notes;
}
