import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'package:nikara_app/theme/app_theme.dart';

/// Renderiza una imagen de `image_picker` (path real en mobile/desktop, `blob:` en web) o una URL http(s), con fallback si falta/falla la carga.
class LocalImage extends StatefulWidget {
  const LocalImage({
    super.key,
    required this.path,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.fallbackIcon = Icons.image_outlined,
    this.fallbackIconSize = 28,
  });

  final String? path;
  final BoxFit fit;

  /// Qué parte se conserva al recortar con [BoxFit.cover]. Las fotos de perfil
  /// usan un encuadre más alto que el centro, donde suele estar la cara.
  final Alignment alignment;
  final IconData fallbackIcon;
  final double fallbackIconSize;

  @override
  State<LocalImage> createState() => _LocalImageState();
}

class _LocalImageState extends State<LocalImage> with WidgetsBindingObserver {
  Timer? _retryTimer;
  int _attempt = 0;
  bool _retryPending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final path = widget.path;
    if (state == AppLifecycleState.resumed && _attempt >= 2 && path != null) {
      unawaited(_retry(path, manual: true));
    }
  }

  @override
  void didUpdateWidget(covariant LocalImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _retryTimer?.cancel();
      _retryPending = false;
      _attempt = 0;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _retryTimer?.cancel();
    super.dispose();
  }

  void _scheduleRetry(String path) {
    if (_retryPending || _attempt >= 2) return;
    _retryPending = true;
    _retryTimer = Timer(Duration(seconds: _attempt + 1), () => _retry(path));
  }

  Future<void> _retry(String path, {bool manual = false}) async {
    if (!mounted || widget.path != path) return;
    // Evict before rebuilding: a new Image widget can otherwise reuse the
    // same failed request. The URL and public access remain unchanged.
    await NetworkImage(path).evict();
    if (!mounted || widget.path != path) return;
    setState(() {
      _retryPending = false;
      _attempt = manual ? 0 : _attempt + 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final imagePath = widget.path;
    if (imagePath == null || imagePath.isEmpty) return _fallback();
    final isRemote =
        imagePath.startsWith('http://') || imagePath.startsWith('https://');
    if (!kIsWeb && !isRemote && !File(imagePath).existsSync()) {
      return _fallback();
    }

    return kIsWeb || isRemote
        ? Image.network(
            imagePath,
            key: ValueKey((imagePath, _attempt)),
            width: double.infinity,
            height: double.infinity,
            fit: widget.fit,
            alignment: widget.alignment,
            // `frameBuilder`, no `loadingBuilder`: este último solo reacciona
            // a los bytes de descarga, así que en una imagen ya en la caché
            // HTTP o que llega completa en un solo chunk nunca pasa por
            // "cargando" — hay un frame en blanco entre que el `Image` se
            // monta y el primer frame decodificado se pinta. `frameBuilder`
            // cubre ese hueco porque se dispara según frames decodificados,
            // no bytes de red. Encontrado al reemplazar el logo de una
            // fundación ya publicada: el círculo se veía blanco un instante
            // justo después de guardar, como si no hubiera guardado nada.
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) =>
                wasSynchronouslyLoaded || frame != null
                ? child
                : _placeholder(),
            errorBuilder: (context, error, stackTrace) {
              _scheduleRetry(imagePath);
              return _attempt < 2 ? _placeholder() : _failedImage(imagePath);
            },
          )
        : Image.file(
            File(imagePath),
            width: double.infinity,
            height: double.infinity,
            fit: widget.fit,
            alignment: widget.alignment,
            errorBuilder: (context, error, stackTrace) => _fallback(),
          );
  }

  Widget _placeholder() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: AppColors.placeholderTan,
      alignment: Alignment.center,
      child: const SizedBox.square(
        dimension: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.oliveText,
        ),
      ),
    );
  }

  Widget _failedImage(String path) => Container(
    color: AppColors.placeholderTan,
    alignment: Alignment.center,
    child: IconButton(
      tooltip: 'Reintentar foto',
      onPressed: () => _retry(path, manual: true),
      icon: const Icon(Icons.refresh_rounded, color: AppColors.oliveText),
    ),
  );

  Widget _fallback() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: AppColors.placeholderTan,
      alignment: Alignment.center,
      child: Icon(
        widget.fallbackIcon,
        size: widget.fallbackIconSize,
        color: AppColors.neutral500,
      ),
    );
  }
}
