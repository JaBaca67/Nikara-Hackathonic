import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nikara_app/app.dart'; // Importa el archivo de arriba
import 'package:nikara_app/core/services/guest_session_service.dart';
import 'package:nikara_app/core/supabase/supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    // supabase_flutte r's newer API calls this "publishableKey" — same JWT
    // anon key value, just a renamed parameter.
    publishableKey: SupabaseConfig.anonKey,
  );
  // Restores whether this device was left in guest mode, synchronously
  // available afterwards via GuestSessionService().isGuest.
  await GuestSessionService().load();
  // Arranca la aplicación llamando a MyApp
  runApp(const MyApp());
}
