import 'package:flutter/material.dart';

/// `category`/`requirements` son texto libre en Supabase (mismo criterio que `business_icons.dart`): se empareja por palabra clave con un ícono genérico de respaldo.
IconData ecoCategoryIcon(String category) {
  final value = category.toLowerCase();
  if (value.contains('refores') || value.contains('árbol')) {
    return Icons.park_rounded;
  }
  if (value.contains('fauna') || value.contains('animal')) {
    return Icons.pets_rounded;
  }
  if (value.contains('limpieza') || value.contains('basura')) {
    return Icons.cleaning_services_rounded;
  }
  if (value.contains('playa') ||
      value.contains('río') ||
      value.contains('mar')) {
    return Icons.water_rounded;
  }
  return Icons.eco_rounded;
}

IconData ecoRequirementIcon(String requirement) {
  final value = requirement.toLowerCase();
  if (value.contains('ropa') ||
      value.contains('bota') ||
      value.contains('zapato') ||
      value.contains('gorra')) {
    return Icons.checkroom_rounded;
  }
  if (value.contains('agua') ||
      value.contains('hidrat') ||
      value.contains('botella')) {
    return Icons.water_drop_rounded;
  }
  if (value.contains('guante')) return Icons.back_hand_rounded;
  if (value.contains('solar') || value.contains('sol')) {
    return Icons.wb_sunny_rounded;
  }
  if (value.contains('comida') ||
      value.contains('almuerzo') ||
      value.contains('merienda')) {
    return Icons.restaurant_rounded;
  }
  if (value.contains('bolsa') || value.contains('saco')) {
    return Icons.shopping_bag_rounded;
  }
  if (value.contains('herramienta') ||
      value.contains('pala') ||
      value.contains('machete')) {
    return Icons.handyman_rounded;
  }
  if (value.contains('repelente') || value.contains('insecto')) {
    return Icons.bug_report_rounded;
  }
  return Icons.check_circle_outline_rounded;
}
