import 'package:flutter/material.dart';

import 'package:nikara_app/features/business/data/business_storage_service.dart';
import 'package:nikara_app/features/business/domain/models/business_model.dart';
import 'package:nikara_app/features/business/presentation/screens/business_detail_screen.dart';
import 'package:nikara_app/features/home/data/mock_destinations.dart';
import 'package:nikara_app/features/home/domain/models/destination.dart';
import 'package:nikara_app/features/home/presentation/widgets/destination_card.dart';
import 'package:nikara_app/features/home/presentation/widgets/featured_destination_card.dart';
import 'package:nikara_app/features/home/presentation/widgets/search_header_widget.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Home / "Inicio" screen (Figma node 124:37). Assembles the header, the
/// featured hero card, "Más visitados" and the "Por región" groups from
/// [mockDestinations] — plus a "Negocios Locales" row sourced live from
/// [BusinessStorageService] for anything registered through the
/// "Registra tu negocio" wizard.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _businessStorageService = BusinessStorageService();
  List<BusinessModel> _businesses = const [];

  @override
  void initState() {
    super.initState();
    _loadBusinesses();
  }

  Future<void> _loadBusinesses() async {
    final businesses = await _businessStorageService.getBusinesses();
    if (!mounted) return;
    setState(() => _businesses = businesses);
  }

  void _openBusinessDetail(BusinessModel business) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BusinessDetailScreen(business: business),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final featured = mockDestinations.firstWhere(
      (d) => d.isFeatured,
      orElse: () => mockDestinations.first,
    );
    final popular = mockDestinations.where((d) => d.isPopular).toList();
    final regions = _groupByRegion(mockDestinations);

    return Scaffold(
      backgroundColor: AppColors.surface100,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              const SearchHeaderWidget(notificationCount: 3),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: FeaturedDestinationCard(destination: featured),
              ),
              const SizedBox(height: 16),
              _HorizontalSection(
                title: 'Más visitados',
                destinations: popular,
                cardWidth: 168,
              ),
              if (_businesses.isNotEmpty)
                _BusinessSection(
                  businesses: _businesses,
                  onTap: _openBusinessDetail,
                ),
              const SizedBox(height: 8),
              for (final region in regions.keys)
                _HorizontalSection(
                  title: region,
                  destinations: regions[region]!,
                  cardWidth: 144,
                  showSeeMore: true,
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Groups destinations by [DestinationModel.region], preserving the order
  /// regions first appear in — no sorting surprises as new mock entries land.
  Map<String, List<DestinationModel>> _groupByRegion(
    List<DestinationModel> destinations,
  ) {
    final grouped = <String, List<DestinationModel>>{};
    for (final destination in destinations) {
      grouped.putIfAbsent(destination.region, () => []).add(destination);
    }
    return grouped;
  }
}

class _HorizontalSection extends StatelessWidget {
  const _HorizontalSection({
    required this.title,
    required this.destinations,
    required this.cardWidth,
    this.showSeeMore = false,
  });

  final String title;
  final List<DestinationModel> destinations;
  final double cardWidth;
  final bool showSeeMore;

  @override
  Widget build(BuildContext context) {
    if (destinations.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Text(title, style: AppTextStyles.sectionTitle),
                ),
                if (showSeeMore)
                  Text('Ver Mas', style: AppTextStyles.seeMore),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: cardWidth == 168 ? 191 : 173,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              physics: const ClampingScrollPhysics(),
              itemCount: destinations.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) => DestinationCard(
                destination: destinations[index],
                width: cardWidth,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Negocios Locales" row — businesses registered through the wizard and
/// persisted via [BusinessStorageService], always at least the seeded
/// sample so this section is never truly empty.
class _BusinessSection extends StatelessWidget {
  const _BusinessSection({required this.businesses, required this.onTap});

  final List<BusinessModel> businesses;
  final ValueChanged<BusinessModel> onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text('Negocios Locales', style: AppTextStyles.sectionTitle),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 191,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              physics: const ClampingScrollPhysics(),
              itemCount: businesses.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final business = businesses[index];
                return _BusinessCard(
                  business: business,
                  onTap: () => onTap(business),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BusinessCard extends StatelessWidget {
  const _BusinessCard({required this.business, required this.onTap});

  final BusinessModel business;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const width = 168.0;
    final imagePath = business.localImagePaths.isNotEmpty
        ? business.localImagePaths.first
        : null;

    return Semantics(
      button: true,
      label: '${business.name}, ${business.locationText}',
      child: Material(
        color: AppColors.surface100,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Ink(
            width: width,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x24FDBE02),
                  offset: Offset(0, 4),
                  blurRadius: 18,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  child: SizedBox(
                    height: 110,
                    width: double.infinity,
                    child: imagePath != null
                        ? Image.network(imagePath, fit: BoxFit.cover)
                        : ColoredBox(
                            color: AppColors.placeholderTan,
                            child: const Icon(
                              Icons.storefront_outlined,
                              color: AppColors.neutral500,
                            ),
                          ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        business.name,
                        style: AppTextStyles.cardTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            size: 10,
                            color: AppColors.neutral700,
                          ),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              business.locationText,
                              style: AppTextStyles.cardLocation,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        business.category,
                        style: AppTextStyles.cardPriceSuffix,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
