import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';

import '../../core/constants/colors.dart';
import '../../features/database/database_service.dart';
import '../admin/add_sample_book_page.dart';
import '../../models/catalog_item_model.dart';
import '../../models/farmer_model.dart';

class SampleDistributionPage extends StatefulWidget {
  const SampleDistributionPage({super.key});

  @override
  State<SampleDistributionPage> createState() => _SampleDistributionPageState();
}

class _SampleDistributionPageState extends State<SampleDistributionPage> {
  final DatabaseService _dbService = DatabaseService();
  final TextEditingController _searchController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  late Future<List<SchoolModel>> _schoolsFuture;
  String? _selectedSchoolId;
  String _selectedCategory = "All";
  String _selectedSampleName = "All";
  String _searchQuery = "";
  int? _currentRole;
  final List<String> _distributionLog = [];
  List<CatalogItemModel> _samples = <CatalogItemModel>[];
  int _initialSampleTotal = 0;
  XFile? _recoveredLostPhoto;
  bool _isLoadingRoi = true;
  double _roiRevenue = 0.0;
  double _roiWonValue = 0.0;
  int _roiSamplesGiven = 0;
  int _roiSchoolsReached = 0;

  Future<void> _updateSampleCatalogItem({
    required CatalogItemModel sample,
    int? stockQty,
    bool? isActive,
  }) async {
    try {
      final payload = <String, dynamic>{};
      if (stockQty != null) {
        payload['stock_qty'] = stockQty < 0 ? 0 : stockQty;
      }
      if (isActive != null) {
        payload['is_active'] = isActive;
      }
      if (payload.isEmpty) return;

      await Supabase.instance.client
          .from('catalog_items')
          .update(payload)
          .eq('id', sample.id);

      await _loadSamples();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sample catalog updated.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update sample catalog: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _schoolsFuture = _dbService.getAllSchools();
    _loadCurrentRole();
    _loadSamples();
    _recoverLostCameraData();
    _loadRoiSummary();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentRole() async {
    final role = await _dbService.getCurrentUserRole();
    if (!mounted) return;
    setState(() => _currentRole = role);
  }

  Future<void> _refreshSchools() async {
    setState(() {
      _schoolsFuture = _dbService.getAllSchools();
    });
    await _loadSamples();
    await _loadRoiSummary();
  }

  Future<void> _loadRoiSummary() async {
    setState(() => _isLoadingRoi = true);
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        if (!mounted) return;
        setState(() => _isLoadingRoi = false);
        return;
      }

      final receiptsRes = await supabase
          .from('school_sample_distributions')
          .select('school_id,quantity')
          .eq('agent_id', userId)
          .order('distributed_at', ascending: false)
          .limit(2000);
      final ordersRes = await supabase
          .from('orders')
          .select('checkout_amount,status')
          .eq('agent_id', userId)
          .order('created_at', ascending: false)
          .limit(2000);
      final salesRes = await supabase
          .from('school_sales')
          .select('expected_value,sale_status')
          .eq('agent_id', userId)
          .order('created_at', ascending: false)
          .limit(2000);

      int samplesGiven = 0;
      final schools = <String>{};
      for (final row in List<Map<String, dynamic>>.from(receiptsRes)) {
        samplesGiven += (row['quantity'] as num?)?.toInt() ?? 1;
        final schoolId = row['school_id']?.toString() ?? '';
        if (schoolId.isNotEmpty) schools.add(schoolId);
      }

      double revenue = 0.0;
      for (final row in List<Map<String, dynamic>>.from(ordersRes)) {
        final status = (row['status']?.toString().toLowerCase() ?? '');
        if (status == 'approved' || status == 'paid') {
          revenue += (row['checkout_amount'] as num?)?.toDouble() ?? 0.0;
        }
      }

      double wonValue = 0.0;
      for (final row in List<Map<String, dynamic>>.from(salesRes)) {
        final stage = (row['sale_status']?.toString().toLowerCase() ?? '');
        if (stage == 'won') {
          wonValue += (row['expected_value'] as num?)?.toDouble() ?? 0.0;
        }
      }

      if (!mounted) return;
      setState(() {
        _roiSamplesGiven = samplesGiven;
        _roiSchoolsReached = schools.length;
        _roiRevenue = revenue;
        _roiWonValue = wonValue;
        _isLoadingRoi = false;
      });
    } catch (e) {
      debugPrint('Failed to load ROI summary: $e');
      if (!mounted) return;
      setState(() => _isLoadingRoi = false);
    }
  }

