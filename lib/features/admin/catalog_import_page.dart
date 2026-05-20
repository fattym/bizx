import 'package:flutter/material.dart';

import '../../core/constants/colors.dart';
import '../../models/catalog_item_model.dart';
import '../database/database_service.dart';
import 'utils/csv_download_stub.dart'
    if (dart.library.html) 'utils/csv_download_web.dart'
    if (dart.library.io) 'utils/csv_download_io.dart';

class CatalogImportPage extends StatefulWidget {
  const CatalogImportPage({super.key});

  @override
  State<CatalogImportPage> createState() => _CatalogImportPageState();
}

class _CatalogImportPageState extends State<CatalogImportPage> {
  final _dbService = DatabaseService();
  final _csvController = TextEditingController();
  String _itemType = 'sale';
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _csvController.text = _template('sale');
  }

  @override
  void dispose() {
    _csvController.dispose();
    super.dispose();
  }

  String _template(String type) {
    if (type == 'sample') {
      return [
        'name,category,sku,stock_qty,description,is_active,sample_note',
        'Grade 1 Reader Pack,Primary,SMPL-PR-01,120,Starter reading sample,true,For classroom demo',
        'Teacher Guide Kit,Reference,SMPL-RF-02,54,Teacher support sample,true,Leave one at school office',
      ].join('\n');
    }

    return [
      'name,category,sku,unit_price,stock_qty,description,is_active',
      'Grade 1 Reader Pack,Primary,SL-PR-01,2850,120,Core sale pack,true',
      'Teacher Guide Kit,Reference,SL-RF-02,2700,60,Teacher support pack,true',
    ].join('\n');
  }

  List<List<String>> _parseCsv(String input) {
    final lines =
        input
            .split(RegExp(r'\r?\n'))
            .map((line) => line.trim())
            .where((line) => line.isNotEmpty)
            .toList();
    if (lines.isEmpty) return [];
    return lines.map(_splitCsvLine).toList();
  }

  List<String> _splitCsvLine(String line) {
    final values = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buffer.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        values.add(buffer.toString().trim());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }

    values.add(buffer.toString().trim());
    return values;
  }

  List<CatalogItemModel> _itemsFromCsv(String csvText) {
    final rows = _parseCsv(csvText);
    if (rows.length < 2) return [];

    final headers = rows.first.map((h) => h.trim().toLowerCase()).toList();
    final items = <CatalogItemModel>[];

    for (final row in rows.skip(1)) {
      final record = <String, String>{};
      for (var i = 0; i < headers.length && i < row.length; i++) {
        record[headers[i]] = row[i];
      }

      final name = record['name']?.trim() ?? '';
      final category = record['category']?.trim() ?? '';
      final sku = record['sku']?.trim() ?? '';
      if (name.isEmpty || sku.isEmpty) continue;

      final stockRaw =
          record['stock_qty']?.trim().isNotEmpty == true
              ? record['stock_qty']!.trim()
              : (record['qty']?.trim() ?? '');
      final itemTypeRaw = record['item_type']?.trim() ?? '';
      final resolvedType = itemTypeRaw.isNotEmpty ? itemTypeRaw : _itemType;
      final unitPriceRaw = record['unit_price']?.trim() ?? '';
      final double unitPrice =
          unitPriceRaw.isNotEmpty
              ? (double.tryParse(unitPriceRaw) ?? 0.0)
              : (resolvedType == 'sample' ? 0.0 : 0.0);

      items.add(
        CatalogItemModel(
          name: name,
          category: category.isEmpty ? 'General' : category,
          sku: sku,
          itemType: resolvedType,
          unitPrice: unitPrice,
          stockQty: int.tryParse(stockRaw) ?? 0,
          description: record['description']?.trim(),
          isActive:
              (record['is_active']?.trim().toLowerCase() ?? 'true') != 'false',
        ),
      );
    }

    return items;
  }

  Future<void> _importCsv() async {
    final items = _itemsFromCsv(_csvController.text);
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No valid CSV rows found.')),
      );
      return;
    }

    setState(() => _importing = true);
    try {
      await _dbService.upsertCatalogItems(items);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Imported ${items.length} catalog items.'),
          backgroundColor: AppColors.primaryGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Import failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _downloadTemplate(String type) async {
    final fileName =
        type == 'sample'
            ? 'sample_books_template.csv'
            : 'sales_books_template.csv';
    try {
      await downloadCsvTemplate(fileName, _template(type));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Template download started: $fileName',
          ),
          backgroundColor: AppColors.primaryGreen,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Template download is not supported on this device. Use Load Template and copy it.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F7),
      appBar: AppBar(
        title: const Text('Import Catalog CSV'),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Import sale and sample books',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Sales template columns: name,category,sku,unit_price,stock_qty,description,is_active\n'
                  'Sample template columns: name,category,sku,stock_qty,description,is_active,sample_note',
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _itemType,
                  decoration: const InputDecoration(
                    labelText: 'Default item type',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'sale', child: Text('Sale Books')),
                    DropdownMenuItem(
                      value: 'sample',
                      child: Text('Sample Books'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _itemType = value);
                    if (_csvController.text.trim().isEmpty) {
                      _csvController.text = _template(value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _csvController,
                  maxLines: 12,
                  decoration: const InputDecoration(
                    labelText: 'CSV content',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _csvController.text = _template(_itemType);
                        });
                      },
                      icon: const Icon(Icons.format_align_left),
                      label: const Text('Load Template'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _downloadTemplate('sale'),
                      icon: const Icon(Icons.download),
                      label: const Text('Download Sales Excel'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _downloadTemplate('sample'),
                      icon: const Icon(Icons.download),
                      label: const Text('Download Sample Excel'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _csvController.clear();
                        });
                      },
                      icon: const Icon(Icons.clear),
                      label: const Text('Clear'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _importing ? null : _importCsv,
                  icon:
                      _importing
                          ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.upload_file),
                  label: const Text('Import CSV'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
