---
name: nikara-figma-screen
description: Implement or update a Nikara screen/widget from the Figma file "UI-NÍKARA", mapping Figma variables to this project's AppColors/AppTheme tokens instead of hardcoding values. Use alongside Claude Code's built-in figma-design-to-code skill whenever a Figma URL or node from "UI-NÍKARA" needs to become Flutter code in this repo.
---

# Nikara: implementar pantalla desde Figma

Este repo deriva su diseño 1:1 del archivo Figma "UI-NÍKARA". Antes de esto, carga el skill genérico `figma-design-to-code` (obtiene el contexto de diseño vía MCP) — este skill agrega las reglas específicas de Nikara para traducir ese contexto a código consistente con el resto del repo.

## Reglas de mapeo

1. **Colores**: nunca copies un hex literal del contexto de Figma directo al widget. Primero busca si ya existe un token equivalente en `lib/theme/app_colors.dart` (nombrado como la Local Variable de Figma, ej. `primary500`, `neutral1100`). Si el nodo usa una variable de Figma que no tiene token todavía, agrégala a `AppColors` con un doc comment que referencie el nodo/variable de Figma (sigue el formato ya usado: `/// Variable "500" — main brand gold.`).
2. **Sin blanco/negro puros**: si Figma trae `#FFFFFF` o `#000000` literal (no ligado a variable), no lo repliques tal cual — este proyecto sustituye deliberadamente esos extremos por `surface100`/`neutral1100` u otro token cercano ya "suavizado" (ver comentario al inicio de `app_colors.dart`).
3. **Tipografía**: usa `AppTheme`/`google_fonts` existentes, no declares `TextStyle` sueltos con tamaños/pesos hardcodeados si ya existe un estilo equivalente en el theme.
4. **Ubicación del widget**: si es una screen completa nueva, sigue el skill `nikara-new-feature`. Si es un widget reutilizable dentro de una screen existente, ponlo en `presentation/widgets/` de esa feature (o `lib/shared/widgets/` solo si se reutilizará entre features distintas).
5. **Texto**: todo string visible al usuario va en español, tal como aparece en el diseño de Figma.
6. **Verifica overflow**: cualquier card/header con texto dinámico (nombre de negocio, descripción) necesita protección contra overflow — usa el skill `nikara-overflow-audit` después de implementar.
7. Documenta el nodo de Figma de origen en un comentario corto sobre la clase del widget (sigue el formato usado en `app_colors.dart`: `/// ... (Figma node 124:37, "Inicio")`), para que futuras actualizaciones de diseño puedan encontrar el nodo de vuelta.