  Future<void> _loadSamples() async {
    final samples = await _dbService.getSampleCatalogItemsFromTable();
    if (!mounted) return;
    setState(() {
      _samples = samples;
      if (_initialSampleTotal == 0) {
        _initialSampleTotal = samples.fold<int>(
          0,
          (sum, sample) => sum + sample.stockQty,
        );
      }
    });
  }

  Future<void> _recoverLostCameraData() async {
    try {
      final lostData = await _imagePicker.retrieveLostData();
      if (lostData.isEmpty || lostData.file == null) return;
      if (!mounted) return;
      setState(() {
        _recoveredLostPhoto = lostData.file;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recovered a previously captured photo.')),
      );
    } catch (e) {
      debugPrint('Failed to recover lost camera data: $e');
    }
  }

  Future<XFile?> _takeProofPhoto() async {
    try {
      final photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 75,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      return photo;
    } on PlatformException catch (e) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Camera error: ${e.message ?? e.code}'),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    } catch (e) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open camera: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    }
  }

  Future<void> _assignSample({
    required CatalogItemModel sample,
    required SchoolModel school,
  }) async {
    if (sample.stockQty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('That sample is out of stock.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    int quantity = 1;
    final qtyController = TextEditingController(text: '1');
    final bool? proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Distribute ${sample.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('To: ${school.name}'),
            const SizedBox(height: 16),
            TextField(
              controller: qtyController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Quantity', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final val = int.tryParse(qtyController.text);
              if (val != null && val > 0 && val <= sample.stockQty) {
                quantity = val;
                Navigator.pop(context, true);
              } else {
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid quantity or not enough stock.')));
              }
            },
            child: const Text('Capture Proof'),
          ),
        ],
      ),
    );

    if (proceed != true) return;

    final proofPhoto = await _captureStampedPaperProof(
      sampleName: sample.name,
      schoolName: school.name,
    );
    if (proofPhoto == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Distribution cancelled: proof photo is required.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Expanded(child: Text('Uploading proof and updating CRM...')),
          ],
        ),
      ),
    );

    final receiptUpload = await _uploadStampedReceipt(
      photo: proofPhoto,
      sampleName: sample.name,
      schoolName: school.name,
    );
    
    if (!mounted) return;
    Navigator.pop(context); // Dismiss loading dialog

    if ((receiptUpload['url'] ?? '').trim().isEmpty) {
      final reason =
          (receiptUpload['error'] ?? '').trim().isEmpty
              ? 'Could not upload stamped receipt photo. Try again.'
              : 'Photo upload failed: ${receiptUpload['error']}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(reason), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() {
      final index = _samples.indexWhere((item) => item.id == sample.id);
      if (index != -1) {
        _samples[index] = CatalogItemModel(
          id: sample.id,
          name: sample.name,
          category: sample.category,
          sku: sample.sku,
          itemType: sample.itemType,
          unitPrice: sample.unitPrice,
          stockQty: sample.stockQty - quantity,
          description: sample.description,
          isActive: sample.isActive,
          isSynced: sample.isSynced,
          createdAt: sample.createdAt,
          updatedAt: sample.updatedAt,
        );
      }
      _distributionLog.insert(
        0,
        '$quantity x ${sample.name} given to ${school.name} (proof captured)',
      );
      if (_distributionLog.length > 5) {
        _distributionLog.removeLast();
      }
    });

    try {
    await _dbService.recordSampleDistribution(
      schoolId: school.id,
      sampleName: sample.name,
      sampleCategory: sample.category,
      quantity: quantity,
      notes: 'Distributed from Sample Distribution page.',
      stampedReceiptUrl: receiptUpload['url'],
      stampedReceiptPath: receiptUpload['path'],
    );
    await _dbService.decrementCatalogStock(sample.id, quantity);

    // App-level CRM Automation (Fallback if SQL Trigger is not active)
    final supabase = Supabase.instance.client;
    final saleRes = await supabase
        .from('school_sales')
        .select('id, sale_status')
        .eq('school_id', school.id)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (saleRes != null) {
      final saleId = saleRes['id'];
      final currentStatus = saleRes['sale_status']?.toString().toLowerCase();

      if (currentStatus == 'lead' || currentStatus == 'contacted' || currentStatus == 'meeting_scheduled') {
        await supabase.from('school_sales').update({
          'sale_status': 'sample_issued',
          'stage_updated_at': DateTime.now().toIso8601String(),
        }).eq('id', saleId);
      }

      await supabase.from('opportunity_activities').insert({
        'opportunity_id': saleId,
        'school_id': school.id,
        'actor_id': supabase.auth.currentUser?.id,
        'activity_type': 'Sample Delivered',
        'activity_outcome': 'Samples left with school',
        'notes': 'Distributed $quantity x ${sample.name}',
        'next_action': 'Follow up on sample',
        'next_action_date': DateTime.now().add(const Duration(days: 7)).toIso8601String(),
      });
    }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save distribution: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$quantity x ${sample.name} assigned to ${school.name}'),
        backgroundColor: AppColors.primaryGreen,
      ),
    );
  }

  Future<XFile?> _captureStampedPaperProof({
    required String sampleName,
    required String schoolName,
  }) async {
    XFile? capturedPhoto = _recoveredLostPhoto;
    Uint8List? capturedPhotoBytes;
    if (capturedPhoto != null) {
      capturedPhotoBytes = await capturedPhoto.readAsBytes();
      _recoveredLostPhoto = null;
    }

    if (!mounted) return null;
    final result = await showDialog<XFile?>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('Capture Stamped Paper Proof'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Take a clear photo of the stamped instruction paper for:',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$sampleName -> $schoolName',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  if (capturedPhoto == null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'No photo captured yet.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    Column(
                      children: [
                        Container(
                          width: double.infinity,
                          height: 180,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: Colors.grey.shade100,
                          ),
                          child:
                              capturedPhotoBytes == null
                                  ? const Center(
                                    child: Text('Preview unavailable'),
                                  )
                                  : Image.memory(
                                    capturedPhotoBytes!,
                                    fit: BoxFit.cover,
                                  ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed:
                                capturedPhotoBytes == null
                                    ? null
                                    : () {
                                      showDialog<void>(
                                        context: context,
                                        builder:
                                            (_) => Dialog(
                                              child: InteractiveViewer(
                                                child: Image.memory(
                                                  capturedPhotoBytes!,
                                                  fit: BoxFit.contain,
                                                ),
                                              ),
                                            ),
                                      );
                                    },
                            icon: const Icon(Icons.open_in_full),
                            label: const Text('View Photo'),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 8),
                  const Text(
                    'You can retake the photo before continuing.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text('Cancel'),
                ),
                TextButton.icon(
                  onPressed: () async {
                    final photo = await _takeProofPhoto();
                    if (photo == null) return;
                    final bytes = await photo.readAsBytes();
                    setModalState(() {
                      capturedPhoto = photo;
                      capturedPhotoBytes = bytes;
                    });
                  },
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: Text(
                    capturedPhoto == null ? 'Capture Photo' : 'Retake',
                  ),
                ),
                ElevatedButton(
                  onPressed:
                      capturedPhoto == null
                          ? null
                          : () => Navigator.pop(context, capturedPhoto),
                  child: const Text('Use Photo'),
                ),
              ],
            );
          },
        );
      },
    );

    return result;
  }

  Future<Map<String, String?>> _uploadStampedReceipt({
    required XFile photo,
    required String sampleName,
    required String schoolName,
  }) async {
    final supabase = Supabase.instance.client;
    final rawExt = photo.path.split('.').last.toLowerCase();
    final fileExt = rawExt.isEmpty || rawExt.length > 5 ? 'jpg' : rawExt;
    final safeSchool = schoolName.replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_');
    final safeSample = sampleName.replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_');
    final fileName =
        'sample_receipts/${safeSchool}_${safeSample}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';

    try {
      final bytes = await photo.readAsBytes();
      final candidateBuckets = ['schools', 'profiles'];
      String? lastError;

      for (final bucket in candidateBuckets) {
        try {
          await supabase.storage
              .from(bucket)
              .uploadBinary(
                fileName,
                bytes,
                fileOptions: FileOptions(
                  upsert: true,
                  contentType: 'image/$fileExt',
                ),
              );

          return {
            'url': supabase.storage.from(bucket).getPublicUrl(fileName),
            'path': fileName,
            'error': null,
          };
        } catch (e) {
          lastError = '$bucket: $e';
        }
      }

      return {'url': null, 'path': null, 'error': lastError};
    } catch (e) {
      debugPrint('Stamped receipt upload failed: $e');
      return {'url': null, 'path': null, 'error': e.toString()};
    }
  }

  List<CatalogItemModel> _filteredSamples() {
    return _samples.where((sample) {
      final matchesCategory =
          _selectedCategory == "All" || sample.category == _selectedCategory;
      final matchesName =
          _selectedSampleName == "All" || sample.name == _selectedSampleName;
      final q = _searchQuery.trim().toLowerCase();
      final matchesSearch =
          q.isEmpty ||
          sample.name.toLowerCase().contains(q) ||
          (sample.description ?? '').toLowerCase().contains(q);
      return matchesCategory && matchesName && matchesSearch;
    }).toList();
  }

  int get _remainingSampleTotal =>
      _samples.fold<int>(0, (sum, sample) => sum + sample.stockQty);

  int get _distributedSampleTotal =>
      _initialSampleTotal - _remainingSampleTotal;

  @override
  Widget build(BuildContext context) {
    final roleLabel = switch (_currentRole) {
      1 => 'Admin',
      2 => 'Sales Manager',
      3 => 'BAS',
      4 => 'Agent',
      5 => 'Grounds Person',
      _ => 'User',
    };

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F7),
      appBar: AppBar(
        title: const Text('Sample Distribution'),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        actions: [
          IconButton(
            tooltip: 'All Photos',
            icon: const Icon(Icons.photo_library_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SampleProofGalleryPage(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshSchools,
          ),
        ],
      ),
      body: FutureBuilder<List<SchoolModel>>(
        future: _schoolsFuture,
        builder: (context, snapshot) {
          final schools = snapshot.data ?? const <SchoolModel>[];
          return LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 420;
              final hGap = isCompact ? 12.0 : 16.0;
              final vGap = isCompact ? 12.0 : 16.0;
              return ListView(
                padding: EdgeInsets.all(hGap),
                children: [
                  _buildHeader(roleLabel, compact: isCompact),
                  SizedBox(height: vGap),
                  _buildRoiSummaryCard(compact: isCompact),
                  SizedBox(height: vGap),
                  _buildRemainingTracker(compact: isCompact),
                  if (_currentRole == 1) ...[
                    SizedBox(height: vGap),
                    _buildAdminSampleCatalogManager(),
                  ],
                  SizedBox(height: vGap),
                  _buildSchoolSelector(schools),
                  SizedBox(height: vGap),
                  _buildSearchBar(),
                  SizedBox(height: vGap),
                  _buildCategoryChips(),
                  SizedBox(height: isCompact ? 16 : 20),
                  Text(
                    'Available Samples',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: isCompact ? 15 : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._filteredSamples().map(
                    (sample) => _buildSampleCard(sample, schools),
                  ),
                  SizedBox(height: isCompact ? 16 : 24),
                  _buildHistory(),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildHeader(String roleLabel, {required bool compact}) {
    return Container(
      padding: EdgeInsets.all(compact ? 14 : 18),
      decoration: BoxDecoration(
        color: AppColors.accentOrange,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Role: $roleLabel',
            style: TextStyle(
              color: Colors.white70,
              fontSize: compact ? 12 : 13,
            ),
          ),
          SizedBox(height: compact ? 6 : 8),
          Text(
            'Select a school, pick a sample, and hand it over from one screen.',
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 16 : 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminSampleCatalogManager() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Admin: Manage Sample Catalog',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            'Edit stock and active status for sample items in catalog_items.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddSampleBookPage(),
                  ),
                );
                await _loadSamples();
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Sample'),
            ),
          ),
          const SizedBox(height: 10),
          if (_samples.isEmpty)
            const Text('No sample catalog items found.')
          else
            ..._samples.map((sample) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sample.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'SKU: ${sample.sku} • ${sample.category}',
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        OutlinedButton(
                          onPressed: () => _updateSampleCatalogItem(
                            sample: sample,
                            stockQty: sample.stockQty - 1,
                          ),
                          child: const Text('-1'),
                        ),
                        Text(
                          'Stock: ${sample.stockQty}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        OutlinedButton(
                          onPressed: () => _updateSampleCatalogItem(
                            sample: sample,
                            stockQty: sample.stockQty + 1,
                          ),
                          child: const Text('+1'),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Active'),
                            Switch(
                              value: sample.isActive,
                              onChanged: (value) => _updateSampleCatalogItem(
                                sample: sample,
                                isActive: value,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildRoiSummaryCard({required bool compact}) {
    return Container(
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child:
          _isLoadingRoi
              ? const SizedBox(
                height: 56,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
              : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'My Sample ROI',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: compact ? 8 : 10),
                  Wrap(
                    spacing: compact ? 8 : 10,
                    runSpacing: compact ? 8 : 10,
                    children: [
                      _roiChip('Samples Given', '$_roiSamplesGiven'),
                      _roiChip('Schools Reached', '$_roiSchoolsReached'),
                      _roiChip(
                        'Revenue Earned',
                        'KES ${_roiRevenue.toStringAsFixed(0)}',
                      ),
                      _roiChip(
                        'Won Value',
                        'KES ${_roiWonValue.toStringAsFixed(0)}',
                      ),
                    ],
                  ),
                ],
              ),
    );
  }

  Widget _roiChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildSchoolSelector(List<SchoolModel> schools) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: DropdownButtonFormField<String>(
        isExpanded: true,
        initialValue: _selectedSchoolId,
        decoration: InputDecoration(
          labelText: 'Select School',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          prefixIcon: const Icon(Icons.school_outlined),
        ),
        items:
            schools
                .map(
                  (school) => DropdownMenuItem<String>(
                    value: school.id,
                    child: Text(
                      '${school.name} • ${school.county} • ${school.bookCategory ?? "No SOP"}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
        onChanged: (value) => setState(() => _selectedSchoolId = value),
      ),
    );
  }

  Widget _buildRemainingTracker({required bool compact}) {
    final progress =
        (_remainingSampleTotal + _distributedSampleTotal) == 0
            ? 0.0
            : _distributedSampleTotal /
                (_remainingSampleTotal + _distributedSampleTotal);

    return Container(
      padding: EdgeInsets.all(compact ? 14 : 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: compact ? double.infinity : 220,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Samples Remaining',
                      style: TextStyle(
                        fontSize: compact ? 12 : 13,
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$_remainingSampleTotal left',
                      style: TextStyle(
                        fontSize: compact ? 20 : 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 10 : 12,
                  vertical: compact ? 6 : 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$_distributedSampleTotal distributed',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: compact ? 12 : 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.primaryGreen,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Tracker updates whenever you give a sample to a school.',
            style: TextStyle(color: Colors.grey[700], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      onChanged: (value) => setState(() => _searchQuery = value),
      decoration: InputDecoration(
        hintText: 'Search samples...',
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildCategoryChips() {
    final dynamicCategories =
        _samples.map((sample) => sample.category).toSet().toList()..sort();
    final categories = ['All', ...dynamicCategories];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children:
          categories.map((category) {
            final selected = _selectedCategory == category;
            return ChoiceChip(
              label: Text(category),
              selected: selected,
              onSelected:
                  (_) => setState(() {
                    _selectedCategory = category;
                    final names = _sampleNamesForSelectedCategory;
                    if (!names.contains(_selectedSampleName)) {
                      _selectedSampleName = "All";
                    }
                  }),
              selectedColor: AppColors.primaryGreen.withValues(alpha: 0.18),
            );
          }).toList(),
    );
  }

  List<String> get _sampleNamesForSelectedCategory {
    final names = _samples
        .where(
          (sample) =>
              _selectedCategory == "All" || sample.category == _selectedCategory,
        )
        .map((sample) => sample.name)
        .toSet()
        .toList()
      ..sort();
    return ["All", ...names];
  }

  Widget _buildSamplePickers() {
    final categories = _samples.map((s) => s.category).toSet().toList()..sort();
    final categoryItems = ["All", ...categories];
    final nameItems = _sampleNamesForSelectedCategory;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 680;
        final categoryDropdown = DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: _selectedCategory,
          style: const TextStyle(color: Colors.black87, fontSize: 14),
          decoration: InputDecoration(
            labelText: 'Sample Category',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          items: categoryItems
              .map((category) => DropdownMenuItem<String>(
                    value: category,
                    child: Text(
                      category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.black87),
                    ),
                  ))
              .toList(),
          onChanged: (value) {
            if (value == null) return;
            setState(() {
              _selectedCategory = value;
              final names = _sampleNamesForSelectedCategory;
              if (!names.contains(_selectedSampleName)) {
                _selectedSampleName = "All";
              }
            });
          },
        );

        final nameDropdown = DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: _selectedSampleName,
          style: const TextStyle(color: Colors.black87, fontSize: 14),
          decoration: InputDecoration(
            labelText: 'Sample Name',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          items: nameItems
              .map((name) => DropdownMenuItem<String>(
                    value: name,
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.black87),
                    ),
                  ))
              .toList(),
          onChanged: (value) {
            if (value == null) return;
            setState(() => _selectedSampleName = value);
          },
        );

        if (isWide) {
          return Row(
            children: [
              Expanded(child: categoryDropdown),
              const SizedBox(width: 12),
              Expanded(child: nameDropdown),
            ],
          );
        }

        return Column(
          children: [
            categoryDropdown,
            const SizedBox(height: 12),
            nameDropdown,
          ],
        );
      },
    );
  }

  Widget _buildSampleCard(CatalogItemModel sample, List<SchoolModel> schools) {
    final stock = sample.stockQty;
    SchoolModel? selectedSchool;
    for (final school in schools) {
      if (school.id == _selectedSchoolId) {
        selectedSchool = school;
        break;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 420;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  SizedBox(
                    width:
                        isCompact
                            ? constraints.maxWidth
                            : constraints.maxWidth - 140,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sample.name,
                          style: TextStyle(
                            fontSize: isCompact ? 15 : 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          sample.description ?? '',
                          style: const TextStyle(color: Colors.black54),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          selectedSchool == null
                              ? 'Select a school to see its SOP details.'
                              : '${selectedSchool.bookCategory ?? "No SOP"} • ${selectedSchool.focusAreas.isEmpty ? "General" : selectedSchool.focusAreas.join(", ")}',
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 12,
                          ),
                        ),
                        if (selectedSchool?.sampleProofUrl != null &&
                            selectedSchool!.sampleProofUrl!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: () {
                              showDialog<void>(
                                context: context,
                                builder:
                                    (_) => Dialog(
                                      child: InteractiveViewer(
                                        child: Image.network(
                                          selectedSchool?.sampleProofUrl ?? '',
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    ),
                              );
                            },
                            icon: const Icon(
                              Icons.receipt_long_outlined,
                              size: 18,
                            ),
                            label: const Text('View Stamped Document'),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$stock remaining',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.category_outlined,
                        size: 18,
                        color: Colors.grey[700],
                      ),
                      const SizedBox(width: 6),
                      Text(sample.category),
                    ],
                  ),
                  SizedBox(
                    width: isCompact ? constraints.maxWidth : null,
                    child: ElevatedButton.icon(
                      onPressed:
                          selectedSchool == null
                              ? () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Select a school first.'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                              : () async => await _assignSample(
                                sample: sample,
                                school: selectedSchool!,
                              ),
                      icon: const Icon(Icons.send_outlined),
                      label: const Text('Give to School'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Distribution',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (_distributionLog.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text('No samples have been assigned yet.'),
          )
        else
          ..._distributionLog.map(
            (entry) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(entry),
            ),
          ),
      ],
    );
  }
}

class SampleProofGalleryPage extends StatefulWidget {
  const SampleProofGalleryPage({super.key});

  @override
  State<SampleProofGalleryPage> createState() => _SampleProofGalleryPageState();
}

class _SampleProofGalleryPageState extends State<SampleProofGalleryPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final DatabaseService _dbService = DatabaseService();
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _receiptRows = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _proofRows = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _onboardingReceiptProofRows =
      <Map<String, dynamic>>[];
  List<SchoolModel> _localProofSchools = <SchoolModel>[];

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
      await _dbService.syncData();
      final receiptResponse = await _supabase
          .from('school_sample_distributions')
          .select(
            'id,sample_name,distributed_at,stamped_receipt_url,stamped_receipt_path,schools(name)',
          )
          .not('stamped_receipt_url', 'is', null)
          .order('distributed_at', ascending: false)
          .limit(300);
      final proofResponse = await _supabase
          .from('schools')
          .select(
            'id,name,county,sample_proof_url,sample_proof_path,created_at',
          )
          .not('sample_proof_url', 'is', null)
          .order('created_at', ascending: false)
          .limit(300);
      final onboardingReceiptProofResponse = await _supabase
          .from('school_sample_distributions')
          .select(
            'id,sample_name,distributed_at,stamped_receipt_url,stamped_receipt_path,schools(name,county)',
          )
          .eq('sample_category', 'Onboarding')
          .not('stamped_receipt_url', 'is', null)
          .order('distributed_at', ascending: false)
          .limit(300);
      if (!mounted) return;
      final localSchools = await _dbService.getAllSchoolProfiles();
      setState(() {
        _receiptRows = List<Map<String, dynamic>>.from(
          (receiptResponse as List).map(
            (e) => Map<String, dynamic>.from(e as Map),
          ),
        );
        _proofRows = List<Map<String, dynamic>>.from(
          (proofResponse as List).map(
            (e) => Map<String, dynamic>.from(e as Map),
          ),
        );
        _onboardingReceiptProofRows = List<Map<String, dynamic>>.from(
          (onboardingReceiptProofResponse as List).map(
            (e) => Map<String, dynamic>.from(e as Map),
          ),
        );
        _localProofSchools =
            localSchools
                .where(
                  (s) =>
                      (s.sampleProofUrl == null ||
                          s.sampleProofUrl!.trim().isEmpty) &&
                      (s.sampleProofPath != null &&
                          s.sampleProofPath!.trim().isNotEmpty),
                )
                .toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load photos: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Sample Photos'),
          actions: [
            IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Onboarding Proofs'),
              Tab(text: 'Stamped Receipts'),
            ],
          ),
        ),
        body:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                )
                : TabBarView(
                  children: [
                    _buildOnboardingProofGrid(),
                    _buildStampedReceiptGrid(),
                  ],
                ),
      ),
    );
  }

  Widget _buildOnboardingProofGrid() {
    final fromSchools =
        _proofRows
            .where(
              (row) =>
                  (row['sample_proof_url']?.toString().trim().isNotEmpty ??
                      false),
            )
            .toList();
    final fromReceipts =
        _onboardingReceiptProofRows
            .where(
              (row) =>
                  (row['stamped_receipt_url']?.toString().trim().isNotEmpty ??
                      false),
            )
            .toList();

    if (fromSchools.isEmpty &&
        fromReceipts.isEmpty &&
        _localProofSchools.isEmpty) {
      return const Center(child: Text('No onboarding proof photos yet.'));
    }

    final mergedCount =
        fromSchools.length + fromReceipts.length + _localProofSchools.length;
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.88,
      ),
      itemCount: mergedCount,
      itemBuilder: (context, index) {
        if (index < fromSchools.length) {
          final row = fromSchools[index];
          final url = row['sample_proof_url']?.toString() ?? '';
          final schoolName = row['name']?.toString() ?? 'School';
          final county = row['county']?.toString() ?? '';
          return _buildPhotoCard(
            url: url,
            title: schoolName,
            subtitle:
                county.isEmpty
                    ? 'Onboarding proof'
                    : '$county • Onboarding proof',
            onDelete: () => _deleteSchoolProof(row),
          );
        }

        if (index < fromSchools.length + fromReceipts.length) {
          final row = fromReceipts[index - fromSchools.length];
          final url = row['stamped_receipt_url']?.toString() ?? '';
          final schoolName = row['schools']?['name']?.toString() ?? 'School';
          final county = row['schools']?['county']?.toString() ?? '';
          return _buildPhotoCard(
            url: url,
            title: schoolName,
            subtitle:
                county.isEmpty
                    ? 'Onboarding proof (receipt)'
                    : '$county • Onboarding proof (receipt)',
            onDelete: () => _deleteReceiptProof(row),
          );
        }

        final localSchool =
            _localProofSchools[index -
                fromSchools.length -
                fromReceipts.length];
        final localPath = localSchool.sampleProofPath?.toString() ?? '';
        final county = localSchool.county;
        return _buildPhotoCard(
          url: '',
          localPath: localPath,
          title: localSchool.name,
          subtitle:
              county.isEmpty
                  ? 'Onboarding proof (local unsynced)'
                  : '$county • Onboarding proof (local unsynced)',
          onDelete: () => _deleteLocalSchoolProof(localSchool.id),
        );
      },
    );
  }

  Widget _buildStampedReceiptGrid() {
    if (_receiptRows.isEmpty) {
      return const Center(child: Text('No stamped sample photos yet.'));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.88,
      ),
      itemCount: _receiptRows.length,
      itemBuilder: (context, index) {
        final row = _receiptRows[index];
        final url = row['stamped_receipt_url']?.toString() ?? '';
        final schoolName = row['schools']?['name']?.toString() ?? 'School';
        final sampleName = row['sample_name']?.toString() ?? 'Sample';
        return _buildPhotoCard(
          url: url,
          title: schoolName,
          subtitle: sampleName,
          onDelete: () => _deleteReceiptProof(row),
        );
      },
    );
  }

  Widget _buildPhotoCard({
    required String url,
    String? localPath,
    required String title,
    required String subtitle,
    required VoidCallback onDelete,
  }) {
    return InkWell(
      onTap: () {
        showDialog<void>(
          context: context,
          builder:
              (_) => Dialog(
                child: InteractiveViewer(
                  child: Image.network(url, fit: BoxFit.contain),
                ),
              ),
        );
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child:
                  (localPath != null && localPath.trim().isNotEmpty)
                      ? Image.file(
                        File(localPath),
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder:
                            (_, __, ___) => Container(
                              color: Colors.grey.shade200,
                              alignment: Alignment.center,
                              child: const Text('Could not load'),
                            ),
                      )
                      : Image.network(
                        url,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder:
                            (_, __, ___) => Container(
                              color: Colors.grey.shade200,
                              alignment: Alignment.center,
                              child: const Text('Could not load'),
                            ),
                      ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '$title\n$subtitle',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Delete photo',
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteLocalSchoolProof(String schoolId) async {
    final approved = await _confirmDelete();
    if (!approved) return;
    try {
      final schools = await _dbService.getAllSchoolProfiles();
      final idx = schools.indexWhere((s) => s.id == schoolId);
      if (idx == -1) return;
      final school = schools[idx];
      final updated = SchoolModel(
        id: school.id,
        name: school.name,
        phone: school.phone,
        county: school.county,
        focusAreas: school.focusAreas,
        bookCategory: school.bookCategory,
        latitude: school.latitude,
        longitude: school.longitude,
        photoUrl: school.photoUrl,
        photoPath: school.photoPath,
        capturedBy: school.capturedBy,
        capturedAt: school.capturedAt,
        captureStatus: school.captureStatus,
        contactName: school.contactName,
        contactPhone: school.contactPhone,
        contactTitle: school.contactTitle,
        feedback: school.feedback,
        notes: school.notes,
samplesLeft: school.samplesLeft,
         sampleBooks: school.sampleBooks,
         sampleProofUrl: null,
         sampleProofPath: null,
        schoolOwnership: school.schoolOwnership,
        schoolOwnershipOther: school.schoolOwnershipOther,
        schoolPopulation: school.schoolPopulation,
        schoolLifecycleStatus: school.schoolLifecycleStatus,
        engagementType: school.engagementType,
        isSynced: false,
        createdAt: school.createdAt,
        updatedAt: DateTime.now(),
      );
      await _dbService.saveSchoolProfile(updated);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete local photo: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteSchoolProof(Map<String, dynamic> row) async {
    final schoolId = row['id']?.toString();
    if (schoolId == null || schoolId.isEmpty) return;
    final approved = await _confirmDelete();
    if (!approved) return;

    try {
      await _supabase
          .from('schools')
          .update({'sample_proof_url': null, 'sample_proof_path': null})
          .eq('id', schoolId);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete photo: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteReceiptProof(Map<String, dynamic> row) async {
    final receiptId = row['id']?.toString();
    if (receiptId == null || receiptId.isEmpty) return;
    final approved = await _confirmDelete();
    if (!approved) return;

    try {
      await _supabase
          .from('school_sample_distributions')
          .update({'stamped_receipt_url': null, 'stamped_receipt_path': null})
          .eq('id', receiptId);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete photo: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<bool> _confirmDelete() async {
    final answer = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Delete Photo'),
            content: const Text('Are you sure you want to delete this photo?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
    return answer == true;
  }
}
