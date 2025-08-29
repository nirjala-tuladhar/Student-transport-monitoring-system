import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/bus.dart';
import '../models/driver.dart';
import '../models/student.dart';
import '../models/school.dart';
import 'geocoding_service.dart';

class SchoolService {
  final SupabaseClient _supabase = Supabase.instance.client;
  // Parent web app origin used for password set/reset redirects
  // TODO: externalize via config if environments vary
  static const String kParentAppOrigin = 'http://localhost:3000';

  // Create a new school (Superadmin only)
  Future<Map<String, dynamic>> createSchool(String name) async {
    try {
      final response = await _adminSupabase
          .from('schools')
          .insert({'name': name}).select('id').single();
      return response;
    } catch (e) {
      throw Exception('Failed to create school: $e');
    }

  // Resend parent invite helper
  Future<void> resendParentInvite(String email) async {
    try {
      await _adminSupabase.auth.admin.inviteUserByEmail(
        email,
        redirectTo: kParentAppOrigin,
      );
    } catch (e) {
      throw Exception('Failed to resend invite: $e');
    }
  }
  }

  // Admin client for privileged operations
  final SupabaseClient _adminSupabase = SupabaseClient(
    'https://nnjjefycskerdjqmatkf.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5uamplZnljc2tlcmRqcW1hdGtmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1MjYyNTQ3NiwiZXhwIjoyMDY4MjAxNDc2fQ.nGXxDihQI6LDVWi8M8rnYAcmHXaIZF2DvSfSITGMBmw',
  );

  // Get the current school for the logged-in admin
  Future<School?> getSchool() async {
    final schoolId = await _getUserSchoolId();
    if (schoolId == null) return null;

    final response = await _supabase
        .from('schools')
        .select()
        .eq('id', schoolId)
        .limit(1)
        .maybeSingle();
    if (response == null) return null;
    return School.fromMap(response);
  }

  // Helper to get the current user's school_id
  Future<String?> _getUserSchoolId() async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final response = await _supabase
        .from('school_admins')
        .select('school_id')
        .eq('user_id', user.id)
        .limit(1)
        .maybeSingle();

