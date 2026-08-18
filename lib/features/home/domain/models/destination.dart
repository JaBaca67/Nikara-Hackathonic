import 'package:flutter/material.dart';

/// Destino turístico mostrado en Home (hero destacado, "Más visitados", "Por región").
///
/// [imageAsset] es nullable a propósito: mientras no haya fotos/CDN reales, las cards usan [imagePlaceholderColor] sin necesitar cambios cuando se conecten assets reales.
@immutable
class DestinationModel {
  const DestinationModel({
    required this.id,
    required this.title,
    required this.location,
    required this.region,
    required this.price,
    required this.rating,
    required this.imagePlaceholderColor,
    this.tag,
    this.imageAsset,
    this.isFeatured = false,
    this.isPopular = false,
  });

  final String id;
  final String title;

  /// Nombre corto para cards (ej. "San Juan del Sur") o "Ciudad · País" en el hero destacado.
  final String location;

  /// Agrupa destinos para la sección "Por región" (ej. "Caribe").
  final String region;

  /// Precio en córdobas por persona.
  final double price;

  final double rating;

  /// Etiqueta tipo pill, ej. 'ECO' o 'Laguna Volcánica'.
  final String? tag;

  final Color imagePlaceholderColor;
  final String? imageAsset;

  /// Se muestra como hero destacado en la parte superior de Home.
  final bool isFeatured;

  /// Incluido en la lista horizontal "Más visitados".
  final bool isPopular;

  String get formattedPrice => 'C\$${price.toStringAsFixed(0)}';
}
