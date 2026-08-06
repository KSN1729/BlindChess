/// Configuration options representing base times and incremental gains for game timers.
class ChessClockConfig {
  final String label;
  final int baseSeconds;
  final int incrementSeconds;
  final bool hasTimer;

  const ChessClockConfig({
    required this.label,
    required this.baseSeconds,
    required this.incrementSeconds,
    this.hasTimer = true,
  });

  /// Static clock presets.
  static const noTimer = ChessClockConfig(
    label: 'No Timer',
    baseSeconds: 0,
    incrementSeconds: 0,
    hasTimer: false,
  );

  static const bullet1 = ChessClockConfig(
    label: 'Bullet 1+0',
    baseSeconds: 60,
    incrementSeconds: 0,
  );

  static const bullet2 = ChessClockConfig(
    label: 'Bullet 2+1',
    baseSeconds: 120,
    incrementSeconds: 1,
  );

  static const blitz3 = ChessClockConfig(
    label: 'Blitz 3+0',
    baseSeconds: 180,
    incrementSeconds: 0,
  );

  static const blitz3Increment = ChessClockConfig(
    label: 'Blitz 3+2',
    baseSeconds: 180,
    incrementSeconds: 2,
  );

  static const blitz5 = ChessClockConfig(
    label: 'Blitz 5+0',
    baseSeconds: 300,
    incrementSeconds: 0,
  );

  static const blitz5Increment = ChessClockConfig(
    label: 'Blitz 5+3',
    baseSeconds: 300,
    incrementSeconds: 3,
  );

  static const rapid10 = ChessClockConfig(
    label: 'Rapid 10+0',
    baseSeconds: 600,
    incrementSeconds: 0,
  );

  static const rapid15 = ChessClockConfig(
    label: 'Rapid 15+10',
    baseSeconds: 900,
    incrementSeconds: 10,
  );

  static const classical30 = ChessClockConfig(
    label: 'Classical 30+0',
    baseSeconds: 1800,
    incrementSeconds: 0,
  );

  static const classical90 = ChessClockConfig(
    label: 'Classical 90+30',
    baseSeconds: 5400,
    incrementSeconds: 30,
  );

  /// Helper list containing all standard preset timers.
  static const List<ChessClockConfig> presets = [
    noTimer,
    bullet1,
    bullet2,
    blitz3,
    blitz3Increment,
    blitz5,
    blitz5Increment,
    rapid10,
    rapid15,
    classical30,
    classical90,
  ];
}
