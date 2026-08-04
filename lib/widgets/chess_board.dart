import 'package:flutter/material.dart';
import '../models/chess_piece.dart';
import '../services/chess_engine_service.dart';
import '../services/settings_service.dart';
import 'chess_square.dart';

/// A reusable ChessBoard widget that renders an 8x8 grid.
/// Can be configured in interactive mode or read-only mode.
class ChessBoard extends StatelessWidget {
  final ChessEngineService chessEngineService;
  final bool isWhitePerspective;
  final bool shouldHidePieces;
  final List<(int row, int col)> highlightedSquares;
  final (int row, int col)? lastMoveStart;
  final (int row, int col)? lastMoveEnd;
  final (int row, int col)? checkedKingCoords;
  final String? selectedSquare;
  final Map<(int, int), String?>? flashStates;
  final bool readOnly;

  /// Callback when a square is tapped. Only invoked if [readOnly] is false.
  final Function(int row, int col, String label)? onSquareTap;

  const ChessBoard({
    super.key,
    required this.chessEngineService,
    this.isWhitePerspective = true,
    this.shouldHidePieces = false,
    this.highlightedSquares = const [],
    this.lastMoveStart,
    this.lastMoveEnd,
    this.checkedKingCoords,
    this.selectedSquare,
    this.flashStates,
    this.readOnly = false,
    this.onSquareTap,
  });

  /// Dynamically computes light/dark square colors based on Board Theme selection.
  Color getSquareColor(
    int rankIndex,
    int fileIndex,
    bool isHighlighted,
    bool isLastMove,
  ) {
    final isDark = (rankIndex + fileIndex) % 2 != 0;
    Color baseColor;

    switch (SettingsService.instance.boardTheme) {
      case 'classic_wood':
        baseColor = isDark ? const Color(0xFFB58863) : const Color(0xFFF0D9B5);
        break;
      case 'ocean_blue':
        baseColor = isDark ? const Color(0xFF0284C7) : const Color(0xFFE0F2FE);
        break;
      case 'slate_grey':
      default:
        baseColor = isDark ? const Color(0xFF475569) : const Color(0xFFF1F5F9);
        break;
    }

    // Blend last-move highlights (subtle yellow tint)
    if (isLastMove) {
      baseColor = Color.lerp(baseColor, Colors.yellow, 0.15) ?? baseColor;
    }

    // Blend legal-move highlights (green tint)
    if (isHighlighted) {
      baseColor = Color.lerp(baseColor, Colors.green, 0.3) ?? baseColor;
    }

    return baseColor;
  }

  String getPieceName(ChessPiece? piece) {
    if (piece == null) return 'Empty';
    switch (piece.pieceType) {
      case PieceType.king:
        return 'King';
      case PieceType.queen:
        return 'Queen';
      case PieceType.rook:
        return 'Rook';
      case PieceType.bishop:
        return 'Bishop';
      case PieceType.knight:
        return 'Knight';
      case PieceType.pawn:
        return 'Pawn';
    }
  }

  bool isWhitePiece(ChessPiece? piece) {
    return piece?.pieceColor == PieceColor.white;
  }

  @override
  Widget build(BuildContext context) {
    final files = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'];

    return AspectRatio(
      aspectRatio: 1.0,
      child: Column(
        children: List.generate(8, (rankIndex) {
          final actualRowIndex = isWhitePerspective ? rankIndex : 7 - rankIndex;
          final rank = 8 - actualRowIndex;

          return Expanded(
            child: Row(
              children: List.generate(8, (fileIndex) {
                final actualColIndex = isWhitePerspective
                    ? fileIndex
                    : 7 - fileIndex;
                final file = files[actualColIndex];
                final label = '$file$rank';

                final isHighlighted =
                    !readOnly &&
                    highlightedSquares.contains((
                      actualRowIndex,
                      actualColIndex,
                    ));
                final isLastMove =
                    (lastMoveStart != null &&
                        lastMoveStart == (actualRowIndex, actualColIndex)) ||
                    (lastMoveEnd != null &&
                        lastMoveEnd == (actualRowIndex, actualColIndex));
                final squareColor = getSquareColor(
                  rankIndex,
                  fileIndex,
                  isHighlighted,
                  isLastMove,
                );

                final piece = chessEngineService.pieceAt(
                  actualRowIndex,
                  actualColIndex,
                );

                final isKingInCheck =
                    checkedKingCoords != null &&
                    checkedKingCoords == (actualRowIndex, actualColIndex);

                return Expanded(
                  child: ChessSquare(
                    squareColor: squareColor,
                    label: label,
                    isSelected: !readOnly && selectedSquare == label,
                    piece: piece,
                    pieceName: getPieceName(piece),
                    isWhitePiece: isWhitePiece(piece),
                    isCheck: isKingInCheck,
                    isPieceHidden: shouldHidePieces,
                    flashState: flashStates?[(actualRowIndex, actualColIndex)],
                    onTap: readOnly
                        ? null
                        : () => onSquareTap?.call(
                            actualRowIndex,
                            actualColIndex,
                            label,
                          ),
                  ),
                );
              }),
            ),
          );
        }),
      ),
    );
  }
}
