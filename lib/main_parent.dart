import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final session = snapshot.data?.session;
        if (session != null) {
          // If there's a session, the user is logged in and can see the home screen.
          // The login screen handles the initial password set.
          return const ParentHomeScreen();
        }

        // Otherwise, the user needs to log in.
        return const ParentLoginScreen();
      },
    );
  }
}
