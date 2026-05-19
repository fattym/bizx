import 'package:flutter/material.dart';

import '../../core/constants/colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SampleReceiptsPage extends StatefulWidget {
  const SampleReceiptsPage({super.key});

  @override
  State<SampleReceiptsPage> createState() => _SampleReceiptsPageState();
}

class _SampleReceiptsPageState extends State<SampleReceiptsPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _rows = <Map<String, dynamic>>[];

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
      final response = await _supabase
          .from('school_sample_distributions')
          .select(
            'id, sample_name, sample_category, quantity, notes, distributed_at, stamped_receipt_url, stamped_receipt_path, schools(name), users(full_name, email)',
          )
          .order('distributed_at', ascending: false)
          .limit(200);

      if (!mounted) return;
      setState(() {
        _rows = List<Map<String, dynamic>>.from(
          (response as List).map((e) => Map<String, dynamic>.from(e as Map)),
        );
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load stamped receipts: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stamped Sample Receipts'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!, style: const TextStyle(color: Colors.red)),
                  ),
                )
              : _rows.isEmpty
                  ? const Center(child: Text('No sample receipt records found.'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _rows.length,
                        itemBuilder: (context, index) {
                          final row = _rows[index];
                          final schoolName = row['schools']?['name']?.toString() ?? 'Unknown School';
                          final sampleName = row['sample_name']?.toString() ?? 'Sample';
                          final sampleCategory = row['sample_category']?.toString() ?? 'General';
                          final qty = row['quantity']?.toString() ?? '1';
                          final notes = row['notes']?.toString();
                          final agentName =
                              row['users']?['full_name']?.toString() ??
                              row['users']?['email']?.toString() ??
                              'Unknown User';
                          final proofUrl = row['stamped_receipt_url']?.toString();
                          final distributedAt = row['distributed_at']?.toString() ?? '';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$sampleName -> $schoolName',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text('Category: $sampleCategory • Qty: $qty'),
                                  Text('Distributed by: $agentName'),
                                  if (distributedAt.isNotEmpty)
                                    Text('Time: $distributedAt'),
                                  if (notes != null && notes.trim().isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text('Notes: $notes'),
                                  ],
                                  const SizedBox(height: 10),
                                  if (proofUrl != null && proofUrl.isNotEmpty)
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(10),
                                          child: Image.network(
                                            proofUrl,
                                            height: 180,
                                            width: double.infinity,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                Container(
                                              height: 120,
                                              color: Colors.grey.shade200,
                                              alignment: Alignment.center,
                                              child: const Text('Could not load receipt image'),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        OutlinedButton.icon(
                                          onPressed: () {
                                            showDialog<void>(
                                              context: context,
                                              builder: (_) => Dialog(
                                                child: InteractiveViewer(
                                                  child: Image.network(proofUrl),
                                                ),
                                              ),
                                            );
                                          },
                                          icon: const Icon(Icons.open_in_full),
                                          label: const Text('Open Receipt'),
                                        ),
                                      ],
                                    )
                                  else
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'No stamped receipt image attached.',
                                        style: TextStyle(
                                          color: AppColors.longhornMaroon,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

