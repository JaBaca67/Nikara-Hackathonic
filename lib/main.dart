import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nikara_app/app.dart';
import 'package:nikara_app/core/services/auth_service.dart';
import 'package:nikara_app/core/services/guest_session_service.dart';
import 'package:nikara_app/core/services/local_profile_extras_service.dart';
import 'package:nikara_app/core/supabase/supabase_config.dart';
import 'package:nikara_app/features/notifications/data/push_message_service.dart';
import 'package:nikara_app/features/notifications/data/push_token_service.dart';
import 'package:nikara_app/firebase_options.dart';

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
  await _initPush();
  runApp(const MyApp());
}

/// Firebase (Cloud Messaging) es solo la capa de entrega de push — ver
/// CLAUDE.md > Stack. Supabase sigue siendo la única fuente de verdad; si
/// esto falla (sin Firebase configurado, sin permisos, plataforma sin
/// soporte), las notificaciones in-app de siempre siguen funcionando
/// igual, así que un error acá nunca debe tumbar el arranque de la app.
Future<void> _initPush() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    PushTokenService().startTracking();
    await PushMessageService().startListening();
  } catch (e) {
    debugPrint('Push deshabilitado en este arranque: $e');
  }
}
