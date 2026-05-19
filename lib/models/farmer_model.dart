import 'package:uuid/uuid.dart';

class SchoolModel {
  final String id;
  final String name;
  final String phone;
  final String county;
  final List<String> focusAreas;
  final String? bookCategory;
  final double? latitude;
  final double? longitude;
  final String? photoUrl;
  final String? photoPath;
  final String? capturedBy;
  final DateTime? capturedAt;
  final String? captureStatus;
  final String? contactName;
  final String? contactPhone;
  final String? contactTitle;
  final String? feedback;
  final String? notes;
  final String? samplesLeft;
  final String? sampleBook;
  final String? schoolOwnership;
  final String? schoolOwnershipOther;
  final int? schoolPopulation;
  final String? schoolLifecycleStatus;
  final String? engagementType;
  final bool isSynced;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  SchoolModel({
    String? id,
    required this.name,
    required this.phone,
    required this.county,
    required this.focusAreas,
    this.bookCategory,
    this.latitude,
    this.longitude,
    this.photoUrl,
    this.photoPath,
    this.capturedBy,
    this.capturedAt,
    this.captureStatus,
    this.contactName,
    this.contactPhone,
    this.contactTitle,
    this.feedback,
    this.notes,
    this.samplesLeft,
    this.sampleBook,
    this.schoolOwnership,
    this.schoolOwnershipOther,
    this.schoolPopulation,
    this.schoolLifecycleStatus,
    this.engagementType,
    this.isSynced = false,
    this.createdAt,
    this.updatedAt,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'county': county,
      'focusAreas': focusAreas,
      'book_category': bookCategory,
      'latitude': latitude,
      'longitude': longitude,
      'photo_url': photoUrl,
      'photo_path': photoPath,
      'captured_by': capturedBy,
      'captured_at': capturedAt?.toIso8601String(),
      'capture_status': captureStatus,
      'contact_name': contactName,
      'contact_phone': contactPhone,
      'contact_title': contactTitle,
      'feedback': feedback,
      'notes': notes,
      'samples_left': samplesLeft,
      'sample_book': sampleBook,
      'school_ownership': schoolOwnership,
      'school_ownership_other': schoolOwnershipOther,
      'school_population': schoolPopulation,
      'school_lifecycle_status': schoolLifecycleStatus,
      'engagement_type': engagementType,
      'isSynced': isSynced,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory SchoolModel.fromMap(Map<dynamic, dynamic> map) {
    return SchoolModel(
      id: map['id'],
      name: map['name'],
      phone: map['phone'],
      county: map['county'],
      focusAreas: List<String>.from(map['focusAreas'] ?? const []),
      bookCategory: map['book_category'] ?? map['bookCategory'],
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      photoUrl: map['photo_url'] ?? map['photoUrl'],
      photoPath: map['photo_path'] ?? map['photoPath'],
      capturedBy: map['captured_by'] ?? map['capturedBy'],
      capturedAt: _parseDate(map['captured_at'] ?? map['capturedAt']),
      captureStatus: map['capture_status'] ?? map['captureStatus'],
      contactName: map['contact_name'] ?? map['contactName'],
      contactPhone: map['contact_phone'] ?? map['contactPhone'],
      contactTitle: map['contact_title'] ?? map['contactTitle'],
      feedback: map['feedback'],
      notes: map['notes'],
      samplesLeft: map['samples_left'] ?? map['samplesLeft'],
      sampleBook: map['sample_book'] ?? map['sampleBook'],
      schoolOwnership: map['school_ownership'] ?? map['schoolOwnership'],
      schoolOwnershipOther:
          map['school_ownership_other'] ?? map['schoolOwnershipOther'],
      schoolPopulation: (map['school_population'] as num?)?.toInt(),
      schoolLifecycleStatus:
          map['school_lifecycle_status'] ?? map['schoolLifecycleStatus'],
      engagementType: map['engagement_type'] ?? map['engagementType'],
      isSynced: map['isSynced'] ?? false,
      createdAt: _parseDate(map['created_at'] ?? map['createdAt']),
      updatedAt: _parseDate(map['updated_at'] ?? map['updatedAt']),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  SchoolModel copyWithSynced(bool value) {
    return SchoolModel(
      id: id,
      name: name,
      phone: phone,
      county: county,
      focusAreas: focusAreas,
      bookCategory: bookCategory,
      latitude: latitude,
      longitude: longitude,
      photoUrl: photoUrl,
      photoPath: photoPath,
      capturedBy: capturedBy,
      capturedAt: capturedAt,
      captureStatus: captureStatus,
      contactName: contactName,
      contactPhone: contactPhone,
      contactTitle: contactTitle,
      feedback: feedback,
      notes: notes,
      samplesLeft: samplesLeft,
      sampleBook: sampleBook,
      schoolOwnership: schoolOwnership,
      schoolOwnershipOther: schoolOwnershipOther,
      schoolPopulation: schoolPopulation,
      schoolLifecycleStatus: schoolLifecycleStatus,
      engagementType: engagementType,
      isSynced: value,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
