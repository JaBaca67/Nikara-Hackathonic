import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nikara_app/app.dart';
import 'package:nikara_app/core/services/auth_service.dart';
import 'package:nikara_app/core/services/guest_session_service.dart';
import 'package:nikara_app/core/services/local_profile_extras_service.dart';
import 'package:nikara_app/core/supabase/supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await Supabase.initialize(
    url: SupabaseConfig.url,
    // "publishableKey" es el nuevo nombre de supabase_flutter para la anon key.
    publishableKey: SupabaseConfig.anonKey,
  );
  // Mantiene la lista de "Cambiar de cuenta" al día (incluida la rotación del
  // refresh token); debe quedar suscrito antes de que se emita initialSession.
  AuthService().startTrackingSessions();
  // Deja isGuest disponible de forma síncrona antes de construir la UI.
  await GuestSessionService().load();
  // Limpieza única del avatar local pre-015, que ya nadie lee.
  await LocalProfileExtrasService().clearLegacyAvatar();
  runApp(const MyApp());
}
