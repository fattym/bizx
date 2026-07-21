import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';
import '../database/database_service.dart';
import 'package:intl/intl.dart';

class AdminSampleRequestsPage extends StatefulWidget {
  const AdminSampleRequestsPage({super.key});

  @override
  State<AdminSampleRequestsPage> createState() =>
      _AdminSampleRequestsPageState();
}

class _AdminSampleRequestsPageState extends State<AdminSampleRequestsPage> {
  final DatabaseService _dbService = DatabaseService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _requests = [];
  String _statusFilter = 'PENDING'; // PENDING, APPROVED, REJECTED, ALL

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);
    try {
      final res = await _dbService.getSampleRequests(
        status: _statusFilter == 'ALL' ? null : _statusFilter,
      );
      if (!mounted) return;
      setState(() {
        _requests = res;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Failed to load sample requests: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading requests: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showApproveDialog(Map<String, dynamic> request) {
    final items = List<Map<String, dynamic>>.from(request['items'] ?? []);
    final List<TextEditingController> controllers =
        items.map((item) {
          return TextEditingController(text: '${item['requested_qty'] ?? 1}');
        }).toList();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Approve Request ${request['request_code']}'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['sample_name'] ?? 'Unknown',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text('Requested: ${item['requested_qty']}'),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 100,
                        child: TextField(
                          controller: controllers[index],
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Approved Qty',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(context);
                final approvedItems = <Map<String, dynamic>>[];
                for (int i = 0; i < items.length; i++) {
                  final approvedQty = int.tryParse(controllers[i].text) ?? 0;
                  final item = Map<String, dynamic>.from(items[i]);
                  item['approved_qty'] = approvedQty;
                  approvedItems.add(item);
                }

                try {
                  await _dbService.updateSampleRequestStatus(
                    requestId: request['id'],
                    status: 'APPROVED',
                    approvedItems: approvedItems,
                  );
                  _loadRequests();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Request approved.'),
                      backgroundColor: AppColors.primaryGreen,
                    ),
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to approve: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Approve'),
            ),
          ],
        );
      },
    );
  }

  void _showRejectDialog(Map<String, dynamic> request) {
    final TextEditingController reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Reject Request ${request['request_code']}'),
          content: TextField(
            controller: reasonController,
            decoration: const InputDecoration(
              labelText: 'Rejection Reason (Optional)',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                Navigator.pop(context);
                try {
                  await _dbService.updateSampleRequestStatus(
                    requestId: request['id'],
                    status: 'REJECTED',
                    rejectionReason: reasonController.text.trim(),
                  );
                  _loadRequests();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Request rejected.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to reject: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Reject'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatusChip(String status) {
    Color bgColor;
    Color textColor = Colors.white;
    switch (status) {
      case 'APPROVED':
        bgColor = AppColors.primaryGreen;
        break;
      case 'REJECTED':
        bgColor = Colors.red;
        break;
      case 'PENDING':
      default:
        bgColor = Colors.orange;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sample Requests'),
        backgroundColor: const Color(0xFF6D273F),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children:
                    ['PENDING', 'APPROVED', 'REJECTED', 'ALL'].map((status) {
                      final isSelected = _statusFilter == status;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(status),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _statusFilter = status);
                              _loadRequests();
                            }
                          },
                        ),
                      );
                    }).toList(),
              ),
            ),
          ),
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _requests.isEmpty
                    ? const Center(child: Text('No sample requests found.'))
                    : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _requests.length,
                      itemBuilder: (context, index) {
                        final request = _requests[index];
                        final schoolName =
                            request['schools']?['name'] ?? 'Unknown School';
                        final items = List<Map<String, dynamic>>.from(
                          request['items'] ?? [],
                        );
                        final status = request['status'] ?? 'PENDING';
                        final dateStr = request['requested_at'];
                        String formattedDate = '';
                        if (dateStr != null) {
                          try {
                            formattedDate = DateFormat(
                              'MMM dd, yyyy HH:mm',
                            ).format(DateTime.parse(dateStr).toLocal());
                          } catch (_) {}
                        }

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      request['request_code'] ?? 'Unknown ID',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    _buildStatusChip(status),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'School: $schoolName',
                                  style: const TextStyle(fontSize: 16),
                                ),
                                if (formattedDate.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      'Requested on: $formattedDate',
                                      style: const TextStyle(
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                if ((request['notes'] ?? '')
                                    .toString()
                                    .isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text('Notes: ${request['notes']}'),
                                  ),
                                const Divider(height: 24),
                                const Text(
                                  'Items Requested:',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                ...items.map((item) {
                                  String qtyText =
                                      'Requested: ${item['requested_qty']}';
                                  if (status == 'APPROVED' &&
                                      item.containsKey('approved_qty')) {
                                    qtyText +=
                                        ' | Approved: ${item['approved_qty']}';
                                  }
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '• ${item['sample_name'] ?? 'Unknown'}',
                                        ),
                                        Text(
                                          qtyText,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                                if (status == 'REJECTED' &&
                                    (request['rejection_reason'] ?? '')
                                        .toString()
                                        .isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Rejection Reason: ${request['rejection_reason']}',
                                      style: TextStyle(
                                        color: Colors.red.shade900,
                                      ),
                                    ),
                                  ),
                                ],
                                if (status == 'PENDING') ...[
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      OutlinedButton(
                                        onPressed:
                                            () => _showRejectDialog(request),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.red,
                                        ),
                                        child: const Text('Reject'),
                                      ),
                                      const SizedBox(width: 12),
                                      FilledButton(
                                        onPressed:
                                            () => _showApproveDialog(request),
                                        style: FilledButton.styleFrom(
                                          backgroundColor:
                                              AppColors.primaryGreen,
                                        ),
                                        child: const Text('Approve'),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
