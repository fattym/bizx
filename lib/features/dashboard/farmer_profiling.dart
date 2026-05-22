import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/constants/colors.dart';
import '../database/database_service.dart';
import '../../models/farmer_model.dart';

class SchoolProfiling extends StatefulWidget {
  const SchoolProfiling({super.key});

  @override
  State<SchoolProfiling> createState() => _SchoolProfilingState();
}

class _SchoolProfilingState extends State<SchoolProfiling> {
  // --- FORM STATE ---
  final DatabaseService _dbService = DatabaseService();
  final TextEditingController _schoolNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _countyController = TextEditingController();
  final List<String> _focusAreas = [
    "Primary",
    "Secondary",
    "Reference",
    "Teacher Guides",
    "Other",
  ];
  String? _selectedFocusArea;
  String? _priceSensitivity;
  bool _isSaving = false;
  Position? _currentPosition;
  String? _locationStatus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchCurrentLocation();
    });
  }

  @override
  void dispose() {
    _schoolNameController.dispose();
    _phoneController.dispose();
    _countyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("School Profiling"),
        backgroundColor: AppColors.primaryGreen,
        actions: [
          IconButton(
            icon: const Icon(Icons.save_outlined),
            onPressed: () => _handleSave(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader("👤 SCHOOL PROFILE"),
            _buildTextField(
              "School Name",
              Icons.school_outlined,
              controller: _schoolNameController,
            ),
            _buildTextField(
              "Phone Number",
              Icons.phone_android,
              keyboard: TextInputType.phone,
              controller: _phoneController,
            ),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    "County",
                    Icons.map_outlined,
                    controller: _countyController,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildTextField("Sub-County", Icons.location_city),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _locationBanner(),

            const SizedBox(height: 24),
            _sectionHeader("🏫 INSTITUTION DETAILS"),
            _buildSingleFocusAreaSelect(),
            const SizedBox(height: 10),
            ..._buildFocusAreaInput(),

            const SizedBox(height: 24),
            _sectionHeader("📚 CURRENT READING USAGE"),
            _buildTextField("Current Publisher", Icons.menu_book_outlined),
            _buildDropdown("Delivery Frequency", [
              "Daily",
              "Twice Weekly",
              "Weekly",
            ]),

            const SizedBox(height: 24),
            _sectionHeader("🟩 LONGHORN ADOPTION"),
            _buildDropdown("Aware of Longhorn?", ["No", "Yes"]),
            _buildDropdown("Trial Status", [
              "Never Engaged",
              "Trialed Once",
              "Regular Partner",
            ]),
            _buildTextField(
              "Longhorn Titles Used",
              Icons.branding_watermark_outlined,
            ),

            const SizedBox(height: 24),
            _sectionHeader("🛒 PARTNER BEHAVIOR"),
            _buildDropdown("Primary Buying Outlet", [
              "Bookshop",
              "Distributor",
              "School Office",
            ]),
            _buildTextField(
              "Distance to Outlet (KM)",
              Icons.route,
              keyboard: TextInputType.number,
            ),
            _buildDropdown("Price Sensitivity", [
              "Low",
              "Medium",
              "High",
            ], (val) => setState(() => _priceSensitivity = val)),

            const SizedBox(height: 32),
            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }

  // --- UI COMPONENTS ---

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: AppColors.primaryGreen,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    IconData icon, {
    TextInputType keyboard = TextInputType.text,
    TextEditingController? controller,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: AppColors.primaryGreen),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildDropdown(
    String label,
    List<String> items, [
    Function(String?)? onChanged,
  ]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        items:
            items
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
        onChanged: onChanged ?? (val) {},
      ),
    );
  }

  Widget _buildSingleFocusAreaSelect() {
    return Wrap(
      spacing: 8,
      children:
          _focusAreas.map((type) {
            final isSelected = _selectedFocusArea == type;
            return FilterChip(
              label: Text(type),
              selected: isSelected,
              onSelected: (val) {
                setState(() => _selectedFocusArea = val ? type : null);
              },
              selectedColor: AppColors.primaryGreen.withValues(alpha: 0.2),
              checkmarkColor: AppColors.primaryGreen,
            );
          }).toList(),
    );
  }

  List<Widget> _buildFocusAreaInput() {
    if (_selectedFocusArea == null) return [];
    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TextField(
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: "Number of $_selectedFocusArea",
            prefixIcon: const Icon(
              Icons.numbers,
              color: AppColors.secondaryOrange,
            ),
            border: const UnderlineInputBorder(),
          ),
        ),
      ),
    ];
  }

  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: _isSaving ? null : _handleSave,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: const Text(
        "SAVE SCHOOL PROFILE",
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _locationBanner() {
    final status = _locationStatus ?? 'Fetching GPS location...';
    final coords =
        _currentPosition == null
            ? 'Waiting for coordinates'
            : '${_currentPosition!.latitude.toStringAsFixed(5)}, ${_currentPosition!.longitude.toStringAsFixed(5)}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primaryGreen.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'GPS Location',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(status),
          const SizedBox(height: 4),
          Text(coords, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _fetchCurrentLocation,
            child: const Text('Refresh Location'),
          ),
        ],
      ),
    );
  }

  Future<void> _fetchCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() {
          _locationStatus = 'Enable location services to capture GPS.';
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
          _locationStatus = 'Location permission is required.';
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (!mounted) return;
      setState(() {
        _currentPosition = position;
        _locationStatus = 'GPS ready.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _locationStatus = 'Could not fetch location: $e';
      });
    }
  }

  Future<void> _handleSave() async {
    if (_schoolNameController.text.trim().isEmpty ||
        _phoneController.text.trim().isEmpty ||
        _countyController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please fill in school name, phone, and county."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final currentUserId = _dbService.getCurrentUserId();
      final position =
          _currentPosition ??
          await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
            ),
          );

      final school = SchoolModel(
        name: _schoolNameController.text.trim(),
        phone: _phoneController.text.trim(),
        county: _countyController.text.trim(),
        focusAreas: [_selectedFocusArea ?? 'General'],
        latitude: position.latitude,
        longitude: position.longitude,
        captureStatus: _locationStatus ?? 'School profile saved',
        notes:
            _priceSensitivity == null || _priceSensitivity!.isEmpty
                ? null
                : 'Price sensitivity: $_priceSensitivity',
        capturedBy: currentUserId,
        capturedAt: DateTime.now(),
      );

      await _dbService.saveSchoolProfile(school);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("School profile saved with GPS location."),
          backgroundColor: AppColors.primaryGreen,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to save school profile: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}
