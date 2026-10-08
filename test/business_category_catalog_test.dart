import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nikara_app/features/business/utils/business_icons.dart';

void main() {
  group('catálogo de categorías', () {
    test('todo nombre del catálogo es de una sola palabra visible', () {
      // El chip del filtro de Inicio se dimensiona por su texto: un nombre
      // compuesto ("Agroturismo / Fincas") se comía media fila. La regla vive
      // acá para que una categoría nueva no la rompa sin que nadie lo note.
      for (final category in kBusinessCategoryPresets) {
        expect(
          category.contains(' '),
          isFalse,
          reason: '"$category" tiene espacios y no entra en el chip',
        );
        expect(category.length, lessThanOrEqualTo(12), reason: category);
      }
    });

    test('cada categoría tiene ícono propio y subcategorías', () {
      final icons = <IconData>{};
      for (final category in kBusinessCategoryPresets) {
        final icon = businessCategoryIcon(category);
        expect(
          icon,
          isNot(Icons.category_rounded),
          reason: '$category cae al ícono genérico',
        );
        expect(icons.add(icon), isTrue, reason: '$category repite ícono');
        expect(subcategoriesFor(category), isNotEmpty, reason: category);
      }
    });

    test('normaliza a sí misma', () {
      for (final category in kBusinessCategoryPresets) {
        expect(businessCategoryPresetFor(category), category);
      }
    });
  });

  group('businessCategoryPresetFor', () {
    test('resuelve los nombres anteriores del catálogo', () {
      // Filas ya guardadas en `businesses.category` con el nombre viejo.
      expect(businessCategoryPresetFor('Tour'), 'Tours');
      expect(businessCategoryPresetFor('Compras y mercados'), 'Compras');
      expect(businessCategoryPresetFor('Agroturismo / Fincas'), 'Agroturismo');
      expect(
        businessCategoryPresetFor('Servicios para el viajero'),
        'Servicios',
      );
    });

    test('"Agroturismo" no se lo come la rama de Tours', () {
      // "agroturismo" contiene "turismo": si la rama de Tours se evalúa
      // primero, todas las fincas aparecen bajo Tours.
      expect(businessCategoryPresetFor('Agroturismo'), 'Agroturismo');
      expect(businessCategoryPresetFor('Finca cafetalera'), 'Agroturismo');
    });

    test('resuelve las categorías de los datos semilla', () {
      expect(businessCategoryPresetFor('Turismo y Miradores'), 'Tours');
      expect(businessCategoryPresetFor('Artesanía y Alfarería'), 'Cultura');
      expect(businessCategoryPresetFor('Cultura y Patrimonio'), 'Cultura');
      expect(businessCategoryPresetFor('Arte y Escultura'), 'Cultura');
      expect(
        businessCategoryPresetFor('Gastronomía Tradicional'),
        'Restaurante',
      );
    });

    test('devuelve null en vez de adivinar', () {
      expect(businessCategoryPresetFor('Pulpería de don Chico'), isNull);
      expect(businessCategoryPresetFor(''), isNull);
    });
  });

  test('subcategoriesFor acepta el nombre anterior de la categoría', () {
    // Al editar un negocio guardado como "Tour" el picker tiene que seguir
    // ofreciendo sus subcategorías, no quedarse vacío.
    expect(subcategoriesFor('Tour'), subcategoriesFor('Tours'));
    expect(
      subcategoriesFor('Agroturismo / Fincas'),
      subcategoriesFor('Agroturismo'),
    );
    expect(subcategoriesFor('Pulpería de don Chico'), isEmpty);
  });

  group('orderedBusinessCategories (chips del Mapa)', () {
    test('normaliza y ordena como el catálogo, no alfabéticamente', () {
      // Los 9 valores que hay hoy en `businesses.category`, en el orden
      // alfabético en que los devolvía la consulta.
      const enLaBaseDeDatos = [
        'Agroturismo / Fincas',
        'Arte y Escultura',
        'Artesanía y Alfarería',
        'Cultura y Patrimonio',
        'Gastronomía Tradicional',
        'Hospedaje',
        'Restaurante',
        'Tour',
        'Turismo y Miradores',
      ];
      expect(orderedBusinessCategories(enLaBaseDeDatos), [
        'Hospedaje',
        'Restaurante',
        'Tours',
        'Cultura',
        'Agroturismo',
      ]);
    });

    test('un valor irreconocible se conserva al final, no se pierde', () {
      // Perder el chip esconde los negocios que lo usan.
      expect(orderedBusinessCategories(const ['Pulpería', 'Hospedaje']), [
        'Hospedaje',
        'Pulpería',
      ]);
    });

    test('ignora los vacíos', () {
      expect(orderedBusinessCategories(const ['', 'Hospedaje']), ['Hospedaje']);
    });
  });
}
