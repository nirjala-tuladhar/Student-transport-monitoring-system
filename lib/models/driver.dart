class Driver {
  final String id;
  final String schoolId;
  final String name;
  final Map<String, dynamic> extraData;

  Driver({
    required this.id,
    required this.schoolId,
    required this.name,
    this.extraData = const {},
  });

  factory Driver.fromMap(Map<String, dynamic> map) {
    return Driver(
      id: map['id'],
      schoolId: map['school_id'],
      name: map['name'],
      extraData: map, // Store the full map to access related data like buses
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'school_id': schoolId,
      'name': name,
    };
  }
}
