import 'package:flutter/material.dart';
import 'supabase_client.dart';
import 'screens/superadmin/login_screen.dart';
import 'screens/superadmin/dashboard_screen.dart';
import 'screens/superadmin/create_school_admin_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initSupabase(); // Connects to Supabase
  runApp(const StudentTransportMonitoringSystem());
}

class StudentTransportMonitoringSystem extends StatelessWidget {
  const StudentTransportMonitoringSystem({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Student Transport Monitoring System',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SuperadminLoginScreen(),
        '/dashboard': (context) => const SuperadminDashboardScreen(),
        '/create_school_admin': (context) => const CreateSchoolAdminScreen(),
        // Add more screens like /create_school_admin, etc. later
      },
    );
  }
}
