import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/colors.dart';
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

  @override
  void initState() {
    super.initState();
    _ordersFuture = _databaseService.getOrdersForCurrentUser();
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
                          final invoicePath = await _invoiceService
                              .generateInvoiceFile(order: order, items: items);
                          final launched = await launchUrl(
                            Uri.file(invoicePath),
                            mode: LaunchMode.externalApplication,
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                launched
                                    ? 'Invoice saved at $invoicePath'
                                    : 'Invoice saved at $invoicePath',
                              ),
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
