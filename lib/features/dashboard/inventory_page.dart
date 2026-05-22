import 'package:flutter/material.dart';

import '../../core/constants/colors.dart';
import '../../features/database/database_service.dart';
import '../../models/catalog_item_model.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  final _dbService = DatabaseService();
  String selectedCategory = "All";
  late Future<List<CatalogItemModel>> _inventoryFuture;

  @override
  void initState() {
    super.initState();
    _inventoryFuture = _dbService.getCatalogItems(itemType: 'sale');
  }

  Future<void> _refreshInventory() async {
    setState(() {
      _inventoryFuture = _dbService.getCatalogItems(itemType: 'sale');
    });
    await _inventoryFuture;
  }

  List<String> _categories(List<CatalogItemModel> items) {
    final categories =
        items.map((item) => item.category).toSet().toList()..sort();
    return ['All', ...categories];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F7),
      appBar: AppBar(
        title: const Text("Catalogue Inventory"),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshInventory,
          ),
        ],
      ),
      body: FutureBuilder<List<CatalogItemModel>>(
        future: _inventoryFuture,
        builder: (context, snapshot) {
          final items = snapshot.data ?? const <CatalogItemModel>[];
          final visibleItems =
              selectedCategory == "All"
                  ? items
                  : items
                      .where((item) => item.category == selectedCategory)
                      .toList();

          return Column(
            children: [
              _buildCategoryFilter(_categories(items)),
              Expanded(
                child:
                    snapshot.connectionState == ConnectionState.waiting
                        ? const Center(child: CircularProgressIndicator())
                        : visibleItems.isEmpty
                        ? const Center(child: Text('No catalog items found.'))
                        : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: visibleItems.length,
                          itemBuilder: (context, index) {
                            final item = visibleItems[index];
                            return _buildInventoryCard(item);
                          },
                        ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCategoryFilter(List<String> categories) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 10),
      color: Colors.white,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children:
            categories.map((cat) {
              final isSelected = selectedCategory == cat;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(cat),
                  selected: isSelected,
                  onSelected: (val) => setState(() => selectedCategory = cat),
                  selectedColor: AppColors.primaryGreen,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.black,
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }

  Widget _buildInventoryCard(CatalogItemModel item) {
    final isLowStock = item.stockQty < 20;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '${item.category} • SKU: ${item.sku}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isLowStock)
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.secondaryOrange,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                item.description ?? '',
                style: TextStyle(color: Colors.grey[700], fontSize: 12),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: (item.stockQty / 150).clamp(0.0, 1.0),
                      backgroundColor: Colors.grey.shade200,
                      color:
                          isLowStock
                              ? AppColors.secondaryOrange
                              : AppColors.primaryGreen,
                      minHeight: 8,
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                Text(
                  '${item.stockQty} Units',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color:
                        isLowStock
                            ? AppColors.secondaryOrange
                            : AppColors.primaryGreen,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
