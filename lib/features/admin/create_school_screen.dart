import 'package:flutter/material.dart';
import '../../models/farmer_model.dart';
import '../database/database_service.dart';

class CreateSchoolScreen extends StatefulWidget {
  const CreateSchoolScreen({super.key});

  @override
  State<CreateSchoolScreen> createState() => _CreateSchoolScreenState();
}

class _CreateSchoolScreenState extends State<CreateSchoolScreen> {
  final DatabaseService _dbService = DatabaseService();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _focusAreasController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  final _photoUrlController = TextEditingController();
  final _photoPathController = TextEditingController();
  final _captureStatusController = TextEditingController(
    text: 'School onboarded successfully',
  );

  String? _selectedCounty;
  String? _selectedBookCategory;
  bool _isLoading = false;

  // Dummy list of counties for the dropdown
  final List<String> _counties = [
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
    _nameController.dispose();
    _phoneController.dispose();
    _focusAreasController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _photoUrlController.dispose();
    _photoPathController.dispose();
    _captureStatusController.dispose();
    super.dispose();
  }

  List<String> _parseFocusAreas(String value) {
    return value
        .split(',')
        .map((area) => area.trim())
        .where((area) => area.isNotEmpty)
        .toList();
  }

  double? _parseDouble(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return double.tryParse(trimmed);
  }

  Future<void> _onboardSchool() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final focusAreas = _parseFocusAreas(_focusAreasController.text);
    final latitude = _parseDouble(_latitudeController.text);
    final longitude = _parseDouble(_longitudeController.text);
    final captureStatus =
        _captureStatusController.text.trim().isEmpty
            ? 'School onboarded successfully'
            : _captureStatusController.text.trim();

    setState(() {
      _isLoading = true;
    });

    try {
      final school = SchoolModel(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        county: _selectedCounty ?? 'Unknown',
        focusAreas: focusAreas,
        bookCategory: _selectedBookCategory,
        latitude: latitude,
        longitude: longitude,
        photoUrl:
            _photoUrlController.text.trim().isEmpty
                ? null
                : _photoUrlController.text.trim(),
        photoPath:
            _photoPathController.text.trim().isEmpty
                ? null
                : _photoPathController.text.trim(),
        capturedBy: _dbService.getCurrentUserId(),
        capturedAt: DateTime.now(),
        captureStatus: captureStatus,
        isSynced: false,
      );
      await _dbService.saveSchoolProfile(school);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('School onboarded (or queued offline)!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An unexpected error occurred: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Onboard New School')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            Text(
              'School Details',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Capture the school record using the same fields stored in Supabase.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'School Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.school),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter the school name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _focusAreasController,
              decoration: const InputDecoration(
                labelText: 'Focus Areas',
                helperText: 'Comma-separated values, e.g. Mathematics, Science',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.list_alt),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a phone number';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _latitudeController,
              decoration: const InputDecoration(
                labelText: 'Latitude',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.gps_fixed),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                signed: true,
                decimal: true,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _longitudeController,
              decoration: const InputDecoration(
                labelText: 'Longitude',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.gps_fixed_outlined),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                signed: true,
                decimal: true,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _photoUrlController,
              decoration: const InputDecoration(
                labelText: 'Photo URL',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.image_outlined),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _photoPathController,
              decoration: const InputDecoration(
                labelText: 'Photo Path',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.folder_open),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selectedCounty,
              decoration: const InputDecoration(
                labelText: 'County',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_city),
              ),
              hint: const Text('Select a county'),
              items:
                  _counties.map((String county) {
                    return DropdownMenuItem<String>(
                      value: county,
                      child: Text(county),
                    );
                  }).toList(),
              onChanged: (newValue) {
                setState(() {
                  _selectedCounty = newValue;
                });
              },
              validator:
                  (value) => value == null ? 'Please select a county' : null,
            ),
            const SizedBox(height: 16),
            const Divider(height: 32),
            Text(
              'School Program',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedBookCategory,
              decoration: const InputDecoration(
                labelText: 'Book Category (Optional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category_outlined),
              ),
              hint: const Text('Select book list or book fund'),
              items:
                  ['Book List', 'Book Fund'].map((String category) {
                    return DropdownMenuItem<String>(
                      value: category,
                      child: Text(category),
                    );
                  }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedBookCategory = value;
                });
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _captureStatusController,
              decoration: const InputDecoration(
                labelText: 'Capture Status',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.verified_outlined),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _onboardSchool,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child:
                  _isLoading
                      ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: Colors.white,
                        ),
                      )
                      : const Text('SUBMIT', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
