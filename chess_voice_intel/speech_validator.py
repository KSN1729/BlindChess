import chess
import re
from typing import Dict, Any, Tuple

# Pre-compiled regex patterns for maximum performance
FILE_REGEX = re.compile(r"\bfrom ([a-h])\b|\bon the ([a-h]) file\b|\bon ([a-h]) file\b|\b([a-h]) pawn\b")
RANK_REGEX = re.compile(r"\bfrom ([1-8])\b|\bon the ([1-8]) rank\b|\bon ([1-8]) rank\b")
SQUARE_REGEX = re.compile(r"\b[a-h][1-8]\b")

Q_REGEX = re.compile(r"\bq\b")
R_REGEX = re.compile(r"\br\b")
B_REGEX = re.compile(r"\bb\b")
N_REGEX = re.compile(r"\bn\b")

class SpeechValidator:
    """
    Semantic parser and validator mapping spoken text commands back to unique chess moves.
    """

    @staticmethod
    def parse_command(spoken_text: str) -> Dict[str, Any]:
        text = spoken_text.lower().strip()
        # 1. Map homophones like night to knight
        text = text.replace("night", "knight")

        # 2. Phonetic square translations
        if any(p in text for p in ["alpha", "bravo", "charlie", "delta", "echo", "foxtrot", "golf", "hotel", "one", "two", "three", "four", "five", "six", "seven", "eight", "see", "sea", "bee", "dee", "gee", "aitch"]):
            phonetics = {
                "alpha": "a", "bravo": "b", "charlie": "c", "delta": "d",
                "echo": "e", "foxtrot": "f", "golf": "g", "hotel": "h",
                "one": "1", "two": "2", "three": "3", "four": "4",
                "five": "5", "six": "6", "seven": "7", "eight": "8",
                "see": "c", "sea": "c",
                "bee": "b", "dee": "d", "gee": "g", "aitch": "h"
            }
            for phon, replacement in phonetics.items():
                text = text.replace(phon, replacement)

        # Remove spacing or hyphens between coordinate file and rank
        text = re.sub(r"\b([a-h])\s*[- ]\s*([1-8])\b", r"\1\2", text)

        # Find all [a-h][1-8] occurrences
        squares = SQUARE_REGEX.findall(text)

        # 3. Castling flags
        is_castling = False
        castling_type = None
        if "castle" in text and not squares:
            is_castling = True
            if "kingside" in text or "short" in text:
                castling_type = "kingside"
            elif "queenside" in text or "long" in text:
                castling_type = "queenside"

        # 3. Disambiguation file and rank markers
        start_file = None
        start_rank = None

        file_match = FILE_REGEX.search(text)
        if file_match:
            start_file = next(g for g in file_match.groups() if g is not None)

        rank_match = RANK_REGEX.search(text)
        if rank_match:
            start_rank = next(g for g in rank_match.groups() if g is not None)

        # 4. Promotion Target Extraction
        promotion_piece = None
        is_promo_command = any(k in text for k in ["promote", "promoting", "promotion", "make it a", "="])
        
        if is_promo_command:
            if "queen" in text or Q_REGEX.search(text):
                promotion_piece = chess.QUEEN
            elif "rook" in text or R_REGEX.search(text):
                promotion_piece = chess.ROOK
            elif "bishop" in text or B_REGEX.search(text):
                promotion_piece = chess.BISHOP
            elif "knight" in text or N_REGEX.search(text):
                promotion_piece = chess.KNIGHT

        # Strip promotion words if it is a promotion command to avoid misidentifying the moving piece
        moving_piece_text = text
        if is_promo_command:
            for word in ["queen", "rook", "bishop", "knight", "q", "r", "b", "n"]:
                moving_piece_text = re.sub(rf"\b{word}\b", "", moving_piece_text)

        # 5. Piece identification
        piece_type = None
        if "queen" in moving_piece_text:
            piece_type = chess.QUEEN
        elif "rook" in moving_piece_text or "castle" in moving_piece_text:
            if not is_castling:
                piece_type = chess.ROOK
        elif "bishop" in moving_piece_text:
            piece_type = chess.BISHOP
        elif "knight" in moving_piece_text or "horse" in moving_piece_text:
            piece_type = chess.KNIGHT
        elif "king" in moving_piece_text:
            piece_type = chess.KING
        elif "pawn" in moving_piece_text:
            piece_type = chess.PAWN

        # Determine destination square
        dest_square = None
        if squares:
            dest_square = squares[-1]
            if len(squares) > 1 and not start_file and not start_rank:
                # E.g. "move from g1 to f3" -> first square is starting position
                start_file = squares[0][0]
                start_rank = squares[0][1]

        return {
            "is_castling": is_castling,
            "castling_type": castling_type,
            "piece_type": piece_type,
            "start_file": start_file,
            "start_rank": start_rank,
            "dest_square": dest_square,
            "promotion_piece": promotion_piece,
            "is_capture": any(v in text for v in ["take", "capture", "takes", "captures"])
        }

    @staticmethod
    def validate_and_resolve(board: chess.Board, spoken_text: str, moves_by_dest: Dict[str, Any] = None) -> Tuple[bool, str, str]:
        """
        Resolves a spoken command to exactly one legal move in the board state.
        Supports passing pre-indexed moves_by_dest dict to skip full legal moves search.
        Returns (is_valid, error_reason, resolved_move_uci).
        """
        parsed = SpeechValidator.parse_command(spoken_text)
        matching_moves = []
        
        # 1. Gather candidate moves
        if parsed["is_castling"]:
            candidates = [m for m in board.legal_moves if board.is_castling(m)]
        elif parsed["dest_square"]:
            if moves_by_dest is not None:
                candidates = moves_by_dest.get(parsed["dest_square"], [])
            else:
                candidates = [m for m in board.legal_moves if chess.square_name(m.to_square) == parsed["dest_square"]]
        else:
            candidates = []
        
        for move in candidates:
            # 2. Piece type match
            from_sq = move.from_square
            piece = board.piece_at(from_sq)
            if not piece:
                continue
            if parsed["piece_type"] and piece.piece_type != parsed["piece_type"]:
                continue

            # 3. Starting file disambiguation match
            if parsed["start_file"]:
                file_char = chess.FILE_NAMES[chess.square_file(from_sq)]
                if file_char != parsed["start_file"]:
                    continue

            # 4. Starting rank disambiguation match
            if parsed["start_rank"]:
                rank_char = chess.RANK_NAMES[chess.square_rank(from_sq)]
                if rank_char != parsed["start_rank"]:
                    continue

            # 5. Promotion match
            if parsed["promotion_piece"]:
                if not move.promotion or move.promotion != parsed["promotion_piece"]:
                    continue
            else:
                if move.promotion:
                    # If move requires promotion but command did not specify one, skip
                    continue

            matching_moves.append(move)

        if len(matching_moves) == 0:
            return False, "Command does not match any legal move", ""
        elif len(matching_moves) > 1:
            # Ambiguity resolution: default to pawn moves if piece is not explicitly specified
            pawns_only = [m for m in matching_moves if board.piece_at(m.from_square).piece_type == chess.PAWN]
            if len(pawns_only) == 1 and not parsed["piece_type"]:
                return True, "", pawns_only[0].uci()
            return False, f"Command is ambiguous: matches {len(matching_moves)} moves {[board.san(m) for m in matching_moves]}", ""

        return True, "", matching_moves[0].uci()
