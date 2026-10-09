import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Ajusta el dock a la tarjeta activa. Las tarjetas que asoman por los
/// bordes no deben conservar el espacio de una selección anterior.
class MapCarousel extends StatefulWidget {
  const MapCarousel({
    super.key,
    required this.controller,
    required this.children,
  });

  final PageController controller;
  final List<Widget> children;

  @override
  State<MapCarousel> createState() => _MapCarouselState();
}

class _MapCarouselState extends State<MapCarousel> {
  final Map<Key, double> _heights = {};
  bool _updateScheduled = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_scheduleUpdate);
  }

  @override
  void didUpdateWidget(MapCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_scheduleUpdate);
      widget.controller.addListener(_scheduleUpdate);
    }
    final keys = widget.children.map((child) => child.key).toSet();
    _heights.removeWhere((key, _) => !keys.contains(key));
  }

  @override
  void dispose() {
    widget.controller.removeListener(_scheduleUpdate);
    super.dispose();
  }

  void _scheduleUpdate() {
    if (_updateScheduled) return;
    _updateScheduled = true;
    // Las medidas llegan durante layout; se agrupan para no reconstruir el
    // PageView mientras está calculando las dimensiones de sus páginas.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateScheduled = false;
      if (mounted) setState(() {});
    });
  }

  void _recordHeight(Key key, double height) {
    if (_heights[key] == height) return;
    _heights[key] = height;
    _scheduleUpdate();
  }

  double get _activeHeight {
    if (widget.children.isEmpty) return 0;
    final controller = widget.controller;
    var index = controller.initialPage;
    if (controller.hasClients && controller.position.hasContentDimensions) {
      index = controller.page?.round() ?? index;
    }
    index = index.clamp(0, widget.children.length - 1);
    return _heights[widget.children[index].key] ?? 1;
  }

  @override
  Widget build(BuildContext context) {
    assert(widget.controller.viewportFraction <= 1);
    assert(widget.children.every((child) => child.key != null));
    return SizedBox(
      height: _activeHeight,
      child: PageView.builder(
        controller: widget.controller,
        padEnds: false,
        itemCount: widget.children.length,
        findChildIndexCallback: (key) {
          final index = widget.children.indexWhere((child) => child.key == key);
          return index < 0 ? null : index;
        },
        itemBuilder: (context, index) {
          final child = widget.children[index];
          return OverflowBox(
            key: child.key,
            alignment: Alignment.bottomCenter,
            minHeight: 0,
            maxHeight: double.infinity,
            child: _CardHeightObserver(
              onHeightChanged: (height) => _recordHeight(child.key!, height),
              child: child,
            ),
          );
        },
      ),
    );
  }
}

class _CardHeightObserver extends SingleChildRenderObjectWidget {
  const _CardHeightObserver({
    required this.onHeightChanged,
    required super.child,
  });

  final ValueChanged<double> onHeightChanged;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderCardHeightObserver(onHeightChanged);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderCardHeightObserver renderObject,
  ) {
    renderObject.onHeightChanged = onHeightChanged;
  }
}

class _RenderCardHeightObserver extends RenderProxyBox {
  _RenderCardHeightObserver(this.onHeightChanged);

  ValueChanged<double> onHeightChanged;

  @override
  void performLayout() {
    super.performLayout();
    onHeightChanged(size.height);
  }
}
