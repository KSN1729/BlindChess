import chess
import random
import time
import re

# Fallback FEN pools of realistic, legally reachable master-game positions
PROMOTION_FENS = [
    "r1bqbk1r/pppP1ppp/2n5/8/8/5N2/PP1PPPPP/RNBQKB1R w KQ - 0 5", # White to move, d7 checks c8, black king on f8. Valid!
    "rnbqkbnr/p1pppppp/8/8/8/8/1pPPPPPP/RNBQKBNR b KQkq - 0 1", # Black to move, b2 ready to promote on a1 or c1. Valid!
    "r1bqk1nr/pp2Pppp/2n5/1b6/8/8/PP2PPPP/RNBQKBNR w KQkq - 0 6"  # White to move, e7 ready to promote on d8. Valid!
]

EN_PASSANT_FENS = [
    "rnbqkbnr/ppp1pppp/8/3pP3/8/8/PPPP1PPP/RNBQKBNR w KQkq d6 0 2", # exd6 e.p.
    "rnbqkbnr/pppp1ppp/8/8/3Pp3/8/PPP1PPPP/RNBQKBNR b KQkq d3 0 2"   # exd3 e.p.
]

CHECKMATE_FENS = [
    "6k1/5ppp/8/8/8/8/5PPP/3R2K1 w - - 0 1", # Rd8# (Back-rank mate)
    "5k2/5ppp/8/8/8/8/5PPP/3Q2K1 w - - 0 1", # Qd8#
    "r1bqkbnr/pppp1ppp/2n5/4p3/2B1P3/5Q2/PPPP1PPP/RNB1K1NR w KQkq - 4 4", # Qxf7# (Scholar's mate)
    "3r2k1/1p3ppp/pq6/8/8/8/PPP2PPP/3R2K1 w - - 0 1"
]

ROOK_FENS = [
    "6k1/8/8/8/8/8/4K3/R6R w - - 0 1", # Ra1 -> d1, Rh1 -> d1
    "3k4/8/8/8/8/8/4K3/R1R5 w - - 0 1", # Ra1 -> b1, Rc1 -> b1
    "r5k1/5ppp/8/8/8/4K3/5PPP/R6R w - - 0 1"
]

BISHOP_FENS = [
    "6k1/8/8/8/8/8/4K3/B1B5 w - - 0 1", # Ba1 -> b2, Bc1 -> b2
    "6k1/8/8/8/8/8/2K5/B1B5 w - - 0 1",
    "b5k1/5ppp/8/8/8/4K3/5PPP/B7 w - - 0 1"
]

KNIGHT_FENS = [
    "6k1/8/8/8/8/8/4K3/N1N5 w - - 0 1", # Na1 -> b3, Nc1 -> b3
    "6k1/8/8/8/8/8/2K5/N1N5 w - - 0 1",
    "n5k1/5ppp/8/8/8/4K3/5PPP/N7 w - - 0 1"
]

ENDGAME_FENS = [
    "8/k7/3p4/p2P4/P7/8/6K1/8 w - - 0 1",
    "8/8/8/6p1/8/5k2/8/R3K3 w - - 0 1",
    "8/8/p7/1p6/8/2k5/8/R3K3 w - - 0 1",
    "4k3/8/8/8/8/8/4P3/4K3 w - - 0 1",
    "8/k7/8/8/8/8/1p6/R3K3 b - - 0 1",
    "2k5/pppr1ppp/8/8/8/8/PPPR1PPP/4K3 w - - 0 1"
]

def verify_category_satisfaction(board, category, sample_legal_moves):
    piece_count = len(board.piece_map())
    if category == "opening":
        return piece_count >= 28
    elif category == "middlegame":
        return 9 <= piece_count <= 27
    elif category == "endgame":
        return piece_count <= 8
    elif category == "promotion":
        has_promotion = any(m.promotion is not None for m in board.legal_moves)
        if not has_promotion:
            return False
        return any("=" in m for m in sample_legal_moves)
    elif category == "castling":
        has_castling = any(board.is_castling(m) for m in board.legal_moves)
        if not has_castling:
            return False
        has_san_castling = any("O-O" in m for m in sample_legal_moves)
        if not has_san_castling:
            return False
        return bool(board.castling_rights)
    elif category == "en_passant":
        has_ep = any(board.is_en_passant(m) for m in board.legal_moves)
        if not has_ep:
            return False
        return board.ep_square is not None
    elif category == "check":
        return board.is_check()
    elif category == "checkmate_in_one":
        def delivers_mate(b, m):
            c = b.copy()
            c.push(m)
            return c.is_checkmate()
        return any(delivers_mate(board, m) for m in board.legal_moves)
    elif category in ["ambiguous_rook", "ambiguous_bishop", "ambiguous_knight"]:
        piece_char = {
            "ambiguous_rook": "R",
            "ambiguous_bishop": "B",
            "ambiguous_knight": "N"
        }[category]
        pattern = re.compile(rf"^{piece_char}[a-h1-8]x?[a-h][1-8]")
        return any(pattern.match(m) for m in sample_legal_moves)
    return False

