import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../../models/order_model.dart';
import '../../models/pipeline_stage.dart';
import '../../models/farmer_model.dart';
import '../../core/constants/colors.dart';
import '../database/database_service.dart';
import '../../models/order_item_model.dart';
import '../../models/school_sale_model.dart';
import '../../services/invoice_service.dart';
import '../../models/catalog_item_model.dart';

class AddOrderPage extends StatefulWidget {
  const AddOrderPage({
    super.key,
    this.initialSchoolId,
    this.initialSchoolName,
    this.initialPaymentMethod,
    this.initialPaymentReference,
    this.initialCheckoutAmount,
    this.initialNotes,
    this.initialPackageName,
    this.initialSaleId,
  });

  final String? initialSchoolId;
  final String? initialSchoolName;
  final String? initialPaymentMethod;
  final String? initialPaymentReference;
  final double? initialCheckoutAmount;
  final String? initialNotes;
  final String? initialPackageName;
  final String? initialSaleId;

  @override
  State<AddOrderPage> createState() => _AddOrderPageState();
}

class _AddOrderPageState extends State<AddOrderPage> {
  final _databaseService = DatabaseService();
  final _notesController = TextEditingController();
  final _amountController = TextEditingController();
  final _referenceController = TextEditingController();
  final _customNameController = TextEditingController();
  final _customCategoryController = TextEditingController();
  final _customSkuController = TextEditingController();
  final _customQtyController = TextEditingController(text: '1');
  final _customPriceController = TextEditingController();
  final _invoiceService = InvoiceService();

  List<SchoolModel> _schools = <SchoolModel>[];
  List<CatalogItemModel> _catalogItems = <CatalogItemModel>[];
  final List<Map<String, dynamic>> _cart = <Map<String, dynamic>>[];
  String? _selectedSchoolId;
  String? _paymentMethod;
  bool _loading = true;
  bool _saving = false;
  bool _prefilled = false;

  @override
  void initState() {
    super.initState();
    _notesController.text = widget.initialNotes ?? '';
    _referenceController.text = widget.initialPaymentReference ?? '';
    if (widget.initialCheckoutAmount != null) {
      _amountController.text = widget.initialCheckoutAmount!.toStringAsFixed(0);
    }
    _paymentMethod = widget.initialPaymentMethod;
    _bootstrap();
  }

  @override
  void dispose() {
    _notesController.dispose();
    _amountController.dispose();
    _referenceController.dispose();
    _customNameController.dispose();
    _customCategoryController.dispose();
    _customSkuController.dispose();
    _customQtyController.dispose();
    _customPriceController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final schools = await _databaseService.getAllSchools();
    final catalogItems = await _databaseService.getCatalogItems(
      itemType: 'sale',
    );
    if (!mounted) return;

    setState(() {
      _schools = schools;
      _catalogItems = catalogItems;
      _selectedSchoolId = _resolveInitialSchoolId(schools);
      _loading = false;
    });

    _prefillCartIfNeeded();
  }

  String? _resolveInitialSchoolId(List<SchoolModel> schools) {
    if (widget.initialSchoolId != null) {
      return widget.initialSchoolId;
    }

    if (widget.initialSchoolName != null) {
      for (final school in schools) {
        if (school.name.toLowerCase() ==
            widget.initialSchoolName!.toLowerCase()) {
          return school.id;
        }
      }
    }

    return schools.isNotEmpty ? schools.first.id : null;
  }

  void _prefillCartIfNeeded() {
    if (_prefilled) return;
    _prefilled = true;

    final packageName = widget.initialPackageName?.trim();
    if (packageName == null || packageName.isEmpty) {
      final fallbackAmount = widget.initialCheckoutAmount ?? 0;
      if (fallbackAmount > 0) {
        _cart.add({
          'name': 'School Package',
          'category': 'Custom',
          'price': fallbackAmount,
          'sku': 'CUSTOM',
          'qty': 1,
        });
        setState(() {});
      }

      if (_amountController.text.trim().isEmpty && fallbackAmount > 0) {
        _amountController.text = fallbackAmount.toStringAsFixed(0);
      }
      return;
    }

    final matchingProduct =
        _catalogItems.where((item) {
          return item.name.toLowerCase() == packageName.toLowerCase();
        }).toList();

    if (matchingProduct.isNotEmpty) {
      _addToCart(_catalogToCartMap(matchingProduct.first));
    } else {
      final amount = widget.initialCheckoutAmount ?? 0;
      _cart.add({
        'name': packageName,
        'category': 'Custom',
        'price': amount > 0 ? amount : 0,
        'sku': 'CUSTOM',
        'qty': 1,
      });
      setState(() {});
    }

    if (_amountController.text.trim().isEmpty) {
      final fallbackAmount = widget.initialCheckoutAmount ?? totalAmount;
      if (fallbackAmount > 0) {
        _amountController.text = fallbackAmount.toStringAsFixed(0);
      }
    }
  }

