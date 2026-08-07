import 'package:flutter/material.dart';

import 'package:nikara_app/features/business/data/business_storage_service.dart';
import 'package:nikara_app/features/business/domain/models/business_model.dart';
import 'package:nikara_app/features/business/presentation/screens/business_detail_screen.dart';
import 'package:nikara_app/features/home/data/mock_destinations.dart';
import 'package:nikara_app/features/home/domain/models/destination.dart';
import 'package:nikara_app/shared/widgets/local_image.dart';
import 'package:nikara_app/theme/app_theme.dart';

enum _MapCategory { todos, playas, volcanes, eco }

extension on _MapCategory {
  String get label => switch (this) {
    _MapCategory.todos => 'Todos',
    _MapCategory.playas => 'Playas',
    _MapCategory.volcanes => 'Volcanes',
    _MapCategory.eco => 'Eco',
  };
}

_MapCategory _categoryOf(DestinationModel destination) {
  final title = destination.title.toLowerCase();
  if (destination.tag?.toUpperCase() == 'ECO') return _MapCategory.eco;
  if (title.contains('playa')) return _MapCategory.playas;
  if (title.contains('volcán') || title.contains('volcan')) {
    return _MapCategory.volcanes;
  }
  return _MapCategory.todos;
}

class _MapPin {
  const _MapPin({required this.destination, required this.dx, required this.dy});

  final DestinationModel destination;

  /// Fictional, fraction-of-map (0..1) position — not real coordinates.
  final double dx;
  final double dy;
}

class _BusinessPin {
  const _BusinessPin({required this.business, required this.dx, required this.dy});

  final BusinessModel business;
  final double dx;
  final double dy;
}

/// Deterministic 0..1 fraction derived from [seed] — used to place a
/// business pin plausibly on the stylized map without a real lat/lng
/// (the wizard doesn't collect real coordinates).
double _pseudoFraction(String seed, int salt) {
  final hash = (seed.hashCode ^ salt).abs();
  return 0.15 + (hash % 1000) / 1000 * 0.7;
}

List<_BusinessPin> _buildBusinessPins(List<BusinessModel> businesses) {
  return [
    for (final business in businesses)
      _BusinessPin(
        business: business,
        dx: _pseudoFraction(business.id, 17),
        dy: _pseudoFraction(business.id, 31),
      ),
  ];
}

/// Fictional pin layout loosely following each destination's real region
/// within Nicaragua's silhouette, for a plausible-looking simplified map.
List<_MapPin> _buildPins() {
  const positions = <String, (double, double)>{
    'playa-maderas': (0.30, 0.66),
    'san-juan-del-sur': (0.35, 0.72),
    'laguna-de-apoyo': (0.52, 0.56),
    'isletas-de-granada': (0.58, 0.62),
    'isla-de-ometepe': (0.50, 0.74),
    'volcan-telica': (0.34, 0.34),
    'playa-el-velero': (0.24, 0.40),
    'canon-de-somoto': (0.40, 0.14),
    'corn-island': (0.86, 0.62),
    'laguna-de-perlas': (0.80, 0.44),
  };
  return [
    for (final destination in mockDestinations)
      if (positions.containsKey(destination.id))
        _MapPin(
          destination: destination,
          dx: positions[destination.id]!.$1,
          dy: positions[destination.id]!.$2,
        ),
  ];
}

