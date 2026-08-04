import chess

class DatasetValidator:
    """
    Validates example instances for structural, logical, and grammatical consistency.
    """
    @staticmethod
    def validate_example(ex):
        """
        Validates a single training example dictionary.
        Returns (is_valid, error_reason)
        """
        try:
            # 1. FEN validation
            fen = ex.get('fen', '')
            if not fen:
                return False, "Empty FEN"
            
            try:
                board = chess.Board(fen)
            except ValueError as ve:
                return False, f"Invalid FEN structure: {ve}"

            # 2. Correct Move & Legality validation
            correct_move_san = ex.get('correctMove', '')
            if not correct_move_san:
                return False, "Empty correctMove"
                
            try:
                move = board.parse_san(correct_move_san)
            except ValueError as ve:
                return False, f"Invalid SAN syntax for correctMove '{correct_move_san}': {ve}"
                
            if move not in board.legal_moves:
                return False, f"Move '{correct_move_san}' is illegal on board state '{fen}'"

            # 3. Legal moves list consistency
            legal_moves_provided = set(ex.get('legalMoves', []))
            actual_legal_moves = set([board.san(m) for m in board.legal_moves])
            
            if legal_moves_provided != actual_legal_moves:
                return False, "legalMoves list does not match actual board legal moves"

            # 4. Destination validation
            dest = ex.get('destination', '')
            expected_dest = chess.square_name(move.to_square)
            if dest != expected_dest:
                return False, f"Destination '{dest}' does not match move target square '{expected_dest}'"

            # 5. Piece validation
            piece_type = ex.get('piece', '')
            # Castling moves can have empty piece field
            is_castle = board.is_castling(move)
            if not is_castle:
                piece_at_source = board.piece_at(move.from_square)
                expected_piece = piece_at_source.symbol().lower() if piece_at_source else 'p'
                if piece_type != expected_piece:
                    return False, f"Piece type '{piece_type}' does not match board piece '{expected_piece}'"

            # 6. Castling consistency
            castle_val = ex.get('castle', '')
            if is_castle:
                expected_castle = 'k' if board.is_kingside_castling(move) else 'q'
                if castle_val != expected_castle:
                    return False, f"Castle property '{castle_val}' does not match expected '{expected_castle}'"
            elif castle_val:
                return False, "Castle property set on non-castling move"

            # 7. Promotion consistency
            promotion_val = ex.get('promotion', '')
            if move.promotion:
                p_map = {chess.QUEEN: 'q', chess.ROOK: 'r', chess.BISHOP: 'b', chess.KNIGHT: 'n'}
                expected_promo = p_map.get(move.promotion, '')
                if promotion_val != expected_promo:
                    return False, f"Promotion piece '{promotion_val}' does not match expected '{expected_promo}'"
            elif promotion_val:
                return False, "Promotion piece set on non-promoting move"

            # 8. Check and checkmate flags validation
            is_check = ex.get('check', False)
            is_mate = ex.get('checkmate', False)
            
            # Temporary apply move to check board state after move
            board.push(move)
            actual_check = board.is_check()
            actual_mate = board.is_checkmate()
            board.pop()
            
            if is_check != actual_check:
                return False, f"Check flag '{is_check}' does not match actual check state '{actual_check}'"
            if is_mate != actual_mate:
                return False, f"Checkmate flag '{is_mate}' does not match actual checkmate state '{actual_mate}'"

            # 9. Speech consistency
            raw_speech = ex.get('rawSpeech', '')
            stt = ex.get('stt', '')
            normalized = ex.get('normalized', '')
            
            if not isinstance(raw_speech, str) or not raw_speech.strip():
                return False, "Invalid or empty rawSpeech string"
            if not isinstance(stt, str) or not stt.strip():
                return False, "Invalid or empty stt string"
            if not isinstance(normalized, str) or not normalized.strip():
                return False, "Invalid or empty normalized string"

            return True, ""
        except Exception as e:
            return False, f"Unexpected validation exception: {e}"
