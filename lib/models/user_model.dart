import 'package:uuid/uuid.dart';

class UserModel {
  final String id;
  final String email;
  final String? fullName;
  final String? phone;
  final String? regionId;
  final String? region;
  final String? subRegion;
  final int
  role; // 1 = admin, 2 = sales manager, 3 = BAS, 4 = agent, 5 = grounds person
  final bool isSynced; // For local/remote sync status

  UserModel({
    String? id,
    required this.email,
    this.fullName,
    this.phone,
    this.regionId,
    this.region,
    this.subRegion,
    this.role = 5, // Default role is lowest tier
    this.isSynced = false,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toMap() {
    final map = {
      'id': id,
      'email': email,
      'full_name': fullName,
      'phone': phone,
      'role': role,
      'isSynced': isSynced,
    };

    if (regionId != null) {
      map['region_id'] = regionId;
    }

    if (region != null) {
      map['region'] = region;
    }

    if (subRegion != null) {
      map['sub_region'] = subRegion;
    }

    return map;
  }

  factory UserModel.fromMap(Map<dynamic, dynamic> map) {
    return UserModel(
      id: map['id'],
      email: map['email'],
      fullName: map['full_name'],
      phone: map['phone'],
      regionId: map['region_id']?.toString(),
      region: map['region'],
      subRegion: map['sub_region'],
      role: _parseRole(map['role']),
      isSynced: map['isSynced'] ?? false,
    );
  }

  static int _parseRole(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;
      final lower = value.toLowerCase();
      if (lower == 'admin' || lower == 'superadmin') return 1;
      if (lower == 'sales manager') return 2;
      if (lower == 'bas') return 3;
      if (lower == 'agent' || lower == 'field agent') return 4;
      if (lower == 'grounds person') return 5;
    }
    return 5; // Default to lowest tier
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? fullName,
    String? phone,
    String? regionId,
    String? region,
    String? subRegion,
    int? role,
    bool? isSynced,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      regionId: regionId ?? this.regionId,
      region: region ?? this.region,
      subRegion: subRegion ?? this.subRegion,
      role: role ?? this.role,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}
