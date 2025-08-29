import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_client.dart';
import 'screens/school_admin/login_screen.dart';
import 'screens/school_admin/assignment/assignment_screen.dart';
import 'screens/school_admin/change_password_screen.dart';
import 'screens/school_admin/school_admin_app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initSupabase();
  runApp(const SchoolAdminMainApp());
}

class SchoolAdminMainApp extends StatelessWidget {
  const SchoolAdminMainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'School Administration',
      theme: ThemeData(primarySwatch: Colors.indigo, useMaterial3: true),
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => const AuthHandler(),
        '/login': (context) => const SchoolAdminLoginScreen(),
        '/change-password': (context) => const ChangePasswordScreen(),
        // Route recovery/invite deep links to ChangePasswordScreen
        '/assignment/set-password': (context) => const ChangePasswordScreen(),
        // Optional direct route to dashboard
        '/home': (context) => SchoolAdminApp(onLogout: () async {
              await Supabase.instance.client.auth.signOut();
              if (Navigator.canPop(context)) {
                Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
              }
            }),
      },
    );
  }
}

class AuthHandler extends StatefulWidget {
  const AuthHandler({super.key});

  @override
  State<AuthHandler> createState() => _AuthHandlerState();
}

class _AuthHandlerState extends State<AuthHandler> {
  @override
  void initState() {
    super.initState();
    _handleDeepLinks();
    _handleWebRedirectIfAny();
  }

  void _handleDeepLinks() {
    supabase.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        // This event is triggered when the user clicks the invitation link.
        // We navigate to the change password screen.
        Navigator.of(context).pushReplacementNamed('/assignment/set-password');
      }
    });
  }

  void _handleWebRedirectIfAny() {
    // This logic is now handled by the onAuthStateChange listener below,
    // which is more reliable.
  }

  @override
  Widget build(BuildContext context) {
    // This widget handles the initial auth state.
    // If a user is already logged in, they are sent to the home screen.
    // Otherwise, they see the login screen.
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (snapshot.hasData && snapshot.data?.session != null) {
          // User is logged in -> show dashboard shell with tabs
          return SchoolAdminApp(onLogout: () async {
            await Supabase.instance.client.auth.signOut();
            if (context.mounted) {
              Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
            }
          });
        }

        // User is not logged in.
        return const SchoolAdminLoginScreen();
      },
    );
  }
}
