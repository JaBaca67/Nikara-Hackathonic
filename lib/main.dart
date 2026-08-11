import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nikara_app/app.dart'; // Importa el archivo de arriba
import 'package:nikara_app/core/supabase/supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    // supabase_flutter's newer API calls this "publishableKey" — same JWT
    // anon key value, just a renamed parameter.
    publishableKey: SupabaseConfig.anonKey,
  );
  // Arranca la aplicación llamando a MyApp
  runApp(const MyApp());
} 