/// Mapa screen (Figma node 167:1849): a simplified illustrated map (no live
/// map SDK/API key wired up) with fictional pins, a category filter and a
/// destination list — both driven by [mockDestinations].
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _businessStorageService = BusinessStorageService();
  final _pins = _buildPins();
  List<_BusinessPin> _businessPins = const [];
  List<BusinessModel> _businesses = const [];
  _MapCategory _selectedCategory = _MapCategory.todos;
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    _loadBusinesses();
  }

  Future<void> _loadBusinesses() async {
    final businesses = await _businessStorageService.getBusinesses();
    if (!mounted) return;
    setState(() {
      _businesses = businesses;
      _businessPins = _buildBusinessPins(businesses);
    });
  }

  List<DestinationModel> get _filteredDestinations {
    if (_selectedCategory == _MapCategory.todos) return mockDestinations;
    return mockDestinations
        .where((d) => _categoryOf(d) == _selectedCategory)
        .toList();
  }

  void _openDestinationSheet(DestinationModel destination) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface100,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _DestinationSummarySheet(destination: destination),
    );
  }

  void _openBusinessSheet(BusinessModel business) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface100,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _BusinessSummarySheet(business: business),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundCream,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Mapa de Nicaragua', style: AppTextStyles.headerTitleMd),
                    const SizedBox(height: 2),
                    Text('Toca un pin para explorar', style: AppTextStyles.sectionSubLabel),
                  ],
                ),
              ),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  _StylizedMap(
                    pins: _pins,
                    businessPins: _businessPins,
                    onPinTap: _openDestinationSheet,
                    onBusinessPinTap: _openBusinessSheet,
                  ),
                  Positioned(
                    left: 20,
                    right: 20,
                    top: 12,
                    child: _MapSearchBar(
                      onFilterTap: () =>
                          setState(() => _showFilters = !_showFilters),
                    ),
                  ),
                ],
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                child: _showFilters
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                        child: Wrap(
                          spacing: 8,
                          children: [
                            for (final category in _MapCategory.values)
                              ChoiceChip(
                                label: Text(category.label),
                                labelStyle: AppTextStyles.link.copyWith(
                                  color: _selectedCategory == category
                                      ? AppColors.neutral1100
                                      : AppColors.neutral700,
                                ),
                                selected: _selectedCategory == category,
                                selectedColor: AppColors.tagGold600,
                                backgroundColor: AppColors.surface100,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999),
                                  side: BorderSide(
                                    color: _selectedCategory == category
                                        ? AppColors.tagGold600
                                        : AppColors.surface200,
                                  ),
                                ),
                                onSelected: (_) =>
                                    setState(() => _selectedCategory = category),
                              ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text(
                  'TODOS LOS DESTINOS · ${_filteredDestinations.length} LUGARES',
                  style: AppTextStyles.mapListLabel,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    for (final destination in _filteredDestinations) ...[
                      _MapDestinationRow(
                        destination: destination,
                        onTap: () => _openDestinationSheet(destination),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
              if (_businesses.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Text(
                    'NEGOCIOS REGISTRADOS · ${_businesses.length}',
                    style: AppTextStyles.mapListLabel,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      for (final business in _businesses) ...[
                        _MapBusinessRow(
                          business: business,
                          onTap: () => _openBusinessSheet(business),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MapSearchBar extends StatelessWidget {
  const _MapSearchBar({required this.onFilterTap});

  final VoidCallback onFilterTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.only(right: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: AppColors.neutral1100, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F000000),
            offset: Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          const Icon(Icons.search, size: 18, color: Color(0xFF808080)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Search...',
              style: AppTextStyles.caption.copyWith(color: const Color(0xFF808080)),
            ),
          ),
          GestureDetector(
            onTap: onFilterTap,
            child: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.tagGold600,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.tune, size: 16, color: AppColors.neutral1100),
            ),
          ),
        ],
      ),
    );
  }
}

/// A stylized stand-in for a real map: a soft terrain/coast gradient plus
/// fictional destination pins — no map SDK or API key required.
class _StylizedMap extends StatelessWidget {
  const _StylizedMap({
    required this.pins,
    required this.businessPins,
    required this.onPinTap,
    required this.onBusinessPinTap,
  });

  final List<_MapPin> pins;
  final List<_BusinessPin> businessPins;
  final ValueChanged<DestinationModel> onPinTap;
  final ValueChanged<BusinessModel> onBusinessPinTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      height: 280,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.accent300.withValues(alpha: 0.18),
            AppColors.profileHeaderGoldPale.withValues(alpha: 0.35),
            const Color(0xFF8FC5D6).withValues(alpha: 0.45),
          ],
        ),
      ),
      child: Stack(
        children: [
          for (final pin in pins)
            Positioned.fill(
              child: Align(
                alignment: FractionalOffset(pin.dx, pin.dy),
                child: FractionalTranslation(
                  translation: const Offset(0, -0.5),
                  child: _MapPinButton(
                    isEco: pin.destination.tag?.toUpperCase() == 'ECO',
                    onTap: () => onPinTap(pin.destination),
                  ),
                ),
              ),
            ),
          for (final pin in businessPins)
            Positioned.fill(
              child: Align(
                alignment: FractionalOffset(pin.dx, pin.dy),
                child: FractionalTranslation(
                  translation: const Offset(0, -0.5),
                  child: _BusinessPinButton(
                    onTap: () => onBusinessPinTap(pin.business),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MapPinButton extends StatelessWidget {
  const _MapPinButton({required this.isEco, required this.onTap});

  final bool isEco;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(
        Icons.location_on,
        size: 32,
        color: isEco ? AppColors.ecoGreen500 : AppColors.primary700,
        shadows: const [Shadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
      ),
    );
  }
}

/// Pin for a registered business — a distinct storefront glyph so it reads
/// differently from the curated destination pins on the same map.
class _BusinessPinButton extends StatelessWidget {
  const _BusinessPinButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: const Icon(
        Icons.storefront,
        size: 30,
        color: AppColors.ecoForest,
        shadows: [Shadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
      ),
    );
  }
}

class _MapDestinationRow extends StatelessWidget {
  const _MapDestinationRow({required this.destination, required this.onTap});

  final DestinationModel destination;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final reviewCount = 90 + (destination.price.toInt() % 200);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surface100,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F000000),
              offset: Offset(0, 2),
              blurRadius: 5,
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 52,
                height: 46,
                child: destination.imageAsset != null
                    ? Image.asset(destination.imageAsset!, fit: BoxFit.cover)
                    : ColoredBox(color: destination.imagePlaceholderColor),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          destination.title,
                          style: AppTextStyles.mapRowTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (destination.tag?.toUpperCase() == 'ECO') ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.ecoGreen500,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text('ECO', style: AppTextStyles.tagPill.copyWith(fontSize: 8)),
                        ),
                      ],
                    ],
                  ),
                  Text(destination.location, style: AppTextStyles.mapRowCaption),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.star, size: 9, color: AppColors.primary500),
                      const SizedBox(width: 4),
                      Text('${destination.rating}', style: AppTextStyles.mapRowRating),
                      const SizedBox(width: 4),
                      Text('($reviewCount)', style: AppTextStyles.mapRowCaption),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(destination.formattedPrice, style: AppTextStyles.mapRowPrice),
                Text('/persona', style: AppTextStyles.listCardPriceSuffix),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MapBusinessRow extends StatelessWidget {
  const _MapBusinessRow({required this.business, required this.onTap});

  final BusinessModel business;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final imagePath = business.localImagePaths.isNotEmpty
        ? business.localImagePaths.first
        : null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surface100,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F000000),
              offset: Offset(0, 2),
              blurRadius: 5,
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 52,
                height: 46,
                child: LocalImage(
                  path: imagePath,
                  fallbackIcon: Icons.storefront_outlined,
                  fallbackIconSize: 18,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    business.name,
                    style: AppTextStyles.mapRowTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(business.city, style: AppTextStyles.mapRowCaption),
                  const SizedBox(height: 2),
                  Text(business.category, style: AppTextStyles.mapRowCaption),
                ],
              ),
            ),
            if (business.allowsReservations)
              Text(business.formattedPrice, style: AppTextStyles.mapRowPrice),
          ],
        ),
      ),
    );
  }
}

