import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/sales_access.dart';
import '../../models/order_item_model.dart';
import '../../models/order_model.dart';
import '../database/database_service.dart';
import '../../services/invoice_service.dart';
import 'add_order_page.dart';

class MyOrdersPage extends StatefulWidget {
  const MyOrdersPage({super.key});

  @override
  State<MyOrdersPage> createState() => _MyOrdersPageState();
}

class _MyOrdersPageState extends State<MyOrdersPage> {
  final _databaseService = DatabaseService();
  final _invoiceService = InvoiceService();
  late Future<List<OrderModel>> _ordersFuture;
  int? _currentRole;
  bool _busyUpdating = false;

  @override
  void initState() {
    super.initState();
    _ordersFuture = _databaseService.getOrdersForCurrentUser();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final role = await _databaseService.getCurrentUserRole();
    if (!mounted) return;
    setState(() => _currentRole = role);
  }

  Future<void> _reloadOrders() async {
    setState(() {
      _ordersFuture = _databaseService.getOrdersForCurrentUser();
    });
    await _ordersFuture;
  }

  List<OrderModel> _filterByStatus(List<OrderModel> orders, String status) {
    switch (status) {
      case 'Pending':
        return orders.where(_isPending).toList();
      case 'Completed':
        return orders.where(_isCompleted).toList();
      case 'Drafts':
        return orders.where(_isDraft).toList();
      default:
        return orders;
    }
  }

  bool _isPending(OrderModel order) {
    final status = order.status.toLowerCase();
    return status == 'pending' || status == 'processing';
  }

  bool _isCompleted(OrderModel order) {
    final status = order.status.toLowerCase();
    return status == 'paid' || status == 'completed' || status == 'won';
  }

  bool _isDraft(OrderModel order) => order.status.toLowerCase() == 'draft';

  bool get _canFinishPendingOrder =>
      SalesAccess.canFinishPendingOrder(_currentRole);

  String _formatDate(DateTime? date) {
    if (date == null) return 'No date';
    final local = date.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }

  String _paymentLabel(String method) {
    switch (method) {
      case 'cash':
        return 'Cash';
      case 'mpesa':
        return 'M-Pesa';
      case 'bank':
        return 'Bank Transfer';
      default:
        return method;
    }
  }

  Color _badgeColor(String status) {
    switch (status) {
      case 'Pending':
        return AppColors.secondaryOrange;
      case 'Completed':
        return AppColors.primaryGreen;
      default:
        return Colors.grey;
    }
  }

  Future<void> _openOrderDetails(OrderModel order) async {
    final items = await _databaseService.getOrderItems(order.id);
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.7,
            minChildSize: 0.45,
            maxChildSize: 0.95,
            builder: (context, scrollController) {
              return Padding(
                padding: const EdgeInsets.all(20),
                child: ListView(
                  controller: scrollController,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            order.orderNumber,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        _statusBadge(order.status),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      order.schoolName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${order.schoolPhone ?? 'No phone'} • ${_formatDate(order.createdAt)}',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 20),
                    _detailRow(
                      'Payment Method',
                      _paymentLabel(order.paymentMethod),
                    ),
                    _detailRow(
                      'Payment Ref',
                      order.paymentReference ?? 'Not provided',
                    ),
                    _detailRow(
                      'Amount',
                      'KES ${order.checkoutAmount.toStringAsFixed(0)}',
                    ),
                    _detailRow('Status', order.status.toUpperCase()),
                    if ((order.notes ?? '').isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'Notes',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(order.notes!),
                    ],
                    const SizedBox(height: 20),
                    const Text(
                      'Order Items',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    if (items.isEmpty)
                      const Text('No items found for this order.')
                    else
                      ...items.map(_buildOrderItemTile),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () async {
                        try {
                          final pdfBytes = await _invoiceService
                              .generateInvoiceBytes(order: order, items: items);
                          final fileName = '${order.orderNumber}.pdf';

                          if (kIsWeb) {
                            await Printing.sharePdf(
                              bytes: pdfBytes,
                              filename: fileName,
                            );
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Invoice download started.'),
                              ),
                            );
                            return;
                          }

                          final docsDir =
                              await getApplicationDocumentsDirectory();
                          final invoicesDir = Directory(
                            '${docsDir.path}/invoices',
                          );
                          if (!await invoicesDir.exists()) {
                            await invoicesDir.create(recursive: true);
                          }
                          final filePath = '${invoicesDir.path}/$fileName';
                          final file = File(filePath);
                          await file.writeAsBytes(pdfBytes, flush: true);
                          await Printing.layoutPdf(
                            name: fileName,
                            onLayout: (_) async => pdfBytes,
                          );

                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Invoice saved to $filePath'),
                            ),
                          );
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Could not generate invoice: $e'),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.download),
                      label: const Text('Download Invoice'),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () => _shareInvoiceOnWhatsApp(order, items),
                      icon: const Icon(Icons.share),
                      label: const Text('Share Invoice on WhatsApp'),
                    ),
                    if (_canFinishPendingOrder && _isPending(order)) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed:
                            _busyUpdating
                                ? null
                                : () async {
                                  Navigator.pop(context);
                                  await _finishPendingOrder(order);
                                },
                        icon: const Icon(Icons.task_alt),
                        label: const Text('Update & Finish'),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
    );
  }

