---
name: nikara-overflow-audit
description: Stress-test a Nikara screen or widget against unrealistically long business/user text to catch RenderFlex overflow bugs, following the project's existing test/overflow_audit_test.dart pattern. Use when the user asks to check for UI overflow, "desbordes", clipped text, or after adding a screen/card that renders dynamic business data (name, description, address).
---

# Nikara: auditoría de overflow

Este proyecto ya tuvo una ronda completa de fixes de overflow (commit `9ae1e8a`). `test/overflow_audit_test.dart` mantiene esa cobertura viva renderizando pantallas con datos deliberadamente peores que cualquier input real.

## Cuándo usar

- Se agregó una screen/card/widget nuevo que muestra texto dinámico proveniente de un negocio o perfil de usuario (nombre, descripción, dirección, categoría, amenidades).
- El usuario reporta o sospecha un `RenderFlex overflowed by X pixels` en alguna pantalla.

## Cómo auditar

1. Mira `test/overflow_audit_test.dart` — define `_stressBusiness`, un `BusinessModel` con campos deliberadamente larguísimos (nombres de 80+ caracteres, descripciones sin saltos de línea, listas largas de amenidades/actividades). Si tu widget nuevo consume un modelo distinto (ej. `UserModel`, `ReviewModel`), crea un fixture equivalente para ese modelo: strings largos, sin espacios naturales para wrap, listas con muchos elementos.

2. Renderiza la pantalla/widget con ese fixture dentro de un `testWidgets`, envuelto en el `AppTheme` del proyecto (igual que las demás pruebas del archivo).

3. Corre el test: cualquier overflow aparece como excepción/error de Flutter en la consola de test (`A RenderFlex overflowed by ... pixels`), no como un `expect` fallido — revisa el output completo, no solo el resultado final pass/fail.

4. **Fixes típicos** (en orden de preferencia): envolver texto en `Expanded`/`Flexible` dentro de `Row`; agregar `overflow: TextOverflow.ellipsis` + `maxLines` a `Text`; envolver contenido de card en `SingleChildScrollView` cuando el overflow es vertical y el contenido es legítimamente largo (no truncable).

5. Si el widget nuevo maneja datos de negocio/usuario, agrégalo como un nuevo `testWidgets` dentro de `test/overflow_audit_test.dart` en vez de crear un archivo de test separado — mantiene toda la auditoría en un solo lugar.
