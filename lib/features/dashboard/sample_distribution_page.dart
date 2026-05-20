import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:typed_data';

import '../../core/constants/colors.dart';
import '../../features/database/database_service.dart';
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
  String _searchQuery = "";
  int? _currentRole;
  final List<String> _distributionLog = [];
  List<CatalogItemModel> _samples = <CatalogItemModel>[];
  int _initialSampleTotal = 0;
  XFile? _recoveredLostPhoto;

  @override
  void initState() {
    super.initState();
    _schoolsFuture = _dbService.getAllSchools();
    _loadCurrentRole();
    _loadSamples();
    _recoverLostCameraData();
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
  }

  Future<void> _loadSamples() async {
    final samples = await _dbService.getCatalogItems(itemType: 'sample');
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
        const SnackBar(
          content: Text('Recovered a previously captured photo.'),
        ),
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

    final receiptUpload = await _uploadStampedReceipt(
      photo: proofPhoto,
      sampleName: sample.name,
      schoolName: school.name,
    );
    if ((receiptUpload['url'] ?? '').trim().isEmpty) {
      if (!mounted) return;
      final reason =
          (receiptUpload['error'] ?? '').trim().isEmpty
              ? 'Could not upload stamped receipt photo. Try again.'
              : 'Photo upload failed: ${receiptUpload['error']}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(reason),
          backgroundColor: Colors.red,
        ),
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
          stockQty: sample.stockQty - 1,
          description: sample.description,
          isActive: sample.isActive,
          isSynced: sample.isSynced,
          createdAt: sample.createdAt,
          updatedAt: sample.updatedAt,
        );
      }
      _distributionLog.insert(
        0,
        '${sample.name} given to ${school.name} (proof captured)',
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
        quantity: 1,
        notes: 'Distributed from Sample Distribution page.',
        stampedReceiptUrl: receiptUpload['url'],
        stampedReceiptPath: receiptUpload['path'],
      );
      await _dbService.decrementCatalogStock(sample.id, 1);
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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${sample.name} assigned to ${school.name}'),
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
                  label: Text(capturedPhoto == null ? 'Capture Photo' : 'Retake'),
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
          await supabase.storage.from(bucket).uploadBinary(
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
      final q = _searchQuery.trim().toLowerCase();
      final matchesSearch =
          q.isEmpty ||
          sample.name.toLowerCase().contains(q) ||
          (sample.description ?? '').toLowerCase().contains(q);
      return matchesCategory && matchesSearch;
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
        actions: [
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

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildHeader(roleLabel),
              const SizedBox(height: 16),
              _buildRemainingTracker(),
              const SizedBox(height: 16),
              _buildSchoolSelector(schools),
              const SizedBox(height: 16),
              _buildSearchBar(),
              const SizedBox(height: 16),
              _buildCategoryChips(),
              const SizedBox(height: 20),
              Text(
                'Available Samples',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ..._filteredSamples().map(
                (sample) => _buildSampleCard(sample, schools),
              ),
              const SizedBox(height: 24),
              _buildHistory(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(String roleLabel) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryGreen, Color(0xFF004D2E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Role: $roleLabel',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 8),
          const Text(
            'Select a school, pick a sample, and hand it over from one screen.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
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
        value: _selectedSchoolId,
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

  Widget _buildRemainingTracker() {
    final progress =
        (_remainingSampleTotal + _distributedSampleTotal) == 0
            ? 0.0
            : _distributedSampleTotal /
                (_remainingSampleTotal + _distributedSampleTotal);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Samples Remaining',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$_remainingSampleTotal left',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$_distributedSampleTotal distributed',
                  style: const TextStyle(fontWeight: FontWeight.w600),
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
              onSelected: (_) => setState(() => _selectedCategory = category),
              selectedColor: AppColors.primaryGreen.withOpacity(0.18),
            );
          }).toList(),
    );
  }

  Widget _buildSampleCard(
    CatalogItemModel sample,
    List<SchoolModel> schools,
  ) {
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sample.name,
                      style: const TextStyle(
                        fontSize: 16,
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
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withOpacity(0.12),
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
          Row(
            children: [
              Icon(
                Icons.category_outlined,
                size: 18,
                color: Colors.grey[700],
              ),
              const SizedBox(width: 6),
              Text(sample.category),
              const Spacer(),
              ElevatedButton.icon(
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
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Distribution',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
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