  Widget _buildOrderItemTile(OrderItemModel item) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        title: Text(
          item.productName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${item.category ?? 'Item'} • ${item.quantity} x KES ${item.unitPrice.toStringAsFixed(0)}',
        ),
        trailing: Text(
          'KES ${item.lineTotal.toStringAsFixed(0)}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.secondaryOrange,
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    final statusLabel =
        status.toLowerCase() == 'paid' || status.toLowerCase() == 'completed'
            ? 'Completed'
            : status.toLowerCase() == 'draft'
            ? 'Drafts'
            : 'Pending';

    final color = _badgeColor(statusLabel);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        statusLabel,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Future<void> _shareInvoiceOnWhatsApp(
    OrderModel order,
    List<OrderItemModel> items,
  ) async {
    final itemSummary =
        items.isEmpty
            ? 'No items'
            : items
                .map(
                  (item) =>
                      '- ${item.productName}: ${item.quantity} x KES ${item.unitPrice.toStringAsFixed(0)}',
                )
                .join('\n');
    final message = '''Invoice ${order.orderNumber}
School: ${order.schoolName}
Amount: KES ${order.checkoutAmount.toStringAsFixed(0)}
Status: ${order.status.toUpperCase()}
Items:
$itemSummary''';
    final encodedMessage = Uri.encodeComponent(message);
    final phone = order.schoolPhone?.replaceAll(RegExp(r'[^0-9]'), '');
    final normalizedPhone =
        phone == null || phone.isEmpty
            ? ''
            : phone.startsWith('254')
            ? phone
            : phone.startsWith('0')
            ? '254${phone.substring(1)}'
            : phone;

    final candidates = <Uri>[
      if (normalizedPhone.isNotEmpty)
        Uri.parse(
          'whatsapp://send?phone=$normalizedPhone&text=$encodedMessage',
        ),
      Uri.parse('whatsapp://send?text=$encodedMessage'),
      if (normalizedPhone.isNotEmpty)
        Uri.parse('https://wa.me/$normalizedPhone?text=$encodedMessage'),
      Uri.parse('https://api.whatsapp.com/send?text=$encodedMessage'),
    ];

    for (final uri in candidates) {
      try {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return;
        }
      } catch (_) {}
    }

    if (!mounted) return;
    try {
      await _invoiceService.shareInvoice(order: order, items: items);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open WhatsApp or share invoice: $e')),
      );
    }
  }

  Future<void> _finishPendingOrder(OrderModel order) async {
    final referenceController = TextEditingController(
      text: order.paymentReference ?? '',
    );
    final amountController = TextEditingController(
      text: order.checkoutAmount.toStringAsFixed(0),
    );
    final notesController = TextEditingController(text: order.notes ?? '');
    String paymentMethod = order.paymentMethod;

    final shouldSave = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Finish Pending Order',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Update payment details, then mark the order as paid.',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: paymentMethod,
                      decoration: const InputDecoration(
                        labelText: 'Payment Method',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'cash', child: Text('Cash')),
                        DropdownMenuItem(value: 'mpesa', child: Text('M-Pesa')),
                        DropdownMenuItem(
                          value: 'bank',
                          child: Text('Bank Transfer'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setSheetState(() => paymentMethod = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Checkout Amount',
                        prefixText: 'KES ',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: referenceController,
                      decoration: InputDecoration(
                        labelText:
                            paymentMethod == 'cash'
                                ? 'Cash Receipt / Note'
                                : paymentMethod == 'bank'
                                ? 'Bank Slip / Reference'
                                : 'M-Pesa Reference',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Notes',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Save & Finish'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    if (shouldSave != true) return;

    final checkoutAmount = double.tryParse(amountController.text.trim());
    if (checkoutAmount == null || checkoutAmount <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid checkout amount.')),
      );
      return;
    }

    if (paymentMethod != 'cash' && referenceController.text.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter the payment reference to finish the order.'),
        ),
      );
      return;
    }

    setState(() => _busyUpdating = true);
    try {
      await _databaseService.updateByIdWithOfflineQueue(
        table: 'orders',
        id: order.id,
        payload: {
          'payment_method': paymentMethod,
          'payment_reference':
              paymentMethod == 'cash' ? null : referenceController.text.trim(),
          'checkout_amount': checkoutAmount,
          'status': 'paid',
          'notes':
              notesController.text.trim().isEmpty
                  ? order.notes
                  : notesController.text.trim(),
          'approved_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
      );
      await _reloadOrders();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pending order updated and marked as paid.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not finish order: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _busyUpdating = false);
      }
    }
  }

  Widget _buildOrderList(String status, List<OrderModel> orders) {
    final filtered = _filterByStatus(orders, status);

    if (filtered.isEmpty) {
      return RefreshIndicator(
        onRefresh: _reloadOrders,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 80),
            Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                'No $status orders yet.',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _reloadOrders,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final order = filtered[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      order.orderNumber,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ),
                  _statusBadge(order.status),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Text(
                    order.schoolName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_paymentLabel(order.paymentMethod)} • ${_formatDate(order.createdAt)}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                      Text(
                        'KES ${order.checkoutAmount.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.secondaryOrange,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              onTap: () => _openOrderDetails(order),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF9F9F7),
        appBar: AppBar(
          title: const Text('Book Orders'),
          backgroundColor: AppColors.primaryGreen,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            indicatorColor: AppColors.accentYellow,
            labelColor: AppColors.accentYellow,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: 'Pending'),
              Tab(text: 'Completed'),
              Tab(text: 'Drafts'),
            ],
          ),
        ),
        body: FutureBuilder<List<OrderModel>>(
          future: _ordersFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Text('Could not load orders: ${snapshot.error}'),
              );
            }

            final orders = snapshot.data ?? <OrderModel>[];
            return TabBarView(
              children: [
                _buildOrderList('Pending', orders),
                _buildOrderList('Completed', orders),
                _buildOrderList('Drafts', orders),
              ],
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: AppColors.secondaryOrange,
          child: const Icon(Icons.add, color: Colors.white),
          onPressed: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AddOrderPage()),
            );
            if (result != null && mounted) {
              await _reloadOrders();
            }
          },
        ),
      ),
    );
  }
}
