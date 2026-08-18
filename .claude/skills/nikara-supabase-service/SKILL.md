---
name: nikara-supabase-service
description: Add or extend a Supabase-backed service class (singleton pattern, friendly Spanish error messages) in Nikara. Use when the user wants to query/insert/update a Supabase table, add a new backend-facing method to an existing service, or wire up a new table.
---

# Nikara: servicio Supabase

Todo acceso a Supabase pasa por una clase de servicio singleton, nunca directo desde un widget. Referencia canónica: `lib/core/services/auth_service.dart`.

## Patrón

```dart
class XService {
  factory XService() => instance;
  XService._internal();
  static final XService instance = XService._internal();

  SupabaseClient get _client => Supabase.instance.client;

  Future<Foo> doThing() async {
    try {
      final row = await _client.from('tabla').select().eq('col', valor).maybeSingle();
      // ...
    } on PostgrestException catch (e) {
      throw XServiceException('Mensaje amigable en español: ${e.message}');
    } catch (_) {
      throw const XServiceException(
        'Ocurrió un error de conexión. Verifica tu internet e intenta de nuevo.',
      );
    }
  }
}

class XServiceException implements Exception {
  const XServiceException(this.message);
  final String message;
  @override
  String toString() => message;
}
```

## Reglas

1. **Nunca** dejes escapar un `PostgrestException`/`AuthException` crudo hasta la UI — siempre tradúcelo a español via una excepción propia o un result object (ver `AuthResult` en `auth_service.dart` para el patrón de result object cuando el caller necesita distinguir éxito/fallo sin try/catch).
2. **Orden de catch**: excepción específica de Supabase primero (`PostgrestException`, `AuthException`), genérico al final. Nunca `catch (_) {}` vacío — siempre relanza o traduce.
3. Si el método necesita el usuario actual, usa `AuthService().currentAuthUser`/`isLoggedIn` — no dupliques esa lógica.
4. Nombres de columnas: exactamente como están en Postgres (snake_case) en el `Map` que envías/lees — la conversión a camelCase ocurre en el modelo de dominio (`fromRow`), no en el servicio.
5. RLS está deliberadamente deshabilitada en este proyecto (ver comentario en `lib/core/supabase/supabase_config.dart`) — no asumas que Postgres está validando permisos por ti; si el método expone datos sensibles, valida el rol/dueño en Dart antes de exponerlo en la UI.
6. Después de escribir el servicio, corre `flutter analyze`. Si agregas un método nuevo a un servicio existente en vez de crear uno, revisa que no haya ya un método similar (evita duplicar `getProfileById`-style helpers).
