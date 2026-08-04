import chess

class ContextGenerator:
    """
    Analyzes the semantic context of a spoken chess move against board legality.
    Resolves coordinate noise and tags difficulty level.
    """
    @staticmethod
    def calculate_edit_distance(s1, s2):
        if len(s1) < len(s2):
            return ContextGenerator.calculate_edit_distance(s2, s1)
        if len(s2) == 0:
            return len(s1)
        previous_row = range(len(s2) + 1)
        for i, c1 in enumerate(s1):
            current_row = [i + 1]
            for j, c2 in enumerate(s2):
                insertions = previous_row[j + 1] + 1
                deletions = current_row[j] + 1
                substitutions = previous_row[j] + (c1 != c2)
                current_row.append(min(insertions, deletions, substitutions))
            previous_row = current_row
        return previous_row[-1]

    @staticmethod
    def get_difficulty_and_reason(board, correct_san, clean_text, stt_text, was_noise_injected):
        """
        Determines difficulty (easy, medium, hard, expert) and semantic reason.
        """
        # Parse the move
        move = board.parse_san(correct_san)
        piece = board.piece_at(move.from_square)
        piece_symbol = piece.symbol().lower() if piece else 'p'
        to_sq = chess.square_name(move.to_square)
        
        # Check same type pieces that can reach target square
        same_type_count = 0
        for m in board.legal_moves:
            if m.to_square == move.to_square:
                p = board.piece_at(m.from_square)
                if p and p.piece_type == piece.piece_type:
                    same_type_count += 1

        clean_words = clean_text.lower().split()
        stt_words = stt_text.lower().split()
        
        # Compute word-level edit distance to measure noise severity
        edit_dist = ContextGenerator.calculate_edit_distance(clean_words, stt_words)
        
        # Determine difficulty
        if clean_text == stt_text and same_type_count == 1:
            difficulty = "easy"
            reason = "Standard clean move. Singular piece type can reach destination target."
            
        elif same_type_count == 1 and not was_noise_injected and edit_dist <= 2:
            difficulty = "medium"
            reason = "Contains minor phonetic noise, but board context easily resolves target to a unique legal move."
            
        elif same_type_count > 1 and not was_noise_injected:
            difficulty = "hard"
            reason = f"Ambiguity present: multiple {piece_symbol.upper()} pieces can reach {to_sq}. Spoken text contains valid origin constraints."
            
        elif was_noise_injected:
            if same_type_count > 1:
                difficulty = "expert"
                reason = f"High complexity: multiple {piece_symbol.upper()} pieces can reach {to_sq}, and the user spoke a fake origin coordinate that must be ignored as noise."
            else:
                difficulty = "hard"
                reason = f"Noisy origin coordinates injected. The coordinate must be treated as noise because only one {piece_symbol.upper()} piece can reach {to_sq}."
                
        else:
            # High noise fallback
            if edit_dist >= 4:
                difficulty = "expert"
                reason = "Expert level due to extreme transcription noise and high edit distance from clean move syntax."
            else:
                difficulty = "medium"
                reason = "Standard move with moderate phonetic noise resolved by unique destination match."
                
        return difficulty, reason
