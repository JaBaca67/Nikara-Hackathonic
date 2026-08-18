---
name: nikara-widget-test
description: Write a Flutter widget test for a Nikara screen, including the required Supabase/SharedPreferences mock bootstrap. Use whenever the user asks to add or fix a widget test in this project — the boilerplate is easy to get wrong and causes cryptic assertion failures if skipped.
---

# Nikara: widget test

`AuthService` toca `Supabase.instance` de forma síncrona (incluso solo para leer `isLoggedIn`), lo cual lanza un assertion error si Supabase nunca fue inicializado. Todo widget test en este repo necesita el mismo bootstrap.

## Plantilla obligatoria

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(() async {
    // No hacen falta credenciales reales — Supabase.initialize() solo
    // necesita completar su setup local para que las lecturas síncronas
    // de AuthService dejen de lanzar el assertion error.
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test-anon-key-not-real',
    );
  });

  setUp(() {
    // Otros servicios (favorites, avatar cache) leen SharedPreferences en
    // cada test — sin esto pegan a un platform channel real inexistente.
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('descripción en español de qué se prueba', (tester) async {
    await tester.pumpWidget(const MyApp()); // o MaterialApp(home: LaScreen())
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('texto esperado'), findsOneWidget);
  });
}
```

## Reglas

1. **No uses `pumpAndSettle()`** en ninguna pantalla que incluya `AuroraBackgroundWidget` (o cualquier animación repetida infinita) — nunca terminará. Usa `tester.pump()` + `tester.pump(Duration(...))` explícito.
2. Si la screen bajo test dispara una llamada real a Supabase (no solo lee `Auth.currentUser`), evalúa si conviene testear solo el widget en aislamiento (pasando datos mock por constructor) en vez de mockear la red — este repo no tiene un mock client de Supabase configurado.
3. Nombra las descripciones de test en español, siguiendo la convención existente (`test/widget_test.dart`, `test/overflow_audit_test.dart`).
4. Corre `flutter test <archivo>` después de escribir el test para confirmar que pasa antes de darlo por terminado.
