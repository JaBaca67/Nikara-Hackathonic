---
name: nikara-new-feature
description: Scaffold a new feature module under lib/features/<name>/ following Nikara's feature-first layout (data/domain/presentation), including a starting screen wired into navigation. Use when the user asks to add a new feature, section, or screen area to the Nikara app (not a single one-off widget — for that, just add the widget in place).
---

# Nikara: nueva feature

Crea una feature nueva siguiendo el layout de `lib/features/business/` (el ejemplo más completo del repo).

## Pasos

1. **Confirma el alcance** con el usuario si no está claro: ¿necesita `data/` (llamadas a Supabase), `domain/` (modelos), y `presentation/` (screens/widgets), o solo un subconjunto? No crees las tres carpetas si la feature no las necesita — revisa `lib/features/map/` o `lib/features/settings/` como ejemplos de features más simples (solo `presentation/`).

2. **Estructura**:
   ```
   lib/features/<nombre>/
     data/            # solo si habla con Supabase directamente
       <nombre>_service.dart
     domain/
       models/
         <algo>_model.dart
     presentation/
       screens/
         <nombre>_screen.dart
       widgets/       # widgets usados solo dentro de esta feature
   ```

3. **Modelos de dominio**: clases inmutables (`const` constructor, campos `final`) con `factory X.fromRow(Map<String, dynamic> row)` para deserializar desde Supabase — sin `freezed`/`json_serializable`, el repo no los usa. Ver `lib/core/models/user_model.dart` o `lib/features/business/domain/models/business_model.dart` como plantilla.

4. **Servicio de datos** (si aplica): sigue el patrón singleton — usa el skill `nikara-supabase-service` para esta parte en vez de reinventarlo.

5. **Screen**: `StatefulWidget` o `StatelessWidget` según necesite estado local; usa `AppColors`/`AppTheme` para todo estilo, nunca colores hardcodeados. Si la screen es un tab/sección top-level, regístrala en la navegación (`lib/shared/widgets/main_layout.dart` y `lib/features/home/presentation/widgets/main_navigation_bar.dart`).

6. **Verifica**: corre `flutter analyze` y, si la feature tiene texto dinámico proveniente de negocio/usuario, considera agregar un caso a `test/overflow_audit_test.dart` (usa el skill `nikara-overflow-audit`).

## No hacer

- No mezcles lógica de Supabase directamente en un widget de `presentation/` — pásala por un servicio en `data/`.
- No agregues la screen nueva a `lib/widgets/` ni a `lib/models/` — esas carpetas son legacy (ver reglas en `CLAUDE.md`).
