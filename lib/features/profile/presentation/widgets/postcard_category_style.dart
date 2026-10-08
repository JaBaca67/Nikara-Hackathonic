import 'package:flutter/material.dart';
import 'package:nikara_app/features/business/utils/business_icons.dart';
import 'package:nikara_app/theme/app_colors.dart';

/// Tape identifies the main category, independently of the subcategory.
/// These decorative paper colors are specific to the postcard collection.
class PostcardCategoryStyle {
  const PostcardCategoryStyle(this.label, this.tapeColor);

  final String label;
  final Color tapeColor;

  static const byCategory = <String, PostcardCategoryStyle>{
    'Hospedaje': PostcardCategoryStyle('Hospedaje', AppColors.goldFill),
    'Restaurante': PostcardCategoryStyle('Comida', AppColors.oliveFill),
    'Tours': PostcardCategoryStyle('Tours', AppColors.orangeFill),
    'Eco-destino': PostcardCategoryStyle('Naturaleza', Color(0xFF89CFC1)),
    'Cultura': PostcardCategoryStyle('Cultura', Color(0xFFBEABE2)),
    'Agroturismo': PostcardCategoryStyle('Agroturismo', Color(0xFFBBA378)),
    'Bienestar': PostcardCategoryStyle('Bienestar', Color(0xFFE6A6BA)),
    'Eventos': PostcardCategoryStyle('Eventos', Color(0xFFCB91CD)),
    'Compras': PostcardCategoryStyle('Compras', Color(0xFFE8BA90)),
    'Transporte': PostcardCategoryStyle('Transporte', Color(0xFF91BDE5)),
    'Servicios': PostcardCategoryStyle('Servicios', Color(0xFF9EB9C1)),
  };

  static const other = PostcardCategoryStyle('Otros', Color(0xFFBDB8AF));

  static PostcardCategoryStyle forCategory(String category) =>
      byCategory[businessCategoryPresetFor(category)] ?? other;
}
