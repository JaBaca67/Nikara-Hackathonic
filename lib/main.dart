import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nikara_app/app.dart';
import 'package:nikara_app/core/services/guest_session_service.dart';
import 'package:nikara_app/core/supabase/supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await Supabase.initialize(
    url: SupabaseConfig.url,
    // "publishableKey" es el nuevo nombre de supabase_flutter para la anon key.
    publishableKey: SupabaseConfig.anonKey,
  );
  // Deja isGuest disponible de forma síncrona antes de construir la UI.
  await GuestSessionService().load();
  runApp(const MyApp());
}
