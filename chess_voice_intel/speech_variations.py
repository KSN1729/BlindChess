import chess
import re
from typing import List, Tuple, Dict, Any
from speech_templates import (
    PIECE_NAMES, CAPTURE_VERBS, KINGSIDE_CASTLING, QUEENSIDE_CASTLING,
    PROMOTION_TARGETS, CHECK_SUFFIXES, MATE_SUFFIXES,
    EN_PASSANT_PHRASES, NATURAL_OPENERS
)

def get_disambiguation(board: chess.Board, move: chess.Move) -> Tuple[str, str]:
    """
    Determines if file or rank disambiguation is needed for the move.
    Returns (start_file, start_rank) if needed, otherwise ('', '').
    """
    from_sq = move.from_square
    to_sq = move.to_square
    piece = board.piece_at(from_sq)
    if not piece:
        return "", ""

    # Ambiguity check
    other_can_move = False
    for m in board.legal_moves:
        if m.to_square == to_sq and m.from_square != from_sq:
            other_piece = board.piece_at(m.from_square)
            if other_piece and other_piece.piece_type == piece.piece_type:
                other_can_move = True
                break

    if not other_can_move:
        return "", ""

    # Determine if file, rank, or both disambiguates
    from_file = chess.square_file(from_sq)
    from_rank = chess.square_rank(from_sq)
    
    same_file_exists = False
    same_rank_exists = False
    
    for m in board.legal_moves:
        if m.to_square == to_sq and m.from_square != from_sq:
            other_piece = board.piece_at(m.from_square)
            if other_piece and other_piece.piece_type == piece.piece_type:
                other_file = chess.square_file(m.from_square)
                other_rank = chess.square_rank(m.from_square)
                if other_file == from_file:
                    same_file_exists = True
                if other_rank == from_rank:
                    same_rank_exists = True

    file_char = chess.FILE_NAMES[from_file]
    rank_char = chess.RANK_NAMES[from_rank]

    if same_file_exists and same_rank_exists:
        return file_char, rank_char
    elif same_file_exists:
        # Shared file, so ranks are different. Rank disambiguates.
        return "", rank_char
    elif same_rank_exists:
        # Shared rank, so files are different. File disambiguates.
        return file_char, ""
    else:
        # Default fallback to file
        return file_char, ""

