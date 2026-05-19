import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/colors.dart';
import '../database/database_service.dart';
import '../../models/farmer_model.dart';

class SchoolOnboarding extends StatefulWidget {
  const SchoolOnboarding({super.key});

  @override
  State<SchoolOnboarding> createState() => _SchoolOnboardingState();
}

class _SchoolOnboardingState extends State<SchoolOnboarding> {
  final DatabaseService _dbService = DatabaseService();
  int _currentStep = 0;

  // --- FORM STATE VARIABLES ---
  final TextEditingController _shopNameController = TextEditingController();
  final TextEditingController _contactNameController = TextEditingController();
  final TextEditingController _contactPhoneController =
      TextEditingController();
  final TextEditingController _contactTitleController = TextEditingController();
  final TextEditingController _feedbackController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _schoolOwnershipOtherController =
      TextEditingController();
  final TextEditingController _schoolPopulationController =
      TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  String? _dealerType;
  String? _shopCategory;
  String? _selectedProduct;
  String? _selectedBookProgram;
  String? _samplesLeft;
  String? _selectedSampleBook;
  String? _partnerSubtype;
  String? _selectedCounty;
  String? _schoolOwnership;
  String? _schoolLifecycleStatus;
  String? _engagementType;
  List<String> _sampleBookOptions = <String>[];
  XFile? _capturedPhoto;
  Uint8List? _capturedPhotoBytes;
  Position? _currentPosition;
  String? _captureStatus;
  bool isOffline = true;
  bool _isSubmitting = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  static const List<String> _bookOptions = [
    "Grade 1 Reader Pack",
    "English Workbook Bundle",
    "Reference Handbook",
    "Story Books Pack",
    "Teacher Guide Kit",
  ];

