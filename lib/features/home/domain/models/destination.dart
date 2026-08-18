import 'package:flutter/material.dart';

/// A travel destination shown across the Home screen (featured hero,
/// "Más visitados" and "Por región" sections).
///
/// [imageAsset] is nullable on purpose: until real photography/CDN URLs are
/// available, cards fall back to [imagePlaceholderColor] so the UI never has
/// to change once real assets are wired in.
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

  /// Short place name shown on cards (e.g. "San Juan del Sur") or the
  /// richer "City · Country" line used by the featured hero card.
  final String location;

  /// Groups destinations for the "Por región" section (e.g. "Caribe").
  final String region;

  /// Price in Nicaraguan córdobas per person.
  final double price;

  final double rating;

  /// Pill label, e.g. 'ECO' or a descriptive tag like 'Laguna Volcánica'.
  final String? tag;

  final Color imagePlaceholderColor;
  final String? imageAsset;

  /// Shown as the hero card at the top of Home.
  final bool isFeatured;

  /// Included in the "Más visitados" horizontal list.
  final bool isPopular;

  String get formattedPrice => 'C\$${price.toStringAsFixed(0)}';
}