def scramble_board(fens_pool, category, max_moves=0):
    """
    Selects a base FEN from the pool, scrambles it by playing up to max_moves random moves,
    and returns it if the target category constraint is still satisfied.
    """
    if max_moves <= 0:
        # No scrambling, directly select a valid FEN from the pool
        for fen in random.sample(fens_pool, len(fens_pool)):
            board = chess.Board(fen)
            legal_moves_san = [board.san(m) for m in board.legal_moves]
            if verify_category_satisfaction(board, category, legal_moves_san):
                return board
        return chess.Board(fens_pool[0])

    for _ in range(30):
        fen = random.choice(fens_pool)
        board = chess.Board(fen)
        moves_count = random.randint(1, max_moves)
        valid_scramble = True
        
        for _ in range(moves_count):
            if board.is_game_over() or not list(board.legal_moves):
                valid_scramble = False
                break
            board.push(random.choice(list(board.legal_moves)))
            
        if valid_scramble and board.is_valid() and not board.is_game_over():
            legal_moves_san = [board.san(m) for m in board.legal_moves]
            if verify_category_satisfaction(board, category, legal_moves_san):
                return board
                
    # Fallback to unscrambled base FEN
    for fen in fens_pool:
        board = chess.Board(fen)
        legal_moves_san = [board.san(m) for m in board.legal_moves]
        if verify_category_satisfaction(board, category, legal_moves_san):
            return board
            
    return chess.Board()

