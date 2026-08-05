/// One rung of the level ladder — a name plus the minimum points required
/// to reach it.
class _LevelThreshold {
  const _LevelThreshold(this.minPoints, this.name);

  final int minPoints;
  final String name;
}

/// Computed progression snapshot for a given point total.
class LevelInfo {
  const LevelInfo({
    required this.points,
    required this.currentLevelName,
    required this.nextLevelName,
    required this.levelMinPoints,
    required this.nextLevelMinPoints,
    required this.progress,
    required this.pointsToNext,
    required this.isMaxLevel,
  });

  final int points;
  final String currentLevelName;

  /// Null once [isMaxLevel] is true — there's nothing further to reach.
  final String? nextLevelName;
  final int levelMinPoints;
  final int? nextLevelMinPoints;

  /// 0.0–1.0 progress towards [nextLevelName].
  final double progress;
  final int pointsToNext;
  final bool isMaxLevel;
}

/// Turns a raw point total into a level name, progress percentage and
/// points-remaining figure — the single source of truth for Nikara's
/// gamification ladder.
abstract class GamificationEngine {
  static const List<_LevelThreshold> _levels = [
    _LevelThreshold(0, 'Explorador Novato'),
    _LevelThreshold(200, 'Explorador Eco'),
    _LevelThreshold(1000, 'Guardián del Territorio'),
  ];

  static LevelInfo calculate(int points) {
    final safePoints = points < 0 ? 0 : points;

    var currentIndex = 0;
    for (var i = 0; i < _levels.length; i++) {
      if (safePoints >= _levels[i].minPoints) currentIndex = i;
    }

    final current = _levels[currentIndex];
    final isMaxLevel = currentIndex == _levels.length - 1;
    final next = isMaxLevel ? null : _levels[currentIndex + 1];

    final progress = isMaxLevel
        ? 1.0
        : ((safePoints - current.minPoints) /
                  (next!.minPoints - current.minPoints))
              .clamp(0.0, 1.0);

    return LevelInfo(
      points: safePoints,
      currentLevelName: current.name,
      nextLevelName: next?.name,
      levelMinPoints: current.minPoints,
      nextLevelMinPoints: next?.minPoints,
      progress: progress,
      pointsToNext: isMaxLevel ? 0 : next!.minPoints - safePoints,
      isMaxLevel: isMaxLevel,
    );
  }
}
