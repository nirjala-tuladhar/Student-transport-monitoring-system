import 'package:flutter/material.dart';
import 'supabase_client.dart';
import 'screens/school_admin/school_admin_login_screen.dart';
import 'screens/school_admin/change_password_screen.dart' as password_screen;
import 'screens/school_admin/school_admin_app.dart' as admin_app;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initSupabase();
  runApp(const SchoolAdminMainApp());
}

class SchoolAdminMainApp extends StatefulWidget {
  const SchoolAdminMainApp({super.key});

  @override
  State<SchoolAdminMainApp> createState() => _SchoolAdminMainAppState();
}

class _SchoolAdminMainAppState extends State<SchoolAdminMainApp> {
  bool _loggedIn = false;
  bool _mustChangePassword = false;

  void _handleLogin({required bool mustChangePassword}) {
    setState(() {
      _loggedIn = true;
      _mustChangePassword = mustChangePassword;
    });
  }

  void _handlePasswordChanged() {
    setState(() {
      _mustChangePassword = false;
    });
  }

  void _handleLogout() {
    setState(() {
      _loggedIn = false;
      _mustChangePassword = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_loggedIn) {
      return MaterialApp(
        title: 'School Admin Login',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(primarySwatch: Colors.blue),
        home: SchoolAdminLoginScreen(onLogin: _handleLogin),
      );
    }

    if (_mustChangePassword) {
      return MaterialApp(
        title: 'Change Password',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(primarySwatch: Colors.blue),
        home: password_screen.ChangePasswordScreen(
          onPasswordChanged: _handlePasswordChanged,
        ),
      );
    }

    return MaterialApp(
      title: 'School Admin Dashboard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      home: admin_app.SchoolAdminApp(onLogout: _handleLogout),
    );
  }
}
