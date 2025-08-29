import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

Future<void> initSupabase() async {
  await Supabase.initialize(
    url: 'https://nnjjefycskerdjqmatkf.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5uamplZnljc2tlcmRqcW1hdGtmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTI2MjU0NzYsImV4cCI6MjA2ODIwMTQ3Nn0.tZekV645uZAtapXr5jlyKFItjfus7FziedaqIEFkA-U',
    authOptions: const FlutterAuthClientOptions(authFlowType: AuthFlowType.pkce),
  );
}
