import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../supabase_client.dart';
import '../../theme/app_theme.dart';
import '../../widgets/animated_widgets.dart';

class SummaryScreen extends StatefulWidget {
  const SummaryScreen({super.key});

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  List<Map<String, dynamic>> trips = [];
  bool loading = true;
  String filter = 'All'; // 'All', 'Boarded', 'Not Boarded'
  int totalStudents = 0;
  int boardedCount = 0;
  int notBoardedCount = 0;
  
  // Admin client for privileged operations
  final SupabaseClient _adminSupabase = SupabaseClient(
    'https://nnjjefycskerdjqmatkf.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5uamplZnljc2tlcmRqcW1hdGtmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1MjYyNTQ3NiwiZXhwIjoyMDY4MjAxNDc2fQ.nGXxDihQI6LDVWi8M8rnYAcmHXaIZF2DvSfSITGMBmw',
  );

  @override
  void initState() {
    super.initState();
    fetchTripData();
  }

  Future<void> fetchTripData() async {
    setState(() => loading = true);
    try {
      // Get school_id for current admin
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final adminData = await supabase
          .from('school_admins')
          .select('school_id')
          .eq('user_id', userId)
          .single();

      final schoolId = adminData['school_id'];

      // Get all buses for this school
      final busesData = await _adminSupabase
          .from('buses')
          .select('id, plate_number')
          .eq('school_id', schoolId);

      List<Map<String, dynamic>> allTrips = [];
      totalStudents = 0;
      boardedCount = 0;
      notBoardedCount = 0;

      // For each bus, get trip history grouped by date
      for (var bus in busesData) {
        final busId = bus['id'];
        final plateNumber = bus['plate_number'];

        // Get all trips for this bus first
        final tripsData = await _adminSupabase
            .from('bus_trips')
            .select('id')
            .eq('bus_id', busId);
        
        final tripIds = tripsData.map((t) => t['id']).toList();
        
        if (tripIds.isEmpty) {
          continue; // No trips for this bus
        }
        
        // Get all boarding records for these trips
        final boardingData = await _adminSupabase
            .from('student_boarding')
            .select('student_id, timestamp, students(name)')
            .inFilter('trip_id', tripIds)
            .order('timestamp', ascending: false);

        // Group by date
        Map<String, List<Map<String, dynamic>>> tripsByDate = {};
        
        for (var record in boardingData) {
          try {
            final timestamp = DateTime.parse(record['timestamp']);
            final dateKey = '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')}';
            
            if (!tripsByDate.containsKey(dateKey)) {
              tripsByDate[dateKey] = [];
            }
            
            final studentData = record['students'];
            final studentName = studentData is Map ? (studentData['name'] ?? 'Unknown') : 'Unknown';
            
            tripsByDate[dateKey]!.add({
              'student_name': studentName,
              'student_address': '',
              'student_id': record['student_id'],
              'timestamp': timestamp,
              'status': 'Boarded',
            });
          } catch (e) {
            debugPrint('Error processing boarding record: $e');
            continue;
          }
        }

        // Get all students assigned to this bus
        final assignedStudents = await _adminSupabase
            .from('students')
            .select('id, name')
            .eq('bus_id', busId);

        // For each date, find students who didn't board
        // Only include students who were assigned to the bus BEFORE or ON that date
        for (var dateKey in tripsByDate.keys) {
          final boardedStudentIds = tripsByDate[dateKey]!.map((s) => s['student_id']).toSet();
          final tripDate = DateTime.parse(dateKey);
          
          for (var student in assignedStudents) {
            // Only show as "not boarded" if student was assigned before this trip date
            // This prevents newly added students from showing in old trips
            if (!boardedStudentIds.contains(student['id'])) {
              // For now, we'll skip adding "not boarded" for past dates
              // since we don't track when students were assigned
              // Only add if it's today's date
              final today = DateTime.now();
              final isTodayOrFuture = tripDate.year == today.year && 
                                      tripDate.month == today.month && 
                                      tripDate.day >= today.day;
              
              if (isTodayOrFuture) {
                tripsByDate[dateKey]!.add({
                  'student_name': student['name'],
                  'student_address': '',
                  'student_id': student['id'],
                  'timestamp': DateTime.parse(dateKey),
                  'status': 'Not Boarded',
                });
              }
            }
          }
        }

        // Create trip entries
        for (var entry in tripsByDate.entries) {
          final boarded = entry.value.where((s) => s['status'] == 'Boarded').toList();
          final notBoarded = entry.value.where((s) => s['status'] == 'Not Boarded').toList();
          
          allTrips.add({
            'bus_plate': plateNumber,
            'date': entry.key,
            'boarded': boarded,
            'not_boarded': notBoarded,
            'total': entry.value.length,
          });
          
          totalStudents += entry.value.length;
          boardedCount += boarded.length;
          notBoardedCount += notBoarded.length;
        }
      }

