import 'package:flutter/material.dart';

/// Envuelve una tab del bottom-nav para que un `PageView` la mantenga
/// montada aunque quede fuera de pantalla — el mismo comportamiento que
/// `MainLayout` tenía gratis con `IndexedStack`. Sin esto, cada tab perdería
/// su scroll y repetiría su carga de Supabase/geolocalización cada vez que
/// se vuelve a ella deslizando (ver el comentario en el `initState` de
/// `HomeScreen`, que ya depende hoy de quedar siempre montada).
class KeepAliveTab extends StatefulWidget {
  const KeepAliveTab({super.key, required this.child});

  final Widget child;

  @override
  State<KeepAliveTab> createState() => _KeepAliveTabState();
}

class _KeepAliveTabState extends State<KeepAliveTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
