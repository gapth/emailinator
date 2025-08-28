import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

bool _supabaseInitialized = false;

Future<void> ensureSupabaseInitialized() async {
  if (_supabaseInitialized) return;
  // Ensure widget binding (needed for method channel/fake prefs registration).
  TestWidgetsFlutterBinding.ensureInitialized();
  // Provide in-memory SharedPreferences so the plugin channel isn't required.
  SharedPreferences.setMockInitialValues({});
  await Supabase.initialize(
    url: 'https://example.supabase.co',
    anonKey: 'public-anon-key',
    debug: false,
  );
  _supabaseInitialized = true;
}