  SchoolModel? get _selectedSchool {
    for (final school in _schools) {
      if (school.id == _selectedSchoolId) return school;
    }
    return null;
  }

  double get totalAmount => _cart.fold<double>(
    0.0,
    (sum, item) =>
        sum + ((item['price'] as num).toDouble() * (item['qty'] as int)),
  );

  void _addToCart(Map<String, dynamic> product) {
    setState(() {
      final index = _cart.indexWhere((item) => item['name'] == product['name']);
      if (index == -1) {
        _cart.add({...product, 'qty': 1});
      } else {
        _cart[index]['qty'] = (_cart[index]['qty'] as int) + 1;
      }

      if (_amountController.text.trim().isEmpty) {
        _amountController.text = totalAmount.toStringAsFixed(0);
      }
    });
  }

  Map<String, dynamic> _catalogToCartMap(CatalogItemModel item) {
    return {
      'name': item.name,
      'category': item.category,
      'price': item.unitPrice,
      'sku': item.sku,
      'qty': 1,
      'catalogId': item.id,
    };
  }

  void _increaseQty(int index) {
    setState(() {
      _cart[index]['qty'] = (_cart[index]['qty'] as int) + 1;
      if (_amountController.text.trim().isEmpty) {
        _amountController.text = totalAmount.toStringAsFixed(0);
      }
    });
  }

  void _decreaseQty(int index) {
    setState(() {
      final qty = (_cart[index]['qty'] as int) - 1;
      if (qty <= 0) {
        _cart.removeAt(index);
      } else {
        _cart[index]['qty'] = qty;
      }

      if (_amountController.text.trim().isEmpty) {
        _amountController.text = totalAmount.toStringAsFixed(0);
      }
    });
  }

