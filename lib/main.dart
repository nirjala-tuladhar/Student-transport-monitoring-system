import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_client.dart';
import 'screens/superadmin/login_screen.dart';
import 'screens/superadmin/dashboard_screen.dart';
import 'screens/superadmin/create_school_admin_screen.dart';
import 'screens/school_admin/change_password_screen.dart';

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
        '/': (context) => const RootHandler(),
        '/dashboard': (context) => const SuperadminDashboardScreen(),
        '/create_school_admin': (context) => const CreateSchoolAdminScreen(),
        // School Admin password setup flow handled within main app
        '/school/change-password': (context) => const ChangePasswordScreen(redirectRoute: '/'),
      },
    );
  }
}

class RootHandler extends StatefulWidget {
  const RootHandler({super.key});

  @override
  State<RootHandler> createState() => _RootHandlerState();
}

class _RootHandlerState extends State<RootHandler> {
  @override
  void initState() {
    super.initState();
    _handleWebRedirectIfAny();
  }

  void _handleWebRedirectIfAny() {
    if (!kIsWeb) return;
    final uri = Uri.base;
    // Supabase may put parameters in the query OR in the URL fragment (hash)
    final queryType = uri.queryParameters['type'];
    String? fragmentType;
    String? accessToken;
    String? refreshToken;
    if (uri.fragment.isNotEmpty) {
      // fragment looks like: access_token=...&type=recovery&...
      final fragParams = Uri.splitQueryString(uri.fragment, encoding: Encoding.getByName('utf-8') ?? const Utf8Codec());
      fragmentType = fragParams['type'];
      accessToken = fragParams['access_token'];
      refreshToken = fragParams['refresh_token'];
    }

    final type = queryType ?? fragmentType;

    if (type == 'recovery' || type == 'invite') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        // If tokens are present in the fragment, set the session so password update works
        if (refreshToken != null) {
          // For supabase_flutter 2.x, setSession(refreshToken) will fetch session
          Supabase.instance.client.auth.setSession(refreshToken!);
        }
        Navigator.of(context).pushReplacementNamed('/school/change-password');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Default: show Superadmin login when not in recovery/invite flow
    return const SuperadminLoginScreen();
  }
}