      // Sort by date (most recent first)
      allTrips.sort((a, b) => b['date'].compareTo(a['date']));
      
      trips = allTrips;
    } catch (e) {
      debugPrint('Error fetching trip data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load trip data: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
    setState(() => loading = false);
  }

  List<Map<String, dynamic>> getFilteredStudents(Map<String, dynamic> trip) {
    if (filter == 'Boarded') {
      return trip['boarded'] as List<Map<String, dynamic>>;
    } else if (filter == 'Not Boarded') {
      return trip['not_boarded'] as List<Map<String, dynamic>>;
    }
    // All - combine both
    return [...trip['boarded'] as List, ...trip['not_boarded'] as List];
  }

  Widget _buildFilterChip(String label, Color color) {
    final isSelected = filter == label;
    return GestureDetector(
      onTap: () => setState(() => filter = label),
      child: AnimatedContainer(
        duration: AppTheme.fastAnimation,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: isSelected ? LinearGradient(colors: [color, color.withOpacity(0.8)]) : null,
          color: isSelected ? null : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? color : color.withOpacity(0.3), width: isSelected ? 0 : 1.5),
          boxShadow: isSelected ? AppTheme.cardShadow : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: isSelected ? Colors.white : color,
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.subtleGradient),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _buildFilterChip('All', AppTheme.primaryBlue),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildFilterChip('Boarded', AppTheme.success),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildFilterChip('Not Boarded', AppTheme.error),
                ),
              ],
            ),
          ),


          Expanded(
            child: loading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Loading trip data...', style: TextStyle(color: AppTheme.textSecondary)),
                      ],
                    ),
                  )
                : trips.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inbox_rounded, size: 64, color: AppTheme.textSecondary.withOpacity(0.5)),
                            const SizedBox(height: 16),
                            const Text('No trip data found', style: TextStyle(fontSize: 18, color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: fetchTripData,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: trips.length,
                          itemBuilder: (context, index) {
                            final trip = trips[index];
                            final filteredStudents = getFilteredStudents(trip);
                            if (filteredStudents.isEmpty) return const SizedBox.shrink();
                            return AnimatedCard(
                              margin: const EdgeInsets.only(bottom: 16, left: 0, right: 0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          gradient: AppTheme.primaryGradient,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Icon(Icons.directions_bus_rounded, color: Colors.white, size: 22),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('Bus ${trip['bus_plate']}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                                            Text(trip['date'], style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                                          ],
                                        ),
                                      ),
                                      if (filter == 'All') ...[
                                        _buildBadge('${(trip['boarded'] as List).length}', AppTheme.success),
                                        const SizedBox(width: 6),
                                        _buildBadge('${(trip['not_boarded'] as List).length}', AppTheme.error),
                                      ] else
                                        _buildBadge('${trip['total']}', AppTheme.primaryBlue),
                                    ],
                                  ),
                                  const Divider(height: 24),
                                  ...filteredStudents.map((student) {
                                    final isBoarded = student['status'] == 'Boarded';
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 10),
                                      child: Row(
                                        children: [
                                          Icon(
                                            isBoarded ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                            color: isBoarded ? AppTheme.success : AppTheme.error,
                                            size: 22,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(student['student_name'], style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15, color: AppTheme.textPrimary)),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
