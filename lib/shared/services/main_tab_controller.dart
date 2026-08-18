import 'package:flutter/foundation.dart';

/// Permite pedir un cambio de tab del bottom-nav desde cualquier pantalla (incluso una pushed sobre `MainLayout`) sin un `BuildContext` de vuelta a su State.
class MainTabController {
  factory MainTabController() => instance;

  MainTabController._internal();

  static final MainTabController instance = MainTabController._internal();

  /// `MainLayout` lo resetea a null una vez consumido.
  final ValueNotifier<int?> requestedTab = ValueNotifier(null);

  void switchTo(int index) => requestedTab.value = index;
}
