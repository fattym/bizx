import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/colors.dart';
import '../../core/config/google_maps_config.dart';
import '../../features/database/database_service.dart';
import '../../models/farmer_model.dart';

class ContactsPage extends StatefulWidget {
  const ContactsPage({super.key});

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  final DatabaseService _dbService = DatabaseService();
  final TextEditingController _searchController = TextEditingController();
  late Future<List<SchoolModel>> _contactsFuture;
  Position? _currentPosition;
  bool _isLocating = false;
  String? _locationError;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _contactsFuture = _dbService.getMySchools();
    _loadCurrentLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshContacts() async {
    setState(() {
      _contactsFuture = _dbService.getMySchools();
    });
    await _loadCurrentLocation();
  }

  Future<void> _loadCurrentLocation() async {
    if (_isLocating) return;
    if (!GoogleMapsConfig.isConfigured) return;
    setState(() {
      _isLocating = true;
      _locationError = null;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _locationError = 'Enable location services to see distances.';
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
          _locationError = 'Location permission is required to show distances.';
          _isLocating = false;
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
        _isLocating = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _locationError = 'Could not get your location.';
        _isLocating = false;
      });
    }
  }

  List<SchoolModel> _filterContacts(List<SchoolModel> contacts) {
    final userLat = _currentPosition?.latitude;
    final userLng = _currentPosition?.longitude;

    final withDistance =
        userLat == null || userLng == null
            ? contacts
                .map((c) => _ContactWithDistance(contact: c, distanceKm: null))
                .toList()
            : contacts.map((c) {
              final lat = c.latitude;
              final lng = c.longitude;
              if (lat == null || lng == null) {
                return _ContactWithDistance(contact: c, distanceKm: null);
              }
              final distanceMeters = Geolocator.distanceBetween(
                userLat,
                userLng,
                lat,
                lng,
              );
              return _ContactWithDistance(
                contact: c,
                distanceKm: distanceMeters / 1000,
              );
            }).toList();

    withDistance.sort((a, b) {
      if (a.distanceKm == null && b.distanceKm == null) return 0;
      if (a.distanceKm == null) return 1;
      if (b.distanceKm == null) return -1;
      return a.distanceKm!.compareTo(b.distanceKm!);
    });

    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) {
      return withDistance.map((e) => e.contact).toList();
    }

    final filtered =
        withDistance.where((e) {
          final c = e.contact;
          return c.name.toLowerCase().contains(q) ||
              c.phone.toLowerCase().contains(q) ||
              c.county.toLowerCase().contains(q) ||
              (c.contactName ?? '').toLowerCase().contains(q) ||
              (c.contactPhone ?? '').toLowerCase().contains(q) ||
              (c.dealerType ?? '').toLowerCase().contains(q);
        }).toList();

    return filtered.map((e) => e.contact).toList();
  }

  Color _dealerTypeColor(String? dealerType) {
    final type = (dealerType ?? '').toLowerCase();
    if (type == 'bookshop') return AppColors.accentOrange;
    if (type == 'institution') return AppColors.infoBlue;
    return AppColors.primaryGreen;
  }

  Future<void> _makePhoneCall(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    final launched = await launchUrl(uri);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open the phone dialer.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String? _normalizePhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digits.isEmpty) return null;
    if (digits.startsWith('+')) {
      return digits.substring(1);
    }
    if (digits.startsWith('0')) {
      return '254${digits.substring(1)}';
    }
    if (digits.startsWith('254')) {
      return digits;
    }
    return digits;
  }

  Future<void> _openWhatsApp(SchoolModel contact) async {
    final phone = _normalizePhone(contact.phone);
    if (phone == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No valid phone number found for WhatsApp.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final schoolName = contact.name;
    final message =
        'Hello $schoolName, I am reaching out from Longhorn. '
        'Could we discuss how we can support your institution? '
        'Looking forward to hearing from you.';
    final encodedMessage = Uri.encodeComponent(message);

    final deepLink = Uri.parse(
      'whatsapp://send?phone=$phone&text=$encodedMessage',
    );
    final webFallback = Uri.parse('https://wa.me/$phone?text=$encodedMessage');

    final openedDeepLink = await launchUrl(
      deepLink,
      mode: LaunchMode.externalApplication,
    );
    if (openedDeepLink) return;

    final openedWeb = await launchUrl(
      webFallback,
      mode: LaunchMode.externalApplication,
    );
    if (!openedWeb && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open WhatsApp.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F7),
      appBar: AppBar(
        title: const Text('Contacts'),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshContacts,
          ),
        ],
      ),
      body: FutureBuilder<List<SchoolModel>>(
        future: _contactsFuture,
        builder: (context, snapshot) {
          final contacts = _filterContacts(
            snapshot.data ?? const <SchoolModel>[],
          );

          return RefreshIndicator(
            onRefresh: _refreshContacts,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _searchQuery = value),
                    decoration: InputDecoration(
                      hintText: 'Search by name, phone, or type...',
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                if (_isLocating)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_locationError != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _locationError!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  )
                else if (snapshot.connectionState == ConnectionState.waiting)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (snapshot.hasError)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Failed to load contacts: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  )
                else if (contacts.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.contacts_outlined,
                            size: 48,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No contacts found.',
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...contacts.map(_buildContactTile),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildContactTile(SchoolModel contact) {
    final dealerType =
        (contact.dealerType ?? '').trim().isNotEmpty
            ? contact.dealerType!.trim()
            : 'School';
    final typeColor = _dealerTypeColor(contact.dealerType);
    final primaryPhone = contact.phone.trim();
    final contactName =
        contact.contactName?.trim().isNotEmpty ?? false
            ? contact.contactName!.trim()
            : null;
    final contactPhone =
        contact.contactPhone?.trim().isNotEmpty ?? false
            ? contact.contactPhone!.trim()
            : null;
    final hasSecondaryPhone =
        contactPhone != null && contactPhone != primaryPhone;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _makePhoneCall(primaryPhone),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: typeColor.withValues(alpha: 0.1),
                child: Icon(
                  dealerType.toLowerCase() == 'bookshop'
                      ? Icons.storefront_outlined
                      : dealerType.toLowerCase() == 'institution'
                      ? Icons.account_balance_outlined
                      : Icons.school_outlined,
                  color: typeColor,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            contact.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: typeColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            dealerType,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: typeColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () => _makePhoneCall(primaryPhone),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.phone_rounded,
                            size: 16,
                            color: AppColors.primaryDark,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              primaryPhone,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (contactName != null && contactName.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Contact: $contactName',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                    if (hasSecondaryPhone) ...[
                      const SizedBox(height: 2),
                      InkWell(
                        onTap: () => _makePhoneCall(contactPhone),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.phone_rounded,
                              size: 14,
                              color: AppColors.textMuted,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                contactPhone,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (contact.county.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          contact.county,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Row(
                children: [
                  IconButton(
                    tooltip: 'WhatsApp',
                    onPressed: () => _openWhatsApp(contact),
                    icon: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF25D369).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.chat_bubble_outline_rounded,
                        color: Color(0xFF25D369),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Call',
                    onPressed: () => _makePhoneCall(primaryPhone),
                    icon: Container(
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.call_rounded,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContactWithDistance {
  final SchoolModel contact;
  final double? distanceKm;

  _ContactWithDistance({required this.contact, this.distanceKm});
}
