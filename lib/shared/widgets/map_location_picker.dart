import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:nikara_app/theme/app_theme.dart';

/// Managua — centro por defecto de todo mapa de la app hasta que se resuelve
/// la ubicación real del usuario.
const LatLng kNikaraMapCenter = LatLng(12.1363, -86.2513);

/// Caja generosa alrededor de Nicaragua: evita que el usuario se pierda
/// arrastrando hasta otro continente, sin recortar la frontera.
final LatLngBounds kNikaraMapBounds = LatLngBounds(
  southwest: const LatLng(7.0, -92.0),
  northeast: const LatLng(18.5, -77.0),
);

/// Mapa interactivo para elegir un punto exacto: el pin está fijo en el centro
/// y lo que se mueve es el mapa, así que la coordenada elegida es siempre el
/// centro de la cámara ([onCameraMove]) — no depende del GPS.
///
/// Lo comparten `RegisterBusinessWizard` (paso "Ubicación") y
/// `CreateEcoActivityScreen`; nació en el wizard y se extrajo aquí al
/// necesitarlo también el formulario ECO.
class MapLocationPicker extends StatelessWidget {
  const MapLocationPicker({
    super.key,
    required this.initialCenter,
    required this.onMapCreated,
    required this.onCameraMove,
    required this.onTap,
    required this.onZoomIn,
    required this.onZoomOut,
    this.height = 190,
  });

  final LatLng initialCenter;
  final ValueChanged<GoogleMapController> onMapCreated;
  final ValueChanged<LatLng> onCameraMove;
  final ValueChanged<LatLng> onTap;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: initialCenter,
                zoom: 15,
              ),
              onMapCreated: onMapCreated,
              onCameraMove: (position) => onCameraMove(position.target),
              onTap: onTap,
              minMaxZoomPreference: const MinMaxZoomPreference(6, 18),
              cameraTargetBounds: CameraTargetBounds(kNikaraMapBounds),
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              myLocationButtonEnabled: false,
              compassEnabled: false,
            ),
            IgnorePointer(
              child: Center(
                child: Transform.translate(
                  offset: const Offset(0, -22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: AppColors.primary500,
                          shape: BoxShape.circle,
                          border: Border.fromBorderSide(
                            BorderSide(color: AppColors.surface100, width: 3),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.wizardPhotoShadow,
                              offset: Offset(0, 6),
                              blurRadius: 14,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.location_on,
                          size: 22,
                          color: AppColors.settingsTextDark,
                        ),
                      ),
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(top: 4),
                        decoration: BoxDecoration(
                          color: AppColors.settingsTextDark.withValues(
                            alpha: 0.22,
                          ),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 10,
              bottom: 10,
              child: Column(
                children: [
                  _mapButton(Icons.add, onZoomIn),
                  const SizedBox(height: 6),
                  _mapButton(Icons.remove, onZoomOut),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mapButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surface100,
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [
            BoxShadow(
              color: AppColors.mapCardShadow,
              offset: Offset(0, 2),
              blurRadius: 8,
            ),
          ],
        ),
        child: Icon(icon, size: 17, color: AppColors.settingsTextDark),
      ),
    );
  }
}