  Future<void> _showCustomItemDialog() async {
    _customNameController.clear();
    _customCategoryController.clear();
    _customSkuController.clear();
    _customQtyController.text = '1';
    _customPriceController.clear();

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Custom Item'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _customNameController,
                  decoration: const InputDecoration(labelText: 'Item Name'),
                ),
                TextField(
                  controller: _customCategoryController,
                  decoration: const InputDecoration(labelText: 'Category'),
                ),
                TextField(
                  controller: _customSkuController,
                  decoration: const InputDecoration(labelText: 'SKU / Code'),
                ),
                TextField(
                  controller: _customQtyController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Quantity'),
                ),
                TextField(
                  controller: _customPriceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Unit Price',
                    prefixText: 'KES ',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = _customNameController.text.trim();
                final category = _customCategoryController.text.trim();
                final sku = _customSkuController.text.trim();
                final qty = int.tryParse(_customQtyController.text.trim()) ?? 1;
                final unitPrice =
                    double.tryParse(_customPriceController.text.trim()) ?? 0;

                if (name.isEmpty || unitPrice <= 0 || qty <= 0) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Enter a valid item name, quantity, and unit price.',
                      ),
                    ),
                  );
                  return;
                }

                _cart.add({
                  'name': name,
                  'category': category.isEmpty ? 'Custom' : category,
                  'price': unitPrice,
                  'sku': sku.isEmpty ? 'CUSTOM' : sku,
                  'qty': qty,
                });
                Navigator.pop(context);
                setState(() {
                  _amountController.text = totalAmount.toStringAsFixed(0);
                });
              },
              child: const Text('Add Item'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _submitOrder() async {
    final selectedSchool = _selectedSchool;
    final currentUserId = _databaseService.getCurrentUserId();
    if (selectedSchool == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a school before submitting.')),
      );
      return;
    }

    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in again to submit orders.')),
      );
      return;
    }

    if (_paymentMethod == null || _paymentMethod!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a payment method to continue.')),
      );
      return;
    }

    final checkoutAmount =
        double.tryParse(_amountController.text.trim()) ?? totalAmount;
    if (checkoutAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid checkout amount.')),
      );
      return;
    }

    if (_cart.isEmpty) {
      _cart.add({
        'name':
            widget.initialPackageName?.trim().isNotEmpty == true
                ? widget.initialPackageName!.trim()
                : 'School Package',
        'category': 'Custom',
        'price': checkoutAmount,
        'sku': 'CUSTOM',
        'qty': 1,
        });
    }

    String? schoolId = selectedSchool.id;
    final schoolIsPersisted = await _databaseService.schoolExists(schoolId);
    if (!schoolIsPersisted) {
      if (widget.initialSaleId != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This school must be synced first before finishing checkout.',
            ),
          ),
        );
        return;
      }
      schoolId = null;
    }

    if (_paymentMethod != 'cash' && _referenceController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add the payment reference for M-Pesa or bank.'),
        ),
      );
      return;
    }

    setState(() => _saving = true);

    final order = OrderModel(
      schoolId: schoolId,
      schoolName: selectedSchool.name,
      schoolPhone: selectedSchool.phone,
      agentId: currentUserId,
      paymentMethod: _paymentMethod!,
      paymentReference:
          _paymentMethod == 'cash' ? null : _referenceController.text.trim(),
      checkoutAmount: checkoutAmount,
      status: _resolveOrderStatus(_paymentMethod!),
      notes:
          _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
      submittedAt: DateTime.now(),
    );

    final items =
        _cart.map((item) {
          return OrderItemModel(
            orderId: order.id,
            productName: item['name'].toString(),
            category: item['category']?.toString(),
            sku: item['sku']?.toString(),
            quantity: item['qty'] as int,
            unitPrice: (item['price'] as num).toDouble(),
            lineTotal: (item['price'] as num).toDouble() * (item['qty'] as int),
          );
        }).toList();

    try {
      final savedOrder =
          widget.initialSaleId == null
              ? await _databaseService.createOrder(order: order, items: items)
              : await _databaseService.createOrderWithSchoolSale(
                order: order,
                items: items,
                sale: SchoolSaleModel(
                  id: widget.initialSaleId,
                  schoolId: schoolId ?? selectedSchool.id,
                  agentId: currentUserId,
                  packageName:
                      widget.initialPackageName?.trim().isEmpty ?? true
                          ? 'School Package'
                          : widget.initialPackageName!.trim(),
                  expectedValue: checkoutAmount,
                  notes:
                      _notesController.text.trim().isEmpty
                          ? null
                          : _notesController.text.trim(),
                  stage: PipelineStage.won,
                  stageUpdatedAt: DateTime.now(),
                  probability: 100,
                  closedAt: DateTime.now(),
                  isSynced: false,
              ),
              );

      try {
        await Future.wait(
          _cart
              .where((item) => item['catalogId'] != null)
              .map(
                (item) => _databaseService.decrementCatalogStock(
                  item['catalogId'].toString(),
                  item['qty'] as int,
                ),
              ),
        );
      } catch (stockError) {
        debugPrint('Stock update warning: $stockError');
      }

      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order saved successfully.'),
          backgroundColor: Colors.green,
        ),
      );

      try {
        final pdfBytes = await _invoiceService.generateInvoiceBytes(
          order: savedOrder,
          items: items,
        );
        final fileName = '${savedOrder.orderNumber}.pdf';

        if (kIsWeb) {
          await Printing.sharePdf(bytes: pdfBytes, filename: fileName);
        } else {
          await Printing.layoutPdf(
            name: fileName,
            onLayout: (_) async => pdfBytes,
          );
        }
      } catch (invoiceError) {
        debugPrint('Invoice generation warning: $invoiceError');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Order saved, but invoice could not be generated: $invoiceError',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }

      if (mounted) {
        Navigator.pop(context, {'order': savedOrder});
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save order: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _resolveOrderStatus(String paymentMethod) {
    switch (paymentMethod) {
      case 'cash':
        return 'paid';
      case 'mpesa':
      case 'bank':
        return 'pending';
      default:
        return 'pending';
    }
  }

  String _paymentLabel(String? method) {
    switch (method) {
      case 'cash':
        return 'Cash';
      case 'mpesa':
        return 'M-Pesa';
      case 'bank':
        return 'Bank Transfer';
      default:
        return 'Choose payment';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F7),
      appBar: AppBar(
        title: const Text('New Book Order'),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          color: Colors.white,
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: _selectedSchoolId,
                            decoration: InputDecoration(
                              labelText: 'Select School / Customer',
                              prefixIcon: const Icon(
                                Icons.school_outlined,
                                color: AppColors.primaryGreen,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            items:
                                _schools
                                    .map(
                                      (school) => DropdownMenuItem(
                                        value: school.id,
                                        child: Text(
                                          '${school.name} • ${school.county}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(),
                            onChanged:
                                (val) =>
                                    setState(() => _selectedSchoolId = val),
                          ),
                        ),
                        if (_selectedSchool != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                            child: _SummaryCard(
                              title: _selectedSchool!.name,
                              subtitle:
                                  '${_selectedSchool!.county} • ${_selectedSchool!.phone}',
                              trailing: _paymentLabel(_paymentMethod),
                            ),
                          ),
                        const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'SELECT PRODUCTS',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: _showCustomItemDialog,
                              icon: const Icon(Icons.add_box_outlined),
                              label: const Text('Add Custom Item'),
                            ),
                          ),
                        ),
                        if (_catalogItems.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'No catalog items found. Ask an admin to import the CSV for sale books.',
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        if (index == 0) {
                          if (_cart.isEmpty) {
                            return Card(
                              elevation: 0,
                              color: Colors.green.withValues(alpha: 0.05),
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: Colors.green.shade100),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                  'Add products from the catalog below, then confirm payment details to create the order.',
                                  style: TextStyle(
                                    color: Colors.green.shade900,
                                  ),
                                ),
                              ),
                            );
                          }

                          return _CartCard(
                            cart: _cart,
                            onIncrease: _increaseQty,
                            onDecrease: _decreaseQty,
                          );
                        }

                        final p = _catalogItems[index - 1];
                        return Card(
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                          child: ListTile(
                            title: Text(
                              p.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              '${p.category} • ${p.sku} • KES ${p.unitPrice.toStringAsFixed(0)} • Stock ${p.stockQty}',
                            ),
                            trailing: IconButton(
                              icon:
                                  p.stockQty <= 0
                                      ? const Icon(
                                        Icons.remove_shopping_cart_outlined,
                                        color: Colors.grey,
                                      )
                                      : const Icon(
                                        Icons.add_circle,
                                        color: AppColors.primaryGreen,
                                      ),
                              onPressed:
                                  p.stockQty <= 0
                                      ? null
                                      : () => _addToCart(_catalogToCartMap(p)),
                            ),
                          ),
                        );
                      }, childCount: _catalogItems.length + 1),
                    ),
                  ),
                  SliverFillRemaining(
                    hasScrollBody: false,
                    fillOverscroll: false,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [_buildOrderSummary()],
                    ),
                  ),
                ],
              ),
    );
  }

  Widget _buildOrderSummary() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_cart.fold<int>(0, (sum, item) => sum + (item['qty'] as int))} Items Selected',
                  style: const TextStyle(color: Colors.grey),
                ),
                Text(
                  'Catalog Total: KES ${totalAmount.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.secondaryOrange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _paymentMethod,
              decoration: const InputDecoration(
                labelText: 'Method of Payment',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'cash', child: Text('Cash')),
                DropdownMenuItem(value: 'mpesa', child: Text('M-Pesa')),
                DropdownMenuItem(value: 'bank', child: Text('Bank Transfer')),
              ],
              onChanged: (value) {
                setState(() {
                  _paymentMethod = value;
                });
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Checkout Amount',
                prefixText: 'KES ',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: 'Use cart total',
                  onPressed: () {
                    setState(() {
                      _amountController.text = totalAmount.toStringAsFixed(0);
                    });
                  },
                  icon: const Icon(Icons.calculate),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _referenceController,
              decoration: InputDecoration(
                labelText:
                    _paymentMethod == 'cash'
                        ? 'Cash Receipt / Note'
                        : _paymentMethod == 'bank'
                        ? 'Bank Slip / Reference'
                        : 'M-Pesa Reference',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Order Notes',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _paymentLabel(_paymentMethod),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _paymentMethod == 'cash'
                        ? 'Cash sale will be marked as paid immediately.'
                        : _paymentMethod == 'mpesa'
                        ? 'Use the reference field to capture the M-Pesa transaction code.'
                        : _paymentMethod == 'bank'
                        ? 'Record the bank slip or deposit reference for reconciliation.'
                        : 'Choose a payment method to see the checkout workflow.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed:
                  _saving || _schools.isEmpty || _selectedSchoolId == null
                      ? null
                      : _submitOrder,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child:
                  _saving
                      ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Text(
                        'CONFIRM & SUBMIT ORDER',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final String title;
  final String subtitle;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.green.shade100),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: Colors.green.withValues(alpha: 0.15),
            child: const Icon(Icons.storefront, color: Colors.green),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(subtitle),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            trailing,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.primaryGreen,
            ),
          ),
        ],
      ),
    );
  }
}

class _CartCard extends StatelessWidget {
  const _CartCard({
    required this.cart,
    required this.onIncrease,
    required this.onDecrease,
  });

  final List<Map<String, dynamic>> cart;
  final void Function(int index) onIncrease;
  final void Function(int index) onDecrease;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Current Cart',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...List.generate(cart.length, (index) {
              final item = cart[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['name'].toString(),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '${item['category']} • KES ${(item['price'] as num).toStringAsFixed(0)}',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () => onDecrease(index),
                    ),
                    Text('${item['qty']}'),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () => onIncrease(index),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
