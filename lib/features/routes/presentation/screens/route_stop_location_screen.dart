import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:nikara_app/features/map/presentation/widgets/map_style.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// User-selected entrance for an unlocated itinerary stop, saved only on this route.
class RouteStopLocationScreen extends StatefulWidget {
  const RouteStopLocationScreen({super.key, required this.title});
  final String title;
  @override
  State<RouteStopLocationScreen> createState() =>
      _RouteStopLocationScreenState();
}

class _RouteStopLocationScreenState extends State<RouteStopLocationScreen> {
  LatLng? _selected;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        'Ubicar parada',
        style: AppTextStyles.sectionTitle.copyWith(
          color: AppColors.textPrimary,
        ),
      ),
    ),
    body: SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.title, style: AppTextStyles.mapRowTitle),
                const SizedBox(height: 6),
                Text(
                  'Acerca el mapa y toca la entrada del lugar que conoces. Este punto se guardará en tu itinerario.',
                  style: AppTextStyles.settingsSubtitle,
                ),
              ],
            ),
          ),
          Expanded(
            child: GoogleMap(
              // Camera only; no marker exists until the user chooses a point.
              initialCameraPosition: const CameraPosition(
                target: LatLng(12.8654, -85.2072),
                zoom: 6,
              ),
              style: nikaraMapStyle,
              onTap: (point) => setState(() => _selected = point),
              onLongPress: (point) => setState(() => _selected = point),
              markers: {
                if (_selected != null)
                  Marker(
                    markerId: const MarkerId('chosen-entrance'),
                    position: _selected!,
                    infoWindow: InfoWindow(title: widget.title),
                  ),
              },
              mapToolbarEnabled: false,
              myLocationButtonEnabled: false,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.icon(
              onPressed: _selected == null
                  ? null
                  : () => Navigator.of(context).pop(_selected),
              icon: const Icon(Icons.check_rounded),
              label: const Text('Usar esta ubicación'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary500,
                foregroundColor: AppColors.textPrimary,
                minimumSize: const Size.fromHeight(52),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
