import 'package:flutter/material.dart';
import 'supabase_client.dart';
import 'screens/parent/parent_home_screen.dart';
import 'screens/parent/parent_login_screen.dart';
import 'screens/parent/set_password_screen.dart';
import 'screens/parent/parent_password_login_screen.dart';
import 'services/auth_service.dart';

final authService = AuthService();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initSupabase();
  runApp(const ParentApp());
}

class ParentApp extends StatelessWidget {
  const ParentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Parent Panel',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
      initialRoute: '/',
      routes: {
        '/': (_) => const AuthHandler(),
        '/login': (_) => const ParentLoginScreen(),
        '/home': (_) => const ParentHomeScreen(),
        '/parent/set-password': (_) => const SetPasswordScreen(),
        '/parent/password-login': (_) => const ParentPasswordLoginScreen(),
      },
    );
  }
}

class AuthHandler extends StatelessWidget {
  const AuthHandler({super.key});

  @override
  Widget build(BuildContext context) {
    // Always start at login screen for parent panel
    return const ParentLoginScreen();
  }
}
