class RegionModel {
  final String? id;
  final String region;
  final String subRegion;
  final String? counties;
  final String? assignedTo;
  final String? supervisorId;

  RegionModel({
    this.id,
    required this.region,
    required this.subRegion,
    this.counties,
    this.assignedTo,
    this.supervisorId,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'region': region,
      'sub_region': subRegion,
      'counties': counties,
      'assigned_to': assignedTo,
      if (supervisorId != null) 'supervisor_id': supervisorId,
    };
  }

  factory RegionModel.fromMap(Map<String, dynamic> map) {
    return RegionModel(
      id: map['id']?.toString(),
      region: (map['region'] ?? '').toString(),
      subRegion: (map['sub_region'] ?? '').toString(),
      counties: map['counties']?.toString(),
      assignedTo: map['assigned_to']?.toString(),
      supervisorId: map['supervisor_id']?.toString(),
    );
  }

  RegionModel copyWith({
    String? id,
    String? region,
    String? subRegion,
    String? counties,
    String? assignedTo,
    String? supervisorId,
  }) {
    return RegionModel(
      id: id ?? this.id,
      region: region ?? this.region,
      subRegion: subRegion ?? this.subRegion,
      counties: counties ?? this.counties,
      assignedTo: assignedTo ?? this.assignedTo,
      supervisorId: supervisorId ?? this.supervisorId,
    );
  }
}
