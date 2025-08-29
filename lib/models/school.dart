class School {
  final String id;
  final String name;
  final DateTime createdAt;
  final String? email; // contact email (nullable)
  final String? address;
  final double? latitude;
  final double? longitude;

  School({
    required this.id,
    required this.name,
    required this.createdAt,
    this.email,
    this.address,
    this.latitude,
    this.longitude,
  });

  factory School.fromMap(Map<String, dynamic> map) {
    return School(
      id: map['id'],
      name: map['name'],
      createdAt: DateTime.parse(map['created_at']),
      email: map['email'],
      address: map['address'],
      latitude: (map['latitude'] is num) ? (map['latitude'] as num).toDouble() : (map['latitude'] is String ? double.tryParse(map['latitude']) : null),
      longitude: (map['longitude'] is num) ? (map['longitude'] as num).toDouble() : (map['longitude'] is String ? double.tryParse(map['longitude']) : null),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'created_at': createdAt.toIso8601String(),
      'email': email,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}