  static const List<String> _counties = [
    'Nairobi',
    'Mombasa',
    'Kisumu',
    'Nakuru',
    'Uasin Gishu',
    'Kiambu',
    'Machakos',
    'Kajiado',
    'Meru',
    'Kakamega',
  ];

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _shopNameController.dispose();
    _contactNameController.dispose();
    _contactPhoneController.dispose();
    _contactTitleController.dispose();
    _feedbackController.dispose();
    _notesController.dispose();
    _schoolOwnershipOtherController.dispose();
    _schoolPopulationController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _watchConnectivity();
      _fetchCurrentLocation();
      _loadSampleBooks();
    });
  }

  Future<void> _watchConnectivity() async {
    final initial = await Connectivity().checkConnectivity();
    if (!mounted) return;
    setState(() => isOffline = initial.contains(ConnectivityResult.none));

    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      if (!mounted) return;
      setState(() => isOffline = results.contains(ConnectivityResult.none));
    });
  }

  // --- SUBMISSION LOGIC ---
  Future<void> _submitForm() async {
    if (_isSubmitting) return;
    final schoolName = _shopNameController.text.trim();
    final phone = _contactPhoneController.text.trim();
    final county = _selectedCounty?.trim() ?? '';

    if (schoolName.isEmpty || phone.isEmpty || county.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter school name, phone number, and county.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final payload = _buildSubmissionPayload();
    final focusAreas = <String>[
      if (_shopCategory != null) _shopCategory!,
      if (_selectedProduct != null) _selectedProduct!,
      if (_partnerSubtype != null) _partnerSubtype!,
    ];
    if (focusAreas.isEmpty) {
      focusAreas.add('General');
    }

    setState(() => _isSubmitting = true);
    final uploadedPhoto = await _uploadSchoolPhoto();

    final school = SchoolModel(
      name: schoolName,
      phone: phone,
      county: county,
      focusAreas: focusAreas,
      bookCategory: _selectedBookProgram,
      latitude: _currentPosition?.latitude,
      longitude: _currentPosition?.longitude,
      photoUrl: uploadedPhoto['photoUrl'],
      photoPath: uploadedPhoto['photoPath'],
      captureStatus: _captureStatus,
      contactName: _contactNameController.text.trim().isEmpty
          ? null
          : _contactNameController.text.trim(),
      contactPhone: _contactPhoneController.text.trim(),
      contactTitle: _contactTitleController.text.trim().isEmpty
          ? null
          : _contactTitleController.text.trim(),
      feedback: _feedbackController.text.trim().isEmpty
          ? null
          : _feedbackController.text.trim(),
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      samplesLeft: _samplesLeft,
      sampleBook: _selectedSampleBook,
      schoolOwnership: _schoolOwnership,
      schoolOwnershipOther:
          _schoolOwnership == 'Others'
              ? _schoolOwnershipOtherController.text.trim()
              : null,
      schoolPopulation: int.tryParse(_schoolPopulationController.text.trim()),
      schoolLifecycleStatus: _schoolLifecycleStatus,
      engagementType: _engagementType,
      capturedBy: _dbService.getCurrentUserId(),
      capturedAt: DateTime.now(),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "${_dealerType ?? "School"} onboarding collected",
        ),
        backgroundColor: AppColors.primaryGreen,
        duration: const Duration(seconds: 1),
      ),
    );

    debugPrint('Onboarding payload: $payload');

    try {
      await _dbService.saveSchoolProfile(school);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }

    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "${_dealerType ?? "School"} onboarded successfully (stored locally)",
          ),
          backgroundColor: AppColors.primaryGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pop(context);
    });
  }

  Future<void> _captureSchoolPhoto() async {
    try {
      final photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );
      if (!mounted || photo == null) return;
      final bytes = await photo.readAsBytes();
      setState(() {
        _capturedPhoto = photo;
        _capturedPhotoBytes = bytes;
        _captureStatus = "Photo captured successfully";
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _captureStatus = "Could not open the camera";
      });
    }
  }

  Future<void> _fetchCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() {
          _captureStatus = "Enable location services to capture GPS";
        });
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _captureStatus = "Location permission is required";
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (!mounted) return;
      setState(() {
        _currentPosition = position;
        _captureStatus = "GPS updated successfully";
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _captureStatus = "Could not fetch the current location";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Onboard New School"),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Icon(
              isOffline ? Icons.cloud_off : Icons.cloud_done,
              color: isOffline ? AppColors.secondaryOrange : Colors.white,
            ),
          ),
        ],
      ),
      body: Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primaryGreen),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final stepperType =
                constraints.maxWidth < 360
                    ? StepperType.vertical
                    : StepperType.horizontal;

            return Stepper(
              type: stepperType,
              currentStep: _currentStep,
              onStepContinue: () {
                final validationError = _validateCurrentStep();
                if (validationError != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(validationError),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                if (_currentStep < 3) {
                  setState(() => _currentStep += 1);
                } else {
                  _submitForm();
                }
              },
              onStepCancel: () {
                if (_currentStep > 0) setState(() => _currentStep -= 1);
              },
              controlsBuilder: (context, details) {
                return _buildStepControls(details);
              },
              steps: [
                _buildLocationStep(),
                _buildClassificationStep(),
                _buildIntelligenceStep(),
                _buildVisitationStep(),
              ],
            );
          },
        ),
      ),
    );
  }

  Step _buildLocationStep() {
    return Step(
      isActive: _currentStep >= 0,
      state: _currentStep > 0 ? StepState.complete : StepState.editing,
      title: const Text("Loc"),
      content: Column(
        children: [
          _buildSectionHeader("School Visuals & Location"),
          const SizedBox(height: 20),
          _buildMediaPicker(),
          const SizedBox(height: 20),
          _buildLocationDisplay(),
        ],
      ),
    );
  }

  Step _buildClassificationStep() {
    return Step(
      isActive: _currentStep >= 1,
      state:
          _currentStep > 1
              ? StepState.complete
              : (_currentStep == 1 ? StepState.editing : StepState.indexed),
      title: const Text("School"),
      content: Column(
        children: [
          _buildSectionHeader("School Classification"),
          TextField(
            controller: _shopNameController,
            decoration: InputDecoration(
              labelText: "School Name",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedCounty,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: "County",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            items: _counties
                .map(
                  (county) => DropdownMenuItem<String>(
                    value: county,
                    child: Text(
                      county,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _selectedCounty = value),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _dealerType,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: "School Type",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            items: const [
              DropdownMenuItem(value: "School", child: Text("School")),
              DropdownMenuItem(
                value: "Distributor",
                child: Text("Distributor"),
              ),
              DropdownMenuItem(
                value: "Bookshop",
                child: Text("Bookshop"),
              ),
            ],
            onChanged: (val) => setState(() {
              _dealerType = val;
              _shopCategory = null;
              _partnerSubtype = null;
              _selectedProduct = null;
              _selectedBookProgram = null;
            }),
          ),
          const SizedBox(height: 16),
          if (_dealerType == "School")
            _buildDropdown("School Category", [
              "Primary",
              "Secondary",
            ], (val) => setState(() => _shopCategory = val), value: _shopCategory)
          else if (_dealerType == "Bookshop")
            _buildDropdown("Bookshop Category", [
              "Retail",
              "Chain",
              "Independent",
            ], (val) => setState(() => _partnerSubtype = val), value: _partnerSubtype)
          else if (_dealerType == "Distributor")
            _buildDropdown("Distributor Category", [
              "Regional",
              "National",
              "Specialist",
            ], (val) => setState(() => _partnerSubtype = val), value: _partnerSubtype)
          else
            const SizedBox.shrink(),
          const SizedBox(height: 24),
          if (_dealerType == "School") ...[
            _buildSectionHeader("Learning Materials Stocked"),
            _buildSingleSelect([
              "Readers",
              "Workbooks",
              "Reference",
              "Teacher Guides",
            ]),
            const SizedBox(height: 16),
            _buildDropdown(
              "Book Program",
              ["Book List", "Book Fund"],
              (val) => setState(() => _selectedBookProgram = val),
              value: _selectedBookProgram,
            ),
          ] else if (_dealerType == "Bookshop") ...[
            _buildSectionHeader("Bookshop Services"),
            _buildSingleSelect([
              "Retail",
              "Bulk Supply",
              "Special Orders",
              "Promotions",
            ]),
            const SizedBox(height: 16),
            _buildDropdown(
              "Book Program",
              ["Book List", "Book Fund"],
              (val) => setState(() => _selectedBookProgram = val),
              value: _selectedBookProgram,
            ),
          ] else if (_dealerType == "Distributor") ...[
            _buildSectionHeader("Distribution Coverage"),
            _buildSingleSelect(["County", "Regional", "National", "Online"]),
            const SizedBox(height: 16),
            _buildDropdown(
              "Book Program",
              ["Book List", "Book Fund"],
              (val) => setState(() => _selectedBookProgram = val),
              value: _selectedBookProgram,
            ),
          ],
          if (_dealerType == "School") ...[
            const SizedBox(height: 16),
            _buildDropdown(
              "School Ownership",
              ["Private", "Public", "Others"],
              (val) => setState(() {
                _schoolOwnership = val;
                if (val != 'Others') {
                  _schoolOwnershipOtherController.clear();
                }
              }),
              value: _schoolOwnership,
            ),
            if (_schoolOwnership == 'Others') ...[
              const SizedBox(height: 16),
              _buildTextField(
                "Specify Ownership",
                controller: _schoolOwnershipOtherController,
              ),
            ],
            const SizedBox(height: 16),
            _buildTextField(
              "School Population",
              controller: _schoolPopulationController,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            _buildDropdown(
              "School Status",
              ["Existing", "New"],
              (val) => setState(() => _schoolLifecycleStatus = val),
              value: _schoolLifecycleStatus,
            ),
            const SizedBox(height: 16),
            _buildDropdown(
              "Engagement Type",
              [
                "Cold Lead",
                "Warm Lead",
                "Follow-up",
                "Existing Relationship",
                "New Prospect",
              ],
              (val) => setState(() => _engagementType = val),
              value: _engagementType,
            ),
          ],
        ],
      ),
    );
  }

  Step _buildIntelligenceStep() {
    return Step(
      isActive: _currentStep >= 2,
      state:
          _currentStep > 2
              ? StepState.complete
              : (_currentStep == 2 ? StepState.editing : StepState.indexed),
      title: const Text("Data"),
      content: Column(
        children: [
          _buildSectionHeader(_contactPersonSectionTitle),
          _buildTextField(
            _contactNameLabel,
            controller: _contactNameController,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            _contactPhoneLabel,
            controller: _contactPhoneController,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            _contactTitleLabel,
            controller: _contactTitleController,
          ),
          const SizedBox(height: 24),
          _buildSectionHeader(_samplesSectionTitle),
          _buildDropdown(
            _samplesLeftLabel,
            ["Yes", "No"],
            (val) => setState(() {
              _samplesLeft = val;
              if (val != "Yes") {
                _selectedSampleBook = null;
              }
            }),
            value: _samplesLeft,
          ),
          if (_samplesLeft == "Yes") ...[
            const SizedBox(height: 16),
            _buildDropdown(
              _sampleBookLabel,
              _sampleBookOptions.isNotEmpty ? _sampleBookOptions : _bookOptions,
              (val) => setState(() => _selectedSampleBook = val),
              value: _selectedSampleBook,
            ),
          ],
        ],
      ),
    );
  }

  Step _buildVisitationStep() {
    return Step(
      isActive: _currentStep >= 3,
      state: _currentStep == 3 ? StepState.editing : StepState.indexed,
      title: const Text("Feedback"),
      content: Column(
        children: [
          _buildSectionHeader(_feedbackSectionTitle),
          _buildTextField(
            _feedbackLabel,
            maxLines: 3,
            controller: _feedbackController,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            _notesLabel,
            maxLines: 3,
            controller: _notesController,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.primaryGreen,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  String get _contactPersonSectionTitle {
    switch (_dealerType) {
      case "Bookshop":
        return "Bookshop Contact Person";
      case "Distributor":
        return "Distributor Contact Person";
      case "School":
      default:
        return "Contact Person";
    }
  }

  String get _contactNameLabel {
    switch (_dealerType) {
      case "Bookshop":
        return "Bookshop Contact Name";
      case "Distributor":
        return "Distributor Contact Name";
      case "School":
      default:
        return "Name";
    }
  }

  String get _contactPhoneLabel {
    switch (_dealerType) {
      case "Bookshop":
        return "Bookshop Phone Number";
      case "Distributor":
        return "Distributor Phone Number";
      case "School":
      default:
        return "Phone Number";
    }
  }

  String get _contactTitleLabel {
    switch (_dealerType) {
      case "Bookshop":
        return "Title in the Bookshop";
      case "Distributor":
        return "Title in the Distributor";
      case "School":
      default:
        return "Title in the School";
    }
  }

  String get _samplesSectionTitle {
    switch (_dealerType) {
      case "Bookshop":
        return "Samples Left in Bookshop";
      case "Distributor":
        return "Samples Left for Distribution";
      case "School":
      default:
        return "Samples Left";
    }
  }

  String get _samplesLeftLabel {
    switch (_dealerType) {
      case "Bookshop":
        return "Any samples left?";
      case "Distributor":
        return "Any stock samples left?";
      case "School":
      default:
        return "Samples left?";
    }
  }

  String get _sampleBookLabel {
    switch (_dealerType) {
      case "Bookshop":
        return "Select Book for Bookshop";
      case "Distributor":
        return "Select Book for Distributor";
      case "School":
      default:
        return "Select Book";
    }
  }

  String get _feedbackSectionTitle {
    switch (_dealerType) {
      case "Bookshop":
        return "Bookshop Feedback";
      case "Distributor":
        return "Distributor Feedback";
      case "School":
      default:
        return "Feedback";
    }
  }

  String get _feedbackLabel {
    switch (_dealerType) {
      case "Bookshop":
        return "Bookshop Feedback";
      case "Distributor":
        return "Distributor Feedback";
      case "School":
      default:
        return "Feedback";
    }
  }

  String get _notesLabel {
    switch (_dealerType) {
      case "Bookshop":
        return "Bookshop Notes";
      case "Distributor":
        return "Distributor Notes";
      case "School":
      default:
        return "Notes";
    }
  }

  Widget _buildDropdown(
    String label,
    List<String> items,
    ValueChanged<String?> onChanged,
    {String? value}
  ) {
    return DropdownButtonFormField<String>(
      isExpanded: true,
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: items
          .map(
            (item) => DropdownMenuItem<String>(
              value: item,
              child: Text(
                item,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildSingleSelect(List<String> items) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children:
          items
              .map(
                (item) => FilterChip(
                  label: Text(item),
                  selected: _selectedProduct == item,
                  onSelected: (_) => setState(() => _selectedProduct = item),
                ),
              )
              .toList(),
    );
  }

  Widget _buildTextField(
    String label, {
    TextEditingController? controller,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildMediaPicker() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "School Photo",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child:
                  _capturedPhoto == null
                      ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.photo_camera_outlined,
                              size: 44,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _captureStatus ?? "Take a photo of the school",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                      )
                      : ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child:
                            Image.memory(
                              _capturedPhotoBytes!,
                              fit: BoxFit.cover,
                            ),
                      ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _captureSchoolPhoto,
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text("Capture Photo"),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                tooltip: 'Retake photo',
                onPressed:
                    _capturedPhoto == null
                        ? null
                        : () => setState(() {
                          _capturedPhoto = null;
                          _capturedPhotoBytes = null;
                          _captureStatus = "Photo cleared";
                        }),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocationDisplay() {
    final latitude = _currentPosition?.latitude;
    final longitude = _currentPosition?.longitude;
    final hasLocation = latitude != null && longitude != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  "GPS Capture",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              TextButton.icon(
                onPressed: _fetchCurrentLocation,
                icon: const Icon(Icons.my_location),
                label: const Text("Refresh"),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color:
                  hasLocation
                      ? AppColors.primaryGreen.withOpacity(0.08)
                      : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _captureStatus ??
                      (hasLocation
                          ? "GPS captured successfully"
                          : "Location not captured yet"),
                  style: TextStyle(
                    color:
                        hasLocation
                            ? AppColors.primaryGreen
                            : Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (hasLocation) ...[
                  const SizedBox(height: 8),
                  Text("Latitude: ${latitude!.toStringAsFixed(6)}"),
                  Text("Longitude: ${longitude!.toStringAsFixed(6)}"),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _buildSubmissionPayload() {
    return {
      'shopName': _shopNameController.text,
      'county': _selectedCounty,
      'contactName': _contactNameController.text,
      'samplesLeft': _samplesLeft,
      'selectedSampleBook': _selectedSampleBook,
      'schoolOwnership': _schoolOwnership,
      'schoolOwnershipOther': _schoolOwnershipOtherController.text,
      'schoolPopulation': _schoolPopulationController.text,
      'schoolLifecycleStatus': _schoolLifecycleStatus,
      'engagementType': _engagementType,
      'photoPath': _capturedPhoto?.path,
      'photoCaptured': _capturedPhoto != null,
      'gpsLatitude': _currentPosition?.latitude,
      'gpsLongitude': _currentPosition?.longitude,
      'captureStatus': _captureStatus,
    };
  }

  Future<Map<String, String?>> _uploadSchoolPhoto() async {
    if (_capturedPhoto == null) {
      return {'photoUrl': null, 'photoPath': null};
    }

    final supabase = Supabase.instance.client;
    final fileExt = _capturedPhoto!.path.split('.').last.toLowerCase();
    final safeName =
        _shopNameController.text.trim().isEmpty
            ? 'school'
            : _shopNameController.text.trim().replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_');
    final fileName =
        'schools/${safeName}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
    final bytes = await _capturedPhoto!.readAsBytes();

    try {
      await supabase.storage.from('schools').uploadBinary(
        fileName,
        bytes,
        fileOptions: const FileOptions(upsert: true),
      );
      return {
        'photoUrl': supabase.storage.from('schools').getPublicUrl(fileName),
        'photoPath': fileName,
      };
    } catch (e) {
      debugPrint('School photo upload failed: $e');
      return {'photoUrl': null, 'photoPath': _capturedPhoto!.path};
    }
  }

  Future<void> _loadSampleBooks() async {
    try {
      final items = await _dbService.getCatalogItems(itemType: 'sample');
      if (!mounted) return;

      final options =
          items
              .map(
                (item) =>
                    item.category.isNotEmpty
                        ? '${item.name} • ${item.category}'
                        : item.name,
              )
              .toList();

      setState(() {
        _sampleBookOptions = options.isNotEmpty ? options : _bookOptions;
      });
    } catch (e) {
      debugPrint('Error loading sample books: $e');
      if (!mounted) return;
      setState(() {
        _sampleBookOptions = _bookOptions;
      });
    }
  }

  Widget _buildStepControls(ControlsDetails details) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 340;
        return Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            SizedBox(
              width: isNarrow ? constraints.maxWidth : null,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : details.onStepContinue,
                child: _isSubmitting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Continue'),
              ),
            ),
            SizedBox(
              width: isNarrow ? constraints.maxWidth : null,
              child: TextButton(
                onPressed: details.onStepCancel,
                child: const Text('Back'),
              ),
            ),
          ],
        );
      },
    );
  }

  String? _validateCurrentStep() {
    if (_currentStep == 1) {
      if (_shopNameController.text.trim().isEmpty) {
        return 'School name is required.';
      }
      if ((_selectedCounty ?? '').trim().isEmpty) {
        return 'County is required.';
      }
      if (_dealerType == null) {
        return 'School type is required.';
      }
      if (_dealerType == 'School') {
        if ((_schoolOwnership ?? '').trim().isEmpty) {
          return 'School ownership is required.';
        }
        if (_schoolOwnership == 'Others' &&
            _schoolOwnershipOtherController.text.trim().isEmpty) {
          return 'Please specify school ownership.';
        }
        final population = _schoolPopulationController.text.trim();
        final parsedPopulation = int.tryParse(population);
        if (population.isEmpty || parsedPopulation == null || parsedPopulation < 0) {
          return 'Enter a valid school population.';
        }
        if ((_schoolLifecycleStatus ?? '').trim().isEmpty) {
          return 'School status is required.';
        }
        if ((_engagementType ?? '').trim().isEmpty) {
          return 'Engagement type is required.';
        }
      }
    }

    if (_currentStep == 2) {
      final phone = _contactPhoneController.text.trim();
      if (phone.isEmpty) return 'Phone number is required.';
      final digits = phone.replaceAll(RegExp(r'[^0-9+]'), '');
      if (digits.length < 10) return 'Enter a valid phone number.';
    }

    return null;
  }
}
