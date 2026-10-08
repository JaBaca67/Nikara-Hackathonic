import 'package:flutter/material.dart';
import '../../domain/models/route_stop_model.dart';
import '../widgets/route_mini_map.dart';
import 'package:nikara_app/theme/app_theme.dart';

class RouteOverviewScreen extends StatefulWidget {
  const RouteOverviewScreen({
    super.key,
    required this.title,
    required this.stops,
  });
  final String title;
  final List<RouteStopModel> stops;
  @override
  State<RouteOverviewScreen> createState() => _RouteOverviewScreenState();
}

class _RouteOverviewScreenState extends State<RouteOverviewScreen> {
  late int _day = widget.stops.isEmpty ? 1 : widget.stops.first.dayNumber;
  @override
  Widget build(BuildContext context) {
    final days = widget.stops.map((s) => s.dayNumber).toSet().toList()..sort();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          widget.title,
          style: AppTextStyles.sectionTitle.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  for (final day in days)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text('Día $day'),
                        selected: day == _day,
                        onSelected: (_) => setState(() => _day = day),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => Padding(
                  padding: const EdgeInsets.all(12),
                  child: RouteMiniMap(
                    stops: widget.stops
                        .where((s) => s.dayNumber == _day)
                        .toList(),
                    interactive: true,
                    height: (constraints.maxHeight - 180).clamp(180.0, 800.0),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