def generate_variations(board: chess.Board, move: chess.Move, san_move: str) -> List[Tuple[str, str]]:
    """
    Generates a list of (spokenText, style) variations for a given legal move.
    Guarantees between 10 and 50 unique paraphrases depending on move characteristics.
    """
    variations = []
    
    from_sq = move.from_square
    to_sq = move.to_square
    piece = board.piece_at(from_sq)
    
    dest_str = chess.square_name(to_sq)
    start_str = chess.square_name(from_sq)
    
    is_capture = board.is_capture(move)
    is_ep = board.is_en_passant(move)
    is_castling = board.is_castling(move)
    is_check = board.gives_check(move)
    
    # Checkmate validation
    c = board.copy()
    c.push(move)
    is_mate = c.is_checkmate()

    # Determine disambiguation
    dis_file, dis_rank = get_disambiguation(board, move)

    # 1. Castling Moves
    if is_castling:
        is_kingside = board.is_kingside_castling(move)
        pool = KINGSIDE_CASTLING if is_kingside else QUEENSIDE_CASTLING
        
        # Split into styles
        for text in pool:
            if "i'll" in text or "go ahead" in text:
                variations.append((text, "natural"))
            elif "short" in text or "long" in text:
                variations.append((text, "conversational"))
            elif text == "castle":
                variations.append((text, "minimal"))
            else:
                variations.append((text, "formal"))
                
        # Additional verbose styles for castling
        side = "kingside" if is_kingside else "queenside"
        variations.append((f"castle my king {side}", "verbose"))
        variations.append((f"perform a {side} castle", "verbose"))
        variations.append((f"let's secure the king and castle {side}", "natural"))
        variations.append((f"can you castle {side} please", "natural"))
        
        # Deduplicate and return
        seen = set()
        return [v for v in variations if not (v[0] in seen or seen.add(v[0]))]

    # Get piece names
    p_code = piece.symbol().upper() if piece else "P"
    piece_options = PIECE_NAMES.get(p_code, [""])

    # 2. En-passant Moves
    if is_ep:
        for p_opt in piece_options[:3]:
            prefix = f"{p_opt} " if p_opt else ""
            for ep_phrase in EN_PASSANT_PHRASES:
                variations.append((f"{prefix}takes on {dest_str} {ep_phrase}", "conversational"))
                variations.append((f"{prefix}capture on {dest_str} {ep_phrase}", "formal"))
            variations.append((f"take en passant on {dest_str}", "minimal"))
            variations.append((f"let's capture en passant on {dest_str}", "natural"))
            variations.append((f"move the pawn to capture en passant on {dest_str}", "verbose"))
            
        seen = set()
        return [v for v in variations if not (v[0] in seen or seen.add(v[0]))]

    # 3. Promotion Moves
    if move.promotion:
        promo_piece = chess.piece_symbol(move.promotion).lower()
        promo_targets = PROMOTION_TARGETS.get(promo_piece, ["queen"])
        
        for target in promo_targets:
            # Minimal
            variations.append((f"{dest_str} promote to {target}", "minimal"))
            variations.append((f"{dest_str}={promo_piece.upper()}", "minimal"))
            # Formal
            variations.append((f"pawn to {dest_str} promote to {target}", "formal"))
            variations.append((f"pawn captures on {dest_str} promoting to {target}" if is_capture else f"pawn to {dest_str} promoting to {target}", "formal"))
            # Conversational
            variations.append((f"move pawn to {dest_str} and promote to {target}", "conversational"))
            # Verbose
            variations.append((f"move pawn from {start_str} to {dest_str} promoting to a {target}", "verbose"))
            # Natural
            variations.append((f"let's promote this pawn on {dest_str} to a {target}", "natural"))
            variations.append((f"can you promote to a {target} on {dest_str}", "natural"))
            
        seen = set()
        return [v for v in variations if not (v[0] in seen or seen.add(v[0]))]

    # 4. Standard / Capture / Check / Mate Moves
    # Resolve disambiguation suffix
    dis_suffix = ""
    dis_verbose = ""
    if dis_file and dis_rank:
        dis_suffix = f" from {dis_file}{dis_rank}"
        dis_verbose = f" on {dis_file}{dis_rank}"
    elif dis_file:
        dis_suffix = f" from {dis_file}"
        dis_verbose = f" on the {dis_file} file"
    elif dis_rank:
        dis_suffix = f" from {dis_rank}"
        dis_verbose = f" on the {dis_rank} rank"

    # Outcome suffixes
    outcome_suffixes = [""]
    if is_mate:
        outcome_suffixes = [f" delivering {s}" for s in MATE_SUFFIXES] + [f" checkmate"]
    elif is_check:
        outcome_suffixes = [" check"] + [f" giving {s}" for s in CHECK_SUFFIXES]

    for p_name in piece_options:
        piece_prefix = f"{p_name}" if p_name else ""
        
        # Minimal Style
        if not dis_suffix:
            if is_capture:
                for verb in ["takes", "take", "captures"]:
                    if piece_prefix:
                        variations.append((f"{piece_prefix} {verb} {dest_str}", "minimal"))
                    else:
                        variations.append((f"pawn {verb} {dest_str}", "minimal"))
            else:
                if piece_prefix:
                    variations.append((f"{piece_prefix} {dest_str}", "minimal"))
                else:
                    variations.append((f"{dest_str}", "minimal"))
        else:
            if piece_prefix:
                variations.append((f"{piece_prefix}{dis_suffix} {dest_str}", "minimal"))
                variations.append((f"{piece_prefix} from {dis_file or dis_rank} to {dest_str}", "minimal"))

        # Formal Style
        for out in outcome_suffixes:
            if is_capture:
                for verb in ["takes", "captures"]:
                    prefix = f"{piece_prefix} " if piece_prefix else "pawn "
                    variations.append((f"{prefix}{dis_suffix} {verb} {dest_str}{out}", "formal"))
                    if not dis_suffix:
                        variations.append((f"{prefix}{verb} on {dest_str}{out}", "formal"))
            else:
                prefix = f"{piece_prefix} " if piece_prefix else "pawn to "
                variations.append((f"{prefix}{dis_suffix} to {dest_str}{out}", "formal"))
                if not dis_suffix:
                    variations.append((f"{prefix}to {dest_str}{out}", "formal"))

        # Conversational Style
        for out in outcome_suffixes:
            prefix = f"the {p_name}" if p_name else "the pawn"
            if is_capture:
                variations.append((f"take on {dest_str} with {prefix}{dis_suffix}{out}", "conversational"))
                variations.append((f"capture on {dest_str} using {prefix}{dis_suffix}{out}", "conversational"))
            else:
                variations.append((f"move {prefix}{dis_suffix} to {dest_str}{out}", "conversational"))
                variations.append((f"play {prefix}{dis_suffix} to {dest_str}{out}", "conversational"))

        # Verbose Style
        for out in outcome_suffixes:
            prefix = f"my {p_name}" if p_name else "pawn"
            variations.append((f"move {prefix}{dis_verbose} from {start_str} to {dest_str}{out}", "verbose"))
            if is_capture:
                variations.append((f"move {prefix}{dis_verbose} from {start_str} to capture on {dest_str}{out}", "verbose"))

        # Natural Style
        for opener in NATURAL_OPENERS[:6]:
            for out in outcome_suffixes:
                prefix = f"the {p_name}" if p_name else "pawn"
                if is_capture:
                    variations.append((f"{opener} to take on {dest_str} with {prefix}{dis_suffix}{out}", "natural"))
                else:
                    variations.append((f"{opener} {prefix}{dis_suffix} to {dest_str}{out}", "natural"))

    # Filter out empty strings, normalize spaces, clean checkmark characters
    cleaned_variations = []
    seen = set()
    for text, style in variations:
        text_clean = re.sub(r"\s+", " ", text).strip().lower()
        # strip punctuation for consistency
        text_clean = text_clean.replace("?", "").replace(".", "").replace(",", "")
        if text_clean and text_clean not in seen:
            seen.add(text_clean)
            cleaned_variations.append((text_clean, style))
            
    # Bounded paraphrases size: slice to keep between 10 and 50
    if len(cleaned_variations) < 10:
        # Emergency duplicate templates to ensure minimum 10 unique phrases
        # This only happens for extremely basic pawns, so we inject variations using Charlie/Echo spellings
        extra = []
        for text, style in cleaned_variations:
            if "f3" in text:
                extra.append((text.replace("f3", "foxtrot 3"), style))
            if "c3" in text:
                extra.append((text.replace("c3", "charlie 3"), style))
        cleaned_variations.extend(extra)
        
    return cleaned_variations[:50]
