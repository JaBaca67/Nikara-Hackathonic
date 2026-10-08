import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
  ]);
  await _configureSystemBars();
  // En paralelo al resto del init: el isotipo del splash tiene que estar decodificado en el primer frame.
  final isotipoReady = _precacheAsset(
    'assets/images/isotipo_nikara_splash.png',
    'isotipo del splash',
  );
  // Las ilustraciones de Auth no se ven hasta el login, pero decodificarlas ahí mismo las hacía aparecer a pedazos; este es el único momento en que cuestan cero frames.
  final authArtReady = Future.wait([
    _precacheAsset(
      'assets/images/parte_arriba_nikara.png',
      'ilustración superior de Auth',
    ),
    _precacheAsset(
      'assets/images/parte_abajo_login.png',
      'ilustración inferior de Auth',
    ),
  ]);
  await Supabase.initialize(
    url: SupabaseConfig.url,
    // "publishableKey" es el nuevo nombre de supabase_flutter para la anon key.
    publishableKey: SupabaseConfig.anonKey,
  );
  // Mantiene la lista de "Cambiar de cuenta" al día (incluida la rotación del
  // refresh token); debe quedar suscrito antes de que se emita initialSession.
  AuthService().startTrackingSessions();
  // Borra la marca de invitado que versiones anteriores dejaban en disco.
  await GuestSessionService().load();
  // Limpieza única del avatar local pre-015, que ya nadie lee.
  await LocalProfileExtrasService().clearLegacyAvatar();
  await _initPush();
  await isotipoReady;
  await authArtReady;
  runApp(const MyApp());
}

/// Barras del sistema transparentes e iconos oscuros (fondos amarillo y beige). Sin el
/// `systemNavigationBarContrastEnforced: false`, Android 10+ pone un velo oscuro translúcido tras la
/// barra de gestos; ningún widget de la app declara estilo propio, así que el framework nunca lo
/// anula. Va antes que cualquier otro `await` para que aplique desde el primer frame.
Future<void> _configureSystemBars() async {
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
      systemNavigationBarIconBrightness: Brightness.dark,
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
}

/// `precacheImage` exige un BuildContext y aún no hay árbol; resolver el proveedor con
/// [ImageConfiguration.empty] llena el mismo `imageCache`, así el `Image.asset` correspondiente
/// (misma key: sin `cacheWidth`, sin variantes por densidad) sale sincrónico en vez de aparecer
/// un instante después sobre el fondo vacío. [label] solo identifica el asset en el log.
Future<void> _precacheAsset(String assetPath, String label) {
  final completer = Completer<void>();
  final stream = AssetImage(assetPath).resolve(ImageConfiguration.empty);
  late final ImageStreamListener listener;
  listener = ImageStreamListener(
    (_, _) {
      stream.removeListener(listener);
      completer.complete();
    },
    onError: (Object error, StackTrace? _) {
      stream.removeListener(listener);
      // Sin precarga la pantalla sigue funcionando (el asset carga async); no vale tumbar el arranque.
      debugPrint('Precarga de $label falló: $error');
      completer.complete();
    },
  );
  stream.addListener(listener);
  return completer.future;
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
