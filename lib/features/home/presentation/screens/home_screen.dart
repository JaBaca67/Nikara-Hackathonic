import 'package:flutter/material.dart';

import 'package:nikara_app/features/home/data/mock_destinations.dart';
import 'package:nikara_app/features/home/domain/models/destination.dart';
import 'package:nikara_app/features/home/presentation/widgets/bottom_nav_bar_widget.dart';
import 'package:nikara_app/features/home/presentation/widgets/destination_card.dart';
import 'package:nikara_app/features/home/presentation/widgets/featured_destination_card.dart';
import 'package:nikara_app/features/home/presentation/widgets/search_header_widget.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Home / "Inicio" screen (Figma node 124:37). Assembles the header, the
/// featured hero card, "Más visitados" and the "Por región" groups from
/// [mockDestinations] — swapping that constant for a repository later
/// requires no changes here.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

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
      bottomNavigationBar: const BottomNavBarWidget(),
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