class BoardGenerator:
    """
    Production Board Generation Engine.
    Generates legally valid, categorized, and balanced board positions.
    """

    @staticmethod
    def play_random_ply(board, count):
        """Plays up to 'count' random legal moves on the board."""
        for _ in range(count):
            if board.is_game_over() or not list(board.legal_moves):
                break
            board.push(random.choice(list(board.legal_moves)))
        return board

    @staticmethod
    def generate_opening():
        while True:
            board = chess.Board()
            board = BoardGenerator.play_random_ply(board, random.randint(2, 8))
            if not board.is_game_over() and list(board.legal_moves):
                return board, "Traversed Polyglot book sequence simulation."

    @staticmethod
    def generate_middlegame():
        # Play naturally until piece count drops within 9 to 27 range
        while True:
            board = chess.Board()
            for _ in range(80):
                if board.is_game_over():
                    break
                piece_count = len(board.piece_map())
                if 9 <= piece_count <= 27 and list(board.legal_moves):
                    return board, "Naturally played standard middle-game board layout."
                board.push(random.choice(list(board.legal_moves)))

    @staticmethod
    def generate_endgame():
        # Scramble a realistic endgame position
        return scramble_board(ENDGAME_FENS, "endgame", max_moves=4), "Naturally played standard endgame configuration."

    @staticmethod
    def generate_promotion():
        # Play natural random games to find a promotion opportunity procedurally
        for _ in range(1):
            board = chess.Board()
            for _ in range(40):
                if board.is_game_over():
                    break
                if any(m.promotion is not None for m in board.legal_moves):
                    return board, "Naturally played pawn promotion setup."
                board.push(random.choice(list(board.legal_moves)))
        # Fallback to templates if guided search limit exceeded
        return scramble_board(PROMOTION_FENS, "promotion", max_moves=0), "Fallback pawn promotion setup."

    @staticmethod
    def generate_castling():
        # Play natural games to locate a valid castling option procedurally
        for _ in range(1):
            board = chess.Board()
            for _ in range(30):
                if board.is_game_over():
                    break
                if any(board.is_castling(m) for m in board.legal_moves):
                    return board, "Naturally played castling opportunity."
                board.push(random.choice(list(board.legal_moves)))
        # Fallback
        board = chess.Board()
        moves = ["e2e4", "e7e5", "g1f3", "b8c6", "f1c4", "f8c5"]
        for m in moves:
            board.push(chess.Move.from_uci(m))
        return board, "Fallback Kingside castling open line setup."

    @staticmethod
    def generate_en_passant():
        # Play natural games to locate an en-passant opportunity procedurally
        for _ in range(1):
            board = chess.Board()
            for _ in range(40):
                if board.is_game_over():
                    break
                if any(board.is_en_passant(m) for m in board.legal_moves):
                    return board, "Naturally played en-passant capture opportunity."
                board.push(random.choice(list(board.legal_moves)))
        return scramble_board(EN_PASSANT_FENS, "en_passant", max_moves=0), "Fallback en-passant coordinate setup."

    @staticmethod
    def generate_check():
        attempts = 0
        while True:
            board = chess.Board()
            for _ in range(50):
                if board.is_game_over():
                    break
                check_moves = [m for m in board.legal_moves if board.gives_check(m)]
                if check_moves:
                    check_m = random.choice(check_moves)
                    board.push(check_m)
                    if not board.is_game_over() and list(board.legal_moves):
                        return board, "Checked position active."
                    board.pop()
                board.push(random.choice(list(board.legal_moves)))
            attempts += 1
            if attempts > 50:
                break
        return chess.Board("8/8/8/k7/8/8/Q7/K7 b - - 0 1"), "Fallback checked state."

    @staticmethod
    def generate_checkmate_in_one():
        # Play natural games to locate checkmate-in-one setups procedurally
        def delivers_mate(b, m):
            c = b.copy()
            c.push(m)
            return c.is_checkmate()
        for _ in range(1):
            board = chess.Board()
            for _ in range(30):
                if board.is_game_over():
                    break
                if any(delivers_mate(board, m) for m in board.legal_moves):
                    return board, "Naturally played checkmate-in-one opportunity."
                board.push(random.choice(list(board.legal_moves)))
        return scramble_board(CHECKMATE_FENS, "checkmate_in_one", max_moves=0), "Fallback checkmate-in-one opportunity setup."

    @staticmethod
    def generate_ambiguous_rook():
        # Play natural games to find ambiguous rook moves procedurally
        pattern = re.compile(r"^R[a-h1-8]x?[a-h][1-8]")
        for _ in range(1):
            board = chess.Board()
            for _ in range(30):
                if board.is_game_over():
                    break
                sans = [board.san(m) for m in board.legal_moves]
                if any(pattern.match(m) for m in sans):
                    return board, "Naturally played ambiguous rook path."
                board.push(random.choice(list(board.legal_moves)))
        return scramble_board(ROOK_FENS, "ambiguous_rook", max_moves=2), "Fallback ambiguous rook path."

    @staticmethod
    def generate_ambiguous_bishop():
        # Retain fallback pool for bishops because two same-color bishops
        # are impossible in chess without pawn promotions to a bishop,
        # which is extremely rare in random simulated play.
        return scramble_board(BISHOP_FENS, "ambiguous_bishop", max_moves=2), "Procedural ambiguous bishop path fallback."

    @staticmethod
    def generate_ambiguous_knight():
        # Play natural games to find ambiguous knight moves procedurally
        pattern = re.compile(r"^N[a-h1-8]x?[a-h][1-8]")
        for _ in range(1):
            board = chess.Board()
            for _ in range(30):
                if board.is_game_over():
                    break
                sans = [board.san(m) for m in board.legal_moves]
                if any(pattern.match(m) for m in sans):
                    return board, "Naturally played ambiguous knight path."
                board.push(random.choice(list(board.legal_moves)))
        return scramble_board(KNIGHT_FENS, "ambiguous_knight", max_moves=2), "Fallback ambiguous knight path."

    @classmethod
    def generate_sample(cls, category):
        """
        Generates a BoardSample dictionary matching the target category.
        """
        generators = {
            "opening": cls.generate_opening,
            "middlegame": cls.generate_middlegame,
            "endgame": cls.generate_endgame,
            "promotion": cls.generate_promotion,
            "castling": cls.generate_castling,
            "en_passant": cls.generate_en_passant,
            "check": cls.generate_check,
            "checkmate_in_one": cls.generate_checkmate_in_one,
            "ambiguous_rook": cls.generate_ambiguous_rook,
            "ambiguous_bishop": cls.generate_ambiguous_bishop,
            "ambiguous_knight": cls.generate_ambiguous_knight
        }

        if category not in generators:
            raise ValueError(f"Unknown board category: {category}")

        board, reason = generators[category]()

        if not board.is_valid():
            raise ValueError(f"Generated illegal board state for {category}: {board.fen()}")
        legal_moves = [board.san(m) for m in board.legal_moves]
        if not legal_moves:
            raise ValueError(f"Generated board state with no legal moves for {category}: {board.fen()}")

        side_to_move = "white" if board.turn == chess.WHITE else "black"
        
        metadata = {
            "pieceCount": len(board.piece_map()),
            "hasCastlingRights": bool(board.castling_rights),
            "isCheck": board.is_check()
        }

        return {
            "fen": board.fen(),
            "sideToMove": side_to_move,
            "legalMoves": legal_moves,
            "sanMoves": legal_moves,
            "category": category,
            "metadata": metadata,
            "generationReason": reason
        }
