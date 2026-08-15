import 'package:flutter/foundation.dart';

/// Lets any screen — even one pushed on top of `MainLayout` via
/// `Navigator.push` (like `BusinessDetailScreen`), not just its 4 direct
/// tab children — request a bottom-nav tab switch without needing a
/// `BuildContext`/callback reference back to `MainLayout`'s State.
class MainTabController {
  factory MainTabController() => instance;

  MainTabController._internal();

  static final MainTabController instance = MainTabController._internal();

  /// `MainLayout` listens to this and resets it back to null once
  /// consumed — null means "no pending request".
  final ValueNotifier<int?> requestedTab = ValueNotifier(null);

  void switchTo(int index) => requestedTab.value = index;
}
