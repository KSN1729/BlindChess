import '../models/chess_piece.dart';

/// Returns a high-aesthetic custom piece SVG vector string.
///
/// [Piece Color Theming Wiring Explanations]
/// This color-theming system is wired dynamically from the settings down to rendering:
/// 1. SettingsService holds a value notifier for boardThemeNotifier, which tracks the active theme (wood/ocean/slate).
/// 2. When a player toggles the theme in the Settings panel, SettingsService notifies the visual layer.
/// 3. ChessSquare builds itself by reading the current theme via SettingsService.instance.boardTheme.
/// 4. ChessSquare calls getPieceSvg(type, color, theme), which resolves the precise stroke and fill
///    hex color codes to match the selected board theme (Wood: brown/cream, Ocean: navy/white, Slate: charcoal/white)
///    while preserving clear white/black piece visibility contrast.
String getPieceSvg(PieceType type, PieceColor color, String boardTheme) {
  final isWhite = color == PieceColor.white;
  String strokeColor;
  String fillColor;

  switch (boardTheme) {
    case 'classic_wood':
      // Wood theme: rich warm brown and soft cream
      if (isWhite) {
        strokeColor = '#78350F'; // Warm brown outline
        fillColor = '#FEF3C7'; // Soft cream fill
      } else {
        strokeColor = '#451A03'; // Dark brown outline
        fillColor = '#78350F'; // Dark warm brown fill
      }
      break;
    case 'ocean_blue':
      // Ocean theme: deep navy and soft sky-blue-white
      if (isWhite) {
        strokeColor = '#0369A1'; // Deep sky blue outline
        fillColor = '#F0F9FF'; // Ice blue-white fill
      } else {
        strokeColor = '#0C4A6E'; // Navy outline
        fillColor = '#0369A1'; // Deep blue fill
      }
      break;
    case 'slate_grey':
    default:
      // Slate/Charcoal theme: charcoal and cool grey-white
      if (isWhite) {
        strokeColor = '#374151'; // Charcoal outline
        fillColor = '#F9FAFB'; // Cool white fill
      } else {
        strokeColor = '#111827'; // Dark charcoal outline
        fillColor = '#4B5563'; // Dark slate fill
      }
      break;
  }

  switch (type) {
    case PieceType.pawn:
      return '''
<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
  <circle cx="50" cy="32" r="13" fill="$fillColor" stroke="$strokeColor" stroke-width="4"/>
  <path d="M 36 78 C 36 50 64 50 64 78 Z" fill="$fillColor" stroke="$strokeColor" stroke-width="4" stroke-linejoin="round"/>
  <line x1="28" y1="78" x2="72" y2="78" stroke="$strokeColor" stroke-width="6" stroke-linecap="round"/>
</svg>
''';

    case PieceType.knight:
      return '''
<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
  <path d="M 33 78 
           C 33 78 30 55 42 43 
           C 42 43 38 38 33 40 
           C 30 41 28 35 34 30 
           C 40 25 50 20 60 28 
           C 68 34 68 45 68 55 
           C 68 62 58 70 58 78 Z" 
        fill="$fillColor" stroke="$strokeColor" stroke-width="4" stroke-linejoin="round"/>
  <circle cx="50" cy="36" r="3.5" fill="$strokeColor"/>
  <line x1="26" y1="78" x2="74" y2="78" stroke="$strokeColor" stroke-width="6" stroke-linecap="round"/>
</svg>
''';

    case PieceType.bishop:
      return '''
<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
  <path d="M 50 22 C 37 38 37 58 37 78 L 63 78 C 63 58 63 38 50 22 Z" fill="$fillColor" stroke="$strokeColor" stroke-width="4" stroke-linejoin="round"/>
  <circle cx="50" cy="16" r="4.5" fill="$fillColor" stroke="$strokeColor" stroke-width="3"/>
  <line x1="50" y1="32" x2="42" y2="42" stroke="$strokeColor" stroke-width="4.5" stroke-linecap="round"/>
  <line x1="28" y1="78" x2="72" y2="78" stroke="$strokeColor" stroke-width="6" stroke-linecap="round"/>
</svg>
''';

    case PieceType.rook:
      return '''
<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
  <path d="M 32 78 L 32 45 L 36 45 L 36 32 L 42 32 L 42 38 L 50 38 L 50 32 L 58 32 L 58 38 L 64 38 L 64 32 L 68 32 L 68 45 L 72 45 L 72 78 Z" fill="$fillColor" stroke="$strokeColor" stroke-width="4" stroke-linejoin="round"/>
  <line x1="24" y1="78" x2="76" y2="78" stroke="$strokeColor" stroke-width="6" stroke-linecap="round"/>
</svg>
''';

    case PieceType.queen:
      return '''
<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
  <path d="M 28 78 L 18 42 L 36 62 L 50 32 L 64 62 L 82 42 L 72 78 Z" fill="$fillColor" stroke="$strokeColor" stroke-width="4" stroke-linejoin="round"/>
  <circle cx="18" cy="38" r="3.5" fill="$fillColor" stroke="$strokeColor" stroke-width="2.5"/>
  <circle cx="36" cy="58" r="3" fill="$fillColor" stroke="$strokeColor" stroke-width="2"/>
  <circle cx="50" cy="28" r="3.5" fill="$fillColor" stroke="$strokeColor" stroke-width="2.5"/>
  <circle cx="64" cy="58" r="3" fill="$fillColor" stroke="$strokeColor" stroke-width="2"/>
  <circle cx="82" cy="38" r="3.5" fill="$fillColor" stroke="$strokeColor" stroke-width="2.5"/>
  <line x1="22" y1="78" x2="78" y2="78" stroke="$strokeColor" stroke-width="6" stroke-linecap="round"/>
</svg>
''';

    case PieceType.king:
      return '''
<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
  <path d="M 32 78 C 26 48 36 34 50 34 C 64 34 74 48 68 78 Z" fill="$fillColor" stroke="$strokeColor" stroke-width="4" stroke-linejoin="round"/>
  <path d="M 50 14 L 50 34 M 40 22 L 60 22" stroke="$strokeColor" stroke-width="5" stroke-linecap="round"/>
  <line x1="24" y1="78" x2="76" y2="78" stroke="$strokeColor" stroke-width="6" stroke-linecap="round"/>
</svg>
''';
  }
}