    if (response == null) return null;
    return response['school_id'] as String?;
  }

  // Fetch all buses with their assigned driver and students
  Future<List<Map<String, dynamic>>> getBusesWithDetails() async {
    final schoolId = await _getUserSchoolId();
    if (schoolId == null) return [];

    final response = await _supabase
        .from('buses')
        .select('*, driver:drivers(*), students:students(*)')
        .eq('school_id', schoolId);

    return List<Map<String, dynamic>>.from(response);
  }

  // Unassign a student from a bus
  Future<void> unassignStudent(String studentId) async {
    final updated = await _supabase
        .from('students')
        .update({'bus_id': null})
        .eq('id', studentId)
        .select('id')
        .maybeSingle();
    if (updated == null) {
      throw Exception('Failed to unassign student (no permission or not found).');
    }
  }

  // Assign a student to a bus
  Future<void> assignStudentToBus(String studentId, String busId) async {
    final updated = await _supabase
        .from('students')
        .update({'bus_id': busId})
        .eq('id', studentId)
        .select('id, bus_id')
        .maybeSingle();
    if (updated == null) {
      throw Exception('Failed to assign student (no permission or not found).');
    }
  }

  // Assign a driver to a bus
  Future<void> assignDriverToBus(String driverId, String busId) async {
    // First, ensure the driver is not assigned to any other bus if that's a rule.
    // For now, we'll just update the bus's driver_id.
    await _supabase.from('buses').update({'driver_id': driverId}).eq('id', busId);
  }

  // Fetch all unassigned students for the current admin's school
  Future<List<Student>> getUnassignedStudents() async {
    final schoolId = await _getUserSchoolId();
    if (schoolId == null) return [];

    final response = await _supabase
        .from('students')
        .select('*')
        .eq('school_id', schoolId)
        .filter('bus_id', 'is', null);

    return (response as List).map((e) => Student.fromMap(e)).toList();
  }

  // Fetch all unassigned drivers for the current admin's school
  Future<List<Driver>> getUnassignedDrivers() async {
    final schoolId = await _getUserSchoolId();
    if (schoolId == null) return [];

    // Fetch all drivers from the school with their bus assignments.
    final response = await _supabase
        .from('drivers')
        .select('*, buses(driver_id)')
        .eq('school_id', schoolId);

    // Filter drivers in Dart to find those with no bus assignments.
    final unassignedDrivers = (response as List)
        .map((e) => Driver.fromMap(e))
        .where((driver) {
          // The 'buses' key will be present from the select query.
          // If the list is empty, the driver is not assigned to any bus.
          final buses = driver.extraData['buses'] as List? ?? [];
          return buses.isEmpty;
        })
        .toList();

    return unassignedDrivers;
  }

  // Unassign a driver from a bus
  Future<void> unassignDriver(String busId) async {
    await _supabase.from('buses').update({'driver_id': null}).eq('id', busId);
  }

  // Fetch all buses for the current admin's school
  Future<List<Bus>> getBuses() async {
    final schoolId = await _getUserSchoolId();
    if (schoolId == null) return [];

    final response = await _supabase
        .from('buses')
        .select('*')
        .eq('school_id', schoolId);

    return (response as List).map((bus) => Bus.fromMap(bus)).toList();
  }

  // Fetch all drivers for the current admin's school
  Future<List<Driver>> getDrivers() async {
    final schoolId = await _getUserSchoolId();
    if (schoolId == null) return [];

    final response = await _supabase
        .from('drivers')
        .select('*')
        .eq('school_id', schoolId);

    return (response as List).map((driver) => Driver.fromMap(driver)).toList();
  }

  // Fetch all students for the current admin's school
  Future<List<Student>> getStudents() async {
    final schoolId = await _getUserSchoolId();
    if (schoolId == null) return [];

    final response = await _supabase
        .from('students')
        .select('*')
        .eq('school_id', schoolId);

    return (response as List).map((student) => Student.fromMap(student)).toList();
  }

  // Create a new driver
  Future<void> createDriver({required String name}) async {
    final schoolId = await _getUserSchoolId();
    if (schoolId == null) throw Exception('Could not determine school');

    await _supabase.from('drivers').insert({'name': name, 'school_id': schoolId});
  }

  // Create a new bus and provision a login account for the bus panel
  // Uses a synthetic email derived from username to keep usernames unique
  Future<void> createBus(String plateNumber, int capacity, {
    required String username,
    required String password,
  }) async {
    final schoolId = await _getUserSchoolId();
    if (schoolId == null) {
      throw Exception('User is not associated with a school.');
    }
    try {
      final uname = username.trim().toLowerCase();
      if (uname.isEmpty) throw Exception('Username required');
      // Simple allowlist validation (must mirror UI)
      final re = RegExp(r'^[a-z0-9_]+$');
      if (!re.hasMatch(uname)) throw Exception('Invalid username');
      final syntheticEmail = '$uname@bus.local';
      // 1) Create Auth user for bus (service role)
      final created = await _adminSupabase.auth.admin.createUser(
        AdminUserAttributes(
          email: syntheticEmail,
          password: password,
          emailConfirm: true,
          userMetadata: {
            'role': 'bus',
            'username': uname,
          },
        ),
      );
      final busUser = created.user;
      if (busUser == null) {
        throw Exception('Failed to create bus user');
      }

      // 2) Insert bus row with linked user_id
      await _supabase.from('buses').insert({
        'plate_number': plateNumber,
        'capacity': capacity,
        'school_id': schoolId,
        'user_id': busUser.id,
      });
    } catch (e) {
      throw Exception('Failed to create bus: $e');
    }
  }

  // Create a new student with OTP-based parent invitations
  Future<void> createStudent({
    required String name,
    required String busStop,
    required String parent1Email,
    String? parent2Email,
  }) async {
    final schoolId = await _getUserSchoolId();
    if (schoolId == null) throw Exception('Could not determine school');

    // Geocode bus stop (best-effort)
    double? stopLat;
    double? stopLng;
    try {
      final geo = await GeocodingService().geocodeAddress(busStop);
      if (geo != null) {
        stopLat = geo.lat;
        stopLng = geo.lon;
      }
    } catch (_) {}

    // Create the student and fetch its id
    final student = await _supabase
        .from('students')
        .insert({
          'name': name,
          'school_id': schoolId,
          'bus_stop': busStop,
          'bus_stop_lat': stopLat,
          'bus_stop_lng': stopLng,
          'parent1_email': parent1Email,
          'parent2_email': parent2Email,
        })
        .select('id')
        .single();

    final studentId = student['id'] as String;

    // Helper to provision a parent with an OTP
    Future<void> _provisionParent(String email, String relation) async {
      try {
        // 1. Generate a random 6-digit OTP
        final otp = (100000 + (DateTime.now().millisecond % 900000)).toString();

        // 2. Create the user with the OTP as the initial password
        final createdUser = await _adminSupabase.auth.admin.createUser(AdminUserAttributes(
          email: email,
          password: otp,
          emailConfirm: true, // Auto-confirm email
          userMetadata: {
            'role': 'parent',
            'relation': relation,
            'school_id': schoolId,
          },
        ));

        final user = createdUser.user;
        if (user == null) {
          throw Exception('Failed to create parent user in Supabase Auth.');
        }

        // 3. Store the OTP in the database for verification (using admin client)
        await _adminSupabase.from('parent_otps').insert({
          'user_id': user.id,
          'otp_code': otp, // In a real app, this should be hashed.
          'expires_at': DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
        });

        // 4. Link in the public parents table (using admin client)
        await _adminSupabase.from('parents').insert({
          'user_id': user.id,
          'student_id': studentId,
          'relation': relation,
        });

        // 5. Trigger the custom OTP email via Supabase Edge Function
        await _supabase.functions.invoke('send-otp', body: {
          'email': email,
          'otp': otp,
        });

      } catch (e) {
        // Basic error handling for existing users
        // Catching specific auth error for existing user
        if (e.toString().contains('User already registered')) {
            // You could add logic here to handle existing parents if needed.
            return;
        }
        throw Exception('Failed to provision parent: $e');
      }
    }

    await _provisionParent(parent1Email, 'parent1');
    if (parent2Email != null && parent2Email.isNotEmpty) {
      await _provisionParent(parent2Email, 'parent2');
    }
  }

  // Update school profile
  Future<void> updateSchoolProfile({
    required String id,
    required String name,
    required String address,
  }) async {
    // Best-effort geocoding
    double? lat;
    double? lon;
    try {
      // Use combined query for better accuracy: "name, City, Country"
      final query = [name, address].where((e) => e.trim().isNotEmpty).join(', ');
      final geo = await GeocodingService().geocodeAddress(query);
      if (geo != null) {
        lat = geo.lat;
        lon = geo.lon;
      }
    } catch (_) {}

    await _supabase.from('schools').update({
      'name': name,
      'address': address,
      'latitude': lat,
      'longitude': lon,
    }).eq('id', id);
  }

  // Mark first login as complete for the current school admin
  Future<void> markFirstLoginComplete() async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    await _supabase
        .from('school_admins')
        .update({'is_first_login': false}).eq('user_id', user.id);
  }

  // Get latest bus location per bus for the current school (no relational join)
  Future<List<Map<String, dynamic>>> getLatestBusLocations() async {
    final schoolId = await _getUserSchoolId();
    if (schoolId == null) return [];

    // Step 1: Fetch buses for this school that the user can access
    final buses = await _supabase
        .from('buses')
        .select('id, plate_number')
        .eq('school_id', schoolId);

    if (buses.isEmpty) return [];

    final busIds = <String>[];
    final plateById = <String, String>{};
    for (final b in buses) {
      final id = b['id'] as String?;
      if (id != null) {
        busIds.add(id);
        final plate = (b['plate_number'] as String?) ?? 'Bus';
        plateById[id] = plate;
      }
    }
    if (busIds.isEmpty) return [];

    // Step 2: Fetch locations for these buses ordered by latest first
    final locs = await _supabase
        .from('bus_locations')
        .select('bus_id, latitude, longitude, timestamp')
        .inFilter('bus_id', busIds)
        .order('timestamp', ascending: false);

    // Step 3: Deduplicate by bus_id keeping most recent
    final seen = <String>{};
    final latest = <Map<String, dynamic>>[];
    for (final row in (locs as List)) {
      final busId = row['bus_id'] as String?;
      if (busId == null) continue;
      if (seen.add(busId)) {
        latest.add({
          'bus_id': busId,
          'latitude': row['latitude'],
          'longitude': row['longitude'],
          'timestamp': row['timestamp'],
          'plate_number': plateById[busId] ?? 'Bus',
        });
      }
    }
    return latest;
  }
}
