class Bus {
  final String id;
  final String schoolId;
  final String plateNumber;
  final String? driverId;
  final String? userId;

  Bus({
    required this.id,
    required this.schoolId,
    required this.plateNumber,
    this.driverId,
    this.userId,
  });

  factory Bus.fromMap(Map<String, dynamic> map) {
    return Bus(
      id: map['id'],
      schoolId: map['school_id'],
      plateNumber: map['plate_number'],
      driverId: map['driver_id'],
      userId: map['user_id'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'school_id': schoolId,
      'plate_number': plateNumber,
      'driver_id': driverId,
      'user_id': userId,
    };
  }
}