class _BusinessSummarySheet extends StatelessWidget {
  const _BusinessSummarySheet({required this.business});

  final BusinessModel business;

  @override
  Widget build(BuildContext context) {
    final imagePath = business.localImagePaths.isNotEmpty
        ? business.localImagePaths.first
        : null;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    width: 64,
                    height: 64,
                    child: LocalImage(
                      path: imagePath,
                      fallbackIcon: Icons.storefront_outlined,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(business.name, style: AppTextStyles.sectionTitle),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 12, color: AppColors.neutral500),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              business.city,
                              style: AppTextStyles.listCardCaption,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (business.allowsReservations)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(business.category, style: AppTextStyles.cardTitle),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text('${business.formattedPrice} ', style: AppTextStyles.listCardPrice),
                      Text('/persona', style: AppTextStyles.listCardPriceSuffix),
                    ],
                  ),
                ],
              )
            else
              Text(business.category, style: AppTextStyles.cardTitle),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary500,
                  foregroundColor: AppColors.neutral1100,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => BusinessDetailScreen(business: business),
                    ),
                  );
                },
                child: const Text('Ver Detalle'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DestinationSummarySheet extends StatelessWidget {
  const _DestinationSummarySheet({required this.destination});

  final DestinationModel destination;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    width: 64,
                    height: 64,
                    child: destination.imageAsset != null
                        ? Image.asset(destination.imageAsset!, fit: BoxFit.cover)
                        : ColoredBox(color: destination.imagePlaceholderColor),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(destination.title, style: AppTextStyles.sectionTitle),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 12, color: AppColors.neutral500),
                          const SizedBox(width: 2),
                          Text(destination.location, style: AppTextStyles.listCardCaption),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.star, size: 16, color: AppColors.primary500),
                    const SizedBox(width: 4),
                    Text('${destination.rating}', style: AppTextStyles.cardTitle),
                  ],
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text('${destination.formattedPrice} ', style: AppTextStyles.listCardPrice),
                    Text('/persona', style: AppTextStyles.listCardPriceSuffix),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary500,
                  foregroundColor: AppColors.neutral1100,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Próximamente')),
                  );
                },
                child: const Text('Ver Detalle'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
