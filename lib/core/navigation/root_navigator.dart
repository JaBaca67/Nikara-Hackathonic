import 'package:flutter/material.dart';

/// Le da a código sin `BuildContext` (el tap de una notificación push, que
/// puede llegar con la app recién arrancando) una forma de navegar. Se cuelga
/// del `MaterialApp` en `app.dart` y lo usa `push_message_service.dart`.
final rootNavigatorKey = GlobalKey<NavigatorState>();
