import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;

import '../../core/constants/colors.dart';
import '../../core/config/google_maps_config.dart';
import '../database/database_service.dart';
import '../../models/farmer_model.dart';
import 'agrovet_onboarding.dart';
import 'school_action_menu_page.dart';

class MyShopsPage extends StatefulWidget {
  const MyShopsPage({super.key});

  @override
  State<MyShopsPage> createState() => _MyShopsPageState();
}

class _MyShopsPageState extends State<MyShopsPage> {
  final DatabaseService _dbService = DatabaseService();
  final TextEditingController _searchController = TextEditingController();
  static const double _nearbyRadiusKm = 100;

  late Future<List<SchoolModel>> _schoolsFuture;
  String _searchQuery = '';
  Position? _currentPosition;
  bool _isLocating = false;
  String? _locationError;
  bool _isSearchingGoogle = false;
  List<SchoolModel> _googleNearbySchools = <SchoolModel>[];

  @override
  void initState() {
    super.initState();
    _schoolsFuture = _dbService.getAllSchools();
    _loadCurrentLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshSchools() async {
    setState(() {
      _schoolsFuture = _dbService.getAllSchools();
    });
    await _loadCurrentLocation();
  }

  Future<void> _loadCurrentLocation() async {
    if (_isLocating) return;
    setState(() {
      _isLocating = true;
      _locationError = null;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _locationError = 'Enable location services to see nearby schools.';
          _isLocating = false;
        });
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() {
          _locationError =
              'Location permission is required to show nearby schools.';
          _isLocating = false;
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (!mounted) return;
      setState(() {
        _currentPosition = position;
        _isLocating = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _locationError = 'Could not get your location. Please try again.';
        _isLocating = false;
      });
    }
  }

  List<SchoolModel> _filterSchools(List<SchoolModel> schools) {
    final userLat = _currentPosition?.latitude;
    final userLng = _currentPosition?.longitude;
    final nearbySchools =
        (userLat == null || userLng == null)
            ? <SchoolModel>[]
            : schools.where((school) {
              final lat = school.latitude;
              final lng = school.longitude;
              if (lat == null || lng == null) return false;
              final distanceMeters = Geolocator.distanceBetween(
                userLat,
                userLng,
                lat,
                lng,
              );
              return distanceMeters <= _nearbyRadiusKm * 1000;
            }).toList();

    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return nearbySchools;
    return nearbySchools.where((school) {
      return school.name.toLowerCase().contains(q) ||
          school.county.toLowerCase().contains(q) ||
          (school.bookCategory ?? '').toLowerCase().contains(q) ||
          school.focusAreas.any((area) => area.toLowerCase().contains(q));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F7),
      appBar: AppBar(
        title: Text('My Schools (${_nearbyRadiusKm.toInt()}km)'),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
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
          final combinedSchools = <SchoolModel>[
            ...(snapshot.data ?? const <SchoolModel>[]),
            ..._googleNearbySchools,
          ];
          final schools = _filterSchools(combinedSchools);

          return RefreshIndicator(
            onRefresh: _refreshSchools,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                _buildSearchBar(),
                _buildNearbySearchActions(),
                const SizedBox(height: 12),
                if (_isLocating)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_locationError != null)
                  _buildLocationErrorCard()
                else if (snapshot.connectionState == ConnectionState.waiting)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (snapshot.hasError)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Failed to load schools: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  )
                else if (schools.isEmpty)
                  _buildNoNearbySchoolsCard()
                else
                  ...schools.map(_buildSchoolCard),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primaryGreen,
        child: const Icon(Icons.add_business, color: Colors.white),
        onPressed: _openOnboarding,
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.primaryGreen,
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _searchQuery = value),
        decoration: InputDecoration(
          hintText: 'Search by school, county, or book category...',
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildNearbySearchActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _isSearchingGoogle ? null : _searchSchoolsAroundMeFromGoogle,
              icon: const Icon(Icons.travel_explore),
              label: Text(
                _isSearchingGoogle
                    ? 'Searching nearby schools...'
                    : 'Search Schools Around Me',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSchoolCard(SchoolModel school) {
    final nextAction = _deriveAction(school);
    final focusAreas = school.focusAreas;
    final canVisit = _canVisitSchool(school);
    final hasRemotePhoto = school.photoUrl != null && school.photoUrl!.isNotEmpty;
    final hasLocalPhotoPath = school.photoPath != null && school.photoPath!.isNotEmpty;
    final hasPhoto = hasRemotePhoto || hasLocalPhotoPath;
    final schoolPayload = {
      'id': school.id,
      'name': school.name,
      'phone': school.phone,
      'county': school.county,
      'focusAreas': school.focusAreas,
      'book_category': school.bookCategory,
      'latitude': school.latitude,
      'longitude': school.longitude,
      'photo_url': school.photoUrl,
      'photo_path': school.photoPath,
      'captured_by': school.capturedBy,
      'captured_at': school.capturedAt?.toIso8601String(),
      'capture_status': school.captureStatus,
      'isSynced': school.isSynced,
      'created_at': school.createdAt?.toIso8601String(),
      'updated_at': school.updatedAt?.toIso8601String(),
      'nextAction': nextAction,
    };

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SchoolActionMenuPage(
                school: schoolPayload,
              ),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasPhoto)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                child: AspectRatio(
                  aspectRatio: 16 / 7,
                  child: _buildSchoolImage(
                    photoUrl: school.photoUrl,
                    photoPath: school.photoPath,
                  ),
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withOpacity(0.06),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(15),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.primaryGreen.withOpacity(0.1),
                      child: const Icon(Icons.school_outlined, color: AppColors.primaryGreen),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        school.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (hasPhoto)
                        Expanded(
                          child: Text(
                            school.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      if (!hasPhoto)
                        const Spacer(),
                      if (!school.id.startsWith('google_'))
                        PopupMenuButton<String>(
                          tooltip: 'School actions',
                          onSelected: (value) {
                            if (value == 'edit') {
                              _showEditSchoolDialog(school);
                              return;
                            }
                            if (value == 'delete') {
                              _confirmDeleteSchool(school);
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem<String>(
                              value: 'edit',
                              child: Text('Edit'),
                            ),
                            PopupMenuItem<String>(
                              value: 'delete',
                              child: Text('Delete'),
                            ),
                          ],
                        ),
                    ],
                  ),
                  if (!hasPhoto)
                    Text(
                      school.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    '${school.county} • ${school.phone}',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _chip('Book', school.bookCategory ?? 'None'),
                      _chip('Sync', school.isSynced ? 'Synced' : 'Pending'),
                      _chip(
                        'Capture',
                        school.captureStatus ?? 'Not captured',
                      ),
                      _chip('Next', nextAction),
                    ],
                  ),
                  if (focusAreas.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Focus areas',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: focusAreas
                          .take(3)
                          .map((area) => _chip('Area', area))
                          .toList(),
                    ),
                  ],
                  if (school.latitude != null && school.longitude != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Location: ${school.latitude!.toStringAsFixed(4)}, ${school.longitude!.toStringAsFixed(4)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            if (canVisit) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => SchoolActionMenuPage(
                                        school: schoolPayload,
                                      ),
                                ),
                              );
                              return;
                            }
                            _openOnboarding();
                          },
                          icon: Icon(
                            canVisit
                                ? Icons.directions_walk
                                : Icons.add_business,
                          ),
                          label: Text(canVisit ? 'Visit' : 'Onboard'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _openDirections(school),
                          icon: const Icon(Icons.map_outlined),
                          label: const Text('Directions'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSchoolImage({String? photoUrl, String? photoPath}) {
    final hasRemotePhoto = photoUrl != null && photoUrl.isNotEmpty;
    if (hasRemotePhoto) {
      return Image.network(
        photoUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          return _buildImageFallback();
        },
      );
    }

    if (!kIsWeb && photoPath != null && photoPath.isNotEmpty) {
      return Image.file(
        File(photoPath),
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          return _buildImageFallback();
        },
      );
    }

    return _buildImageFallback();
  }

  Widget _buildImageFallback() {
    return Container(
      color: AppColors.primaryGreen.withOpacity(0.08),
      alignment: Alignment.center,
      child: const Icon(
        Icons.school_outlined,
        color: AppColors.primaryGreen,
        size: 40,
      ),
    );
  }

  String _deriveAction(SchoolModel school) {
    if ((school.bookCategory ?? '').toLowerCase() == 'book fund') {
      return 'Sell';
    }
    if (school.focusAreas.isNotEmpty) {
      return 'Follow Up';
    }
    return 'Visit';
  }

  Widget _chip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildLocationErrorCard() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _locationError ?? 'Location unavailable.',
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: _loadCurrentLocation,
                    child: const Text('Retry Location'),
                  ),
                  const SizedBox(width: 10),
                  TextButton(
                    onPressed: _openOnboarding,
                    child: const Text('Onboard School'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoNearbySchoolsCard() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Icon(Icons.location_off_outlined, size: 34),
              const SizedBox(height: 10),
              const Text(
                'No schools found around your area.',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                'Onboard a school near you to get started.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _openOnboarding,
                icon: const Icon(Icons.add_business),
                label: const Text('Onboard School'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openOnboarding() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SchoolOnboarding()),
    ).then((_) => _refreshSchools());
  }

  bool _canVisitSchool(SchoolModel school) {
    return !school.id.startsWith('google_') &&
        school.id.trim().isNotEmpty &&
        school.name.trim().isNotEmpty &&
        school.phone.trim().isNotEmpty &&
        school.county.trim().isNotEmpty;
  }

  Future<void> _openDirections(SchoolModel school) async {
    if (school.latitude == null || school.longitude == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This school has no saved coordinates yet.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final originLat = _currentPosition?.latitude;
    final originLng = _currentPosition?.longitude;
    final destination = '${school.latitude},${school.longitude}';

    final uri =
        (originLat != null && originLng != null)
            ? Uri.parse(
              'https://www.google.com/maps/dir/?api=1&origin=$originLat,$originLng&destination=$destination&travelmode=driving',
            )
            : Uri.parse(
              'https://www.google.com/maps/dir/?api=1&destination=$destination&travelmode=driving',
            );

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open maps application.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _searchSchoolsAroundMeFromGoogle() async {
    if (!GoogleMapsConfig.isConfigured) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Google Maps API key missing. Add --dart-define=GOOGLE_MAPS_API_KEY=your_key',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final originLat = _currentPosition?.latitude;
    final originLng = _currentPosition?.longitude;
    if (originLat == null || originLng == null) {
      await _loadCurrentLocation();
    }

    final lat = _currentPosition?.latitude;
    final lng = _currentPosition?.longitude;
    if (lat == null || lng == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location is required to search schools around you.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSearchingGoogle = true);
    try {
      final radiusMeters = (_nearbyRadiusKm * 1000).round();
      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
        '?location=$lat,$lng&radius=$radiusMeters&keyword=school&key=${GoogleMapsConfig.apiKey}',
      );
      final response = await http.get(uri);
      if (response.statusCode != 200) {
        throw Exception('Google Places request failed (${response.statusCode}).');
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final status = body['status']?.toString() ?? '';
      if (status != 'OK' && status != 'ZERO_RESULTS') {
        throw Exception(body['error_message']?.toString() ?? 'Places API status: $status');
      }

      final results = (body['results'] as List<dynamic>? ?? const <dynamic>[]);
      final mapped = results.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        final placeId = map['place_id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString();
        final name = map['name']?.toString() ?? 'School';
        final vicinity = map['vicinity']?.toString() ?? '';
        final county = _deriveCountyFromVicinity(vicinity);
        final geometry = Map<String, dynamic>.from(map['geometry'] as Map? ?? const {});
        final location = Map<String, dynamic>.from(geometry['location'] as Map? ?? const {});
        final schoolLat = (location['lat'] as num?)?.toDouble();
        final schoolLng = (location['lng'] as num?)?.toDouble();

        return SchoolModel(
          id: 'google_$placeId',
          name: name,
          phone: 'Not captured',
          county: county,
          focusAreas: const ['Discovered from Google Maps'],
          latitude: schoolLat,
          longitude: schoolLng,
          captureStatus: 'Not onboarded',
          schoolOwnership: null,
          schoolOwnershipOther: null,
          schoolPopulation: null,
          schoolLifecycleStatus: null,
          isSynced: false,
        );
      }).toList();

      final existingNames =
          (await _schoolsFuture)
              .map((s) => s.name.trim().toLowerCase())
              .toSet();
      final filteredGoogle =
          mapped
              .where((s) => !existingNames.contains(s.name.trim().toLowerCase()))
              .toList();

      if (!mounted) return;
      setState(() {
        _googleNearbySchools = filteredGoogle;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            filteredGoogle.isEmpty
                ? 'No new nearby schools found from Google.'
                : 'Found ${filteredGoogle.length} nearby schools from Google.',
          ),
          backgroundColor: AppColors.primaryGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not fetch nearby schools: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSearchingGoogle = false);
      }
    }
  }

  String _deriveCountyFromVicinity(String vicinity) {
    if (vicinity.trim().isEmpty) return 'Unknown';
    final parts =
        vicinity
            .split(',')
            .map((p) => p.trim())
            .where((p) => p.isNotEmpty)
            .toList();
    if (parts.isEmpty) return 'Unknown';
    return parts.length == 1 ? parts.first : parts.last;
  }

  Future<void> _showEditSchoolDialog(SchoolModel school) async {
    final nameController = TextEditingController(text: school.name);
    final phoneController = TextEditingController(text: school.phone);
    final countyController = TextEditingController(text: school.county);

    final updated = await showDialog<SchoolModel>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit School'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'School Name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(labelText: 'Phone'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: countyController,
                  decoration: const InputDecoration(labelText: 'County'),
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
                final name = nameController.text.trim();
                final phone = phoneController.text.trim();
                final county = countyController.text.trim();
                if (name.isEmpty || phone.isEmpty || county.isEmpty) return;
                Navigator.pop(
                  context,
                  SchoolModel(
                    id: school.id,
                    name: name,
                    phone: phone,
                    county: county,
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
                    sampleBook: school.sampleBook,
                    schoolOwnership: school.schoolOwnership,
                    schoolOwnershipOther: school.schoolOwnershipOther,
                    schoolPopulation: school.schoolPopulation,
                    schoolLifecycleStatus: school.schoolLifecycleStatus,
                    isSynced: false,
                    createdAt: school.createdAt,
                    updatedAt: DateTime.now(),
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (updated == null) return;
    await _dbService.updateSchoolProfile(updated);
    await _refreshSchools();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('School updated successfully.'),
        backgroundColor: AppColors.primaryGreen,
      ),
    );
  }

  Future<void> _confirmDeleteSchool(SchoolModel school) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete School'),
          content: Text('Delete "${school.name}" from your schools list?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;
    await _dbService.deleteSchoolProfile(school.id);
    await _refreshSchools();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('School deleted.'),
        backgroundColor: AppColors.primaryGreen,
      ),
    );
  }

}
