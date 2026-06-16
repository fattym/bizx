import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/constants/colors.dart';
import '../../models/catalog_item_model.dart';
import '../../models/farmer_model.dart';
import '../../models/user_model.dart';
import '../database/database_service.dart';

class GroundsQuotationPage extends StatefulWidget {
  const GroundsQuotationPage({super.key});

  @override
  State<GroundsQuotationPage> createState() => _GroundsQuotationPageState();
}

class _GroundsQuotationPageState extends State<GroundsQuotationPage> {
  final DatabaseService _dbService = DatabaseService();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final Map<String, bool> _selectedBySku = {};
  final Map<String, int> _qtyBySku = {};

  bool _loading = true;
  List<CatalogItemModel> _books = [];
  List<SchoolModel> _schools = [];
  List<String> _categories = ['All'];
  String _selectedCategory = 'All';
  String _searchQuery = '';
  String? _selectedSchoolId;
  DateTime? _generatedAt;
  String? _quoteNumber;
  String? _quotationTitle;
  String _role5Name = '';
  String _role5Phone = '';

  @override
  void initState() {
    super.initState();
    _loadBooks();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBooks() async {
    try {
      final items = await _dbService.getCatalogItems(activeOnly: true);
      final schools = await _dbService.getAllSchools();
      final uid = _dbService.getCurrentUserId();
      UserModel? role5User;
      if (uid != null && uid.isNotEmpty) {
        role5User = await _dbService.getUser(uid);
      }
      if (!mounted) return;

      final categories =
          items.map((i) => i.category).toSet().toList()..sort();

      setState(() {
        _books = items.where((i) => i.unitPrice > 0).toList();
        _schools = schools;
        _categories = ['All', ...categories];
        _role5Name = role5User?.fullName?.trim() ?? '';
        _role5Phone = role5User?.phone?.trim() ?? '';
        if (_selectedSchoolId == null && _schools.isNotEmpty) {
          _selectedSchoolId = _schools.first.id;
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load books: $e')));
    }
  }

  List<CatalogItemModel> get _selectedBooks {
    return _books.where((b) => _selectedBySku[b.sku] == true).toList();
  }

  int _qtyFor(String sku) => _qtyBySku[sku] ?? 1;

  double _lineTotal(CatalogItemModel item) => item.unitPrice * _qtyFor(item.sku);

  double get _grandTotal {
    return _selectedBooks.fold(0, (sum, b) => sum + _lineTotal(b));
  }

  void _changeQty(String sku, int delta) {
    final current = _qtyFor(sku);
    final next = (current + delta).clamp(1, 999);
    setState(() => _qtyBySku[sku] = next);
  }

  void _generateQuotation() {
    if (_selectedSchoolId == null || _selectedSchoolId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select an onboarded school.')),
      );
      return;
    }
    if (_selectedBooks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one book.')),
      );
      return;
    }
    final now = DateTime.now();
    final quoteNo =
        'QT-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    final selectedSchool = _schools.firstWhere(
      (s) => s.id == _selectedSchoolId,
      orElse: () =>
          SchoolModel(name: 'School', phone: '', county: '', focusAreas: const []),
    );
    setState(() {
      _generatedAt = now;
      _quoteNumber = quoteNo;
      _quotationTitle = '$quoteNo - ${selectedSchool.name}';
    });
  }

  Future<void> _downloadQuotationPdf() async {
    if (_generatedAt == null || _quoteNumber == null || _selectedBooks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Generate a quotation first.')),
      );
      return;
    }

    final quoteNumber = _quoteNumber!;
    final pdfBytes = await _buildQuotationPdfBytes();
    await Printing.layoutPdf(
      name: '$quoteNumber.pdf',
      onLayout: (_) async => pdfBytes,
    );

    if (!kIsWeb) {
      final docsDir = await getApplicationDocumentsDirectory();
      final quotesDir = Directory('${docsDir.path}/quotations');
      if (!await quotesDir.exists()) {
        await quotesDir.create(recursive: true);
      }
      final filePath = '${quotesDir.path}/$quoteNumber.pdf';
      final file = File(filePath);
      await file.writeAsBytes(pdfBytes, flush: true);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('PDF downloaded to: $filePath')));
    }
  }

  Future<void> _shareQuotationPdf() async {
    if (_generatedAt == null || _quoteNumber == null || _selectedBooks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Generate a quotation first.')),
      );
      return;
    }

    final quoteNumber = _quoteNumber!;
    final pdfBytes = await _buildQuotationPdfBytes();
    await Printing.sharePdf(bytes: pdfBytes, filename: '$quoteNumber.pdf');
  }

  Future<Uint8List> _buildQuotationPdfBytes() async {
    final doc = pw.Document();
    final logoBytes = await rootBundle.load(
      'assets/images/icons/download-removebg-preview.png',
    );
    final logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
    final generatedAt = _generatedAt!;
    final quoteNumber = _quoteNumber!;
    final selectedSchool = _schools.firstWhere(
      (s) => s.id == _selectedSchoolId,
      orElse: () => SchoolModel(
        name: 'Unknown School',
        phone: '',
        county: '',
        focusAreas: const [],
      ),
    );
    final preparedPhone =
        _role5Phone.isNotEmpty ? _role5Phone : _phoneController.text.trim();
    final quotationTitle = (_quotationTitle == null || _quotationTitle!.isEmpty)
        ? 'Official Quotation'
        : _quotationTitle!;

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    children: [
                      pw.Container(
                        width: 56,
                        height: 56,
                        decoration: pw.BoxDecoration(
                          borderRadius: pw.BorderRadius.circular(8),
                          color: PdfColors.white,
                        ),
                        child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                      ),
                      pw.SizedBox(width: 10),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Longhorn Publishers PLC',
                            style: pw.TextStyle(
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text(
                            quotationTitle,
                            style: const pw.TextStyle(
                              fontSize: 11,
                              color: PdfColors.grey700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('#ECF4EF'),
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          quoteNumber,
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                        pw.Text(
                          '${generatedAt.year}-${generatedAt.month.toString().padLeft(2, '0')}-${generatedAt.day.toString().padLeft(2, '0')}',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 18),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey300),
                        borderRadius: pw.BorderRadius.circular(8),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Quoted To',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(selectedSchool.name),
                          if (selectedSchool.phone.isNotEmpty)
                            pw.Text('School Phone: ${selectedSchool.phone}'),
                          if (_phoneController.text.trim().isNotEmpty)
                            pw.Text('Phone: ${_phoneController.text.trim()}'),
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 10),
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey300),
                        borderRadius: pw.BorderRadius.circular(8),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Prepared By (Field Agent)',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(_role5Name.isEmpty ? '-' : _role5Name),
                          if (preparedPhone.isNotEmpty)
                            pw.Text('Phone: $preparedPhone'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 16),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.7),
                columnWidths: {
                  0: const pw.FlexColumnWidth(4),
                  1: const pw.FlexColumnWidth(1),
                  2: const pw.FlexColumnWidth(2),
                  3: const pw.FlexColumnWidth(2),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _cell('Book'),
                      _cell('Qty'),
                      _cell('Unit Price'),
                      _cell('Line Total'),
                    ],
                  ),
                  ..._selectedBooks.map((b) {
                    final qty = _qtyFor(b.sku);
                    return pw.TableRow(
                      children: [
                        _cell(b.name),
                        _cell('$qty'),
                        _cell('KES ${b.unitPrice.toStringAsFixed(2)}'),
                        _cell('KES ${_lineTotal(b).toStringAsFixed(2)}'),
                      ],
                    );
                  }),
                ],
              ),
              pw.SizedBox(height: 14),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#0D6B3E'),
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Text(
                    'Grand Total: KES ${_grandTotal.toStringAsFixed(2)}',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ),
              pw.Spacer(),
              pw.Divider(color: PdfColors.grey300),
              pw.Text(
                'Thank you for partnering with Longhorn Publishers PLC.',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
              ),
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  pw.Widget _cell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 10)),
    );
  }

  Widget _buildRecommendations() {
    final school = _schools.firstWhere(
      (s) => s.id == _selectedSchoolId,
      orElse: () => SchoolModel(name: '', phone: '', county: '', focusAreas: []),
    );
    if (school.focusAreas.isEmpty) return const SizedBox.shrink();

    final recommended =
        _books.where((b) {
          return school.focusAreas.any(
            (area) => b.name.toLowerCase().contains(area.toLowerCase()),
          );
        }).take(5).toList();

    if (recommended.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Smart Recommendations',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: recommended.length,
            itemBuilder: (context, index) {
              final b = recommended[index];
              final isSelected = _selectedBySku[b.sku] ?? false;
              return Container(
                width: 160,
                margin: const EdgeInsets.only(right: 10),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedBySku[b.sku] = !isSelected;
                    });
                  },
                  child: Card(
                    color: isSelected ? AppColors.primaryPale : Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            b.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                          Text(
                            'KES ${b.unitPrice.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showQtyDialog(CatalogItemModel book) {
    final controller = TextEditingController(text: _qtyFor(book.sku).toString());
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Quantity for ${book.name}'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Enter Quantity'),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final val = int.tryParse(controller.text) ?? 1;
                setState(() => _qtyBySku[book.sku] = val.clamp(1, 999));
                Navigator.pop(context);
              },
              child: const Text('Set'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quotation Builder')),
      bottomNavigationBar:
          _selectedBooks.isNotEmpty
              ? Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_selectedBooks.length} Items Selected',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Total: KES ${_grandTotal.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: AppColors.primaryGreen,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: _generateQuotation,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                        child: const Text('Generate Quotation'),
                      ),
                    ],
                  ),
                ),
              )
              : null,
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 1000;
                  final isTablet = constraints.maxWidth >= 700;
                  final contentMaxWidth = isWide ? 1180.0 : 760.0;

                  final filteredBooks =
                      _books.where((b) {
                        final matchesSearch =
                            b.name.toLowerCase().contains(_searchQuery) ||
                            b.sku.toLowerCase().contains(_searchQuery);
                        final matchesCategory =
                            _selectedCategory == 'All' ||
                            b.category == _selectedCategory;
                        return matchesSearch && matchesCategory;
                      }).toList();

                  final leftPane = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: _selectedSchoolId,
                        items:
                            _schools
                                .map(
                                  (s) => DropdownMenuItem<String>(
                                    value: s.id,
                                    child: Text(
                                      '${s.name} (${s.county})',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _selectedSchoolId = value);
                        },
                        decoration: const InputDecoration(
                          labelText: 'Onboarded School',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.school_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_selectedSchoolId != null) ...[
                        _buildRecommendations(),
                        const SizedBox(height: 16),
                      ],
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search by book name or SKU...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon:
                              _searchQuery.isNotEmpty
                                  ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _searchController.clear();
                                    },
                                  )
                                  : null,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children:
                              _categories.map((cat) {
                                final isSelected = _selectedCategory == cat;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    label: Text(cat),
                                    selected: isSelected,
                                    onSelected: (selected) {
                                      if (selected) {
                                        setState(() => _selectedCategory = cat);
                                      }
                                    },
                                    selectedColor: AppColors.primaryGreen,
                                    labelStyle: TextStyle(
                                      color:
                                          isSelected
                                              ? Colors.white
                                              : Colors.black,
                                    ),
                                  ),
                                );
                              }).toList(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Select Books (${filteredBooks.length})',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (_selectedBooks.isNotEmpty)
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _selectedBySku.clear();
                                  _qtyBySku.clear();
                                });
                              },
                              icon: const Icon(Icons.clear_all, size: 18),
                              label: const Text('Clear Selection'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (filteredBooks.isEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: Text('No books match your search.'),
                          ),
                        )
                      else
                        ...filteredBooks.map((book) {
                          final selected = _selectedBySku[book.sku] ?? false;
                          final qty = _qtyFor(book.sku);
                          return Card(
                            elevation: selected ? 2 : 0.5,
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(
                                color:
                                    selected
                                        ? AppColors.primaryGreen
                                        : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              leading: Checkbox(
                                value: selected,
                                activeColor: AppColors.primaryGreen,
                                onChanged: (value) {
                                  setState(
                                    () =>
                                        _selectedBySku[book.sku] =
                                            value ?? false,
                                  );
                                },
                              ),
                              title: Text(
                                book.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'SKU: ${book.sku} • ${book.category}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'KES ${book.unitPrice.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      color: AppColors.primaryGreen,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    onPressed:
                                        selected
                                            ? () => _changeQty(book.sku, -1)
                                            : null,
                                    icon: const Icon(
                                      Icons.remove_circle_outline,
                                      size: 20,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap:
                                        selected
                                            ? () => _showQtyDialog(book)
                                            : null,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: Colors.grey.shade300,
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '$qty',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    onPressed:
                                        selected
                                            ? () => _changeQty(book.sku, 1)
                                            : null,
                                    icon: const Icon(
                                      Icons.add_circle_outline,
                                      size: 20,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      const SizedBox(height: 100), // Space for floating bar
                    ],
                  );

                  final rightPane = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Card(
                        color: AppColors.primaryPale,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Grand Total',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              Text(
                                'KES ${_grandTotal.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _generateQuotation,
                        icon: const Icon(Icons.request_quote_outlined),
                        label: const Text('Generate Quotation'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const GeneratedQuotesPage(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.folder_outlined),
                        label: const Text('Generated Quotes'),
                      ),
                      if (_selectedBooks.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _quoteNumber == null
                                      ? 'Selected Books'
                                      : 'Quotation #$_quoteNumber',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  'School: ${_schools.firstWhere((s) => s.id == _selectedSchoolId, orElse: () => SchoolModel(name: '-', phone: '', county: '', focusAreas: const [])).name}',
                                ),
                                if (_quotationTitle != null &&
                                    _quotationTitle!.trim().isNotEmpty)
                                  Text('Title: ${_quotationTitle!.trim()}'),
                                if (_phoneController.text.trim().isNotEmpty)
                                  Text('Phone: ${_phoneController.text.trim()}'),
                                if (_role5Name.isNotEmpty)
                                  Text('Field Agent: $_role5Name'),
                                if (_role5Phone.isNotEmpty)
                                  Text('Field Agent Phone: $_role5Phone'),
                                const SizedBox(height: 10),
                                ..._selectedBooks.map((b) {
                                  final qty = _qtyFor(b.sku);
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 2,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(child: Text('${b.name} x$qty')),
                                        Text(
                                          'KES ${_lineTotal(b).toStringAsFixed(2)}',
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                                const Divider(),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Total',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      'KES ${_grandTotal.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      if (_generatedAt != null && _quoteNumber != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _downloadQuotationPdf,
                                icon: const Icon(Icons.picture_as_pdf_outlined),
                                label: const Text('Download PDF'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _shareQuotationPdf,
                                icon: const Icon(Icons.share_outlined),
                                label: const Text('Share PDF'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  );

                  return Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: contentMaxWidth),
                      child: ListView(
                        padding: EdgeInsets.all(isTablet ? 20 : 16),
                        children: [
                          if (isWide)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 3, child: leftPane),
                                const SizedBox(width: 20),
                                Expanded(flex: 2, child: rightPane),
                              ],
                            )
                          else ...[
                            leftPane,
                            const SizedBox(height: 12),
                            rightPane,
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
    );
  }
}

class GeneratedQuotesPage extends StatefulWidget {
  const GeneratedQuotesPage({super.key});

  @override
  State<GeneratedQuotesPage> createState() => _GeneratedQuotesPageState();
}

class _GeneratedQuotesPageState extends State<GeneratedQuotesPage> {
  late Future<List<File>> _quotesFuture;

  @override
  void initState() {
    super.initState();
    _quotesFuture = _loadSavedQuoteFiles();
  }

  Future<List<File>> _loadSavedQuoteFiles() async {
    if (kIsWeb) return [];
    final docsDir = await getApplicationDocumentsDirectory();
    final quotesDir = Directory('${docsDir.path}/quotations');
    if (!await quotesDir.exists()) return [];

    final entities = await quotesDir.list().toList();
    final files =
        entities
            .whereType<File>()
            .where((f) => f.path.toLowerCase().endsWith('.pdf'))
            .toList();
    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return files;
  }

  Future<void> _redownloadSavedQuote(File file) async {
    final bytes = await file.readAsBytes();
    final fileName =
        file.uri.pathSegments.isNotEmpty
            ? file.uri.pathSegments.last
            : 'quotation.pdf';
    await Printing.layoutPdf(name: fileName, onLayout: (_) async => bytes);
  }

  Future<void> _shareSavedQuote(File file) async {
    final bytes = await file.readAsBytes();
    final fileName =
        file.uri.pathSegments.isNotEmpty
            ? file.uri.pathSegments.last
            : 'quotation.pdf';
    await Printing.sharePdf(bytes: bytes, filename: fileName);
  }

  void _refresh() {
    setState(() {
      _quotesFuture = _loadSavedQuoteFiles();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Generated Quotes'),
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: FutureBuilder<List<File>>(
        future: _quotesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final files = snapshot.data ?? [];
          if (files.isEmpty) {
            return const Center(
              child: Text('No saved quotations yet. Download one first.'),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: files.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final file = files[index];
              final fileName =
                  file.uri.pathSegments.isNotEmpty
                      ? file.uri.pathSegments.last
                      : 'quotation.pdf';
              return ListTile(
                title: Text(fileName),
                subtitle: Text(file.path),
                trailing: Wrap(
                  spacing: 4,
                  children: [
                    IconButton(
                      tooltip: 'Re-download',
                      onPressed: () => _redownloadSavedQuote(file),
                      icon: const Icon(Icons.download_outlined),
                    ),
                    IconButton(
                      tooltip: 'Share',
                      onPressed: () => _shareSavedQuote(file),
                      icon: const Icon(Icons.share_outlined),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
