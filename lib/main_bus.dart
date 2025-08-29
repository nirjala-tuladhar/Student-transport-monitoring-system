import 'package:flutter/material.dart';
import '../supabase_client.dart';
import '../screens/bus/bus_login_screen.dart';
import '../screens/bus/bus_home_screen.dart';
import '../screens/bus/select_bus_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initSupabase();
  runApp(const BusPanelApp());
}

class BusPanelApp extends StatelessWidget {
  const BusPanelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bus Panel',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const _AuthGate(),
      routes: {
        '/login': (_) => const BusLoginScreen(),
        '/select-bus': (_) => const SelectBusScreen(),
        '/home': (_) => const BusHomeScreen(),
      },
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();
  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Always show login first for Bus panel
      Navigator.of(context).pushReplacementNamed('/login');
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
