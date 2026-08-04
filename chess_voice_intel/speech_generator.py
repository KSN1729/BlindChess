import chess
from typing import Dict, Any, List
from speech_sample import SpeechSample
from speech_variations import generate_variations
from speech_validator import SpeechValidator

class SpeechGenerator:
    """
    Orchestration Engine converting a BoardSample into a set of legally valid,
    paraphrased, and validated SpeechSample dicts.
    """

    @staticmethod
    def generate_speech_samples(board_sample: Dict[str, Any]) -> List[Dict[str, Any]]:
        fen = board_sample["fen"]
        board = chess.Board(fen)
        
        speech_samples = []
        
        # Pre-index legal moves by destination square for maximum validation speed
        moves_by_dest = {}
        for move in board.legal_moves:
            dest = chess.square_name(move.to_square)
            if dest not in moves_by_dest:
                moves_by_dest[dest] = []
            moves_by_dest[dest].append(move)
        
        # Iterate over all legal moves
        for move in board.legal_moves:
            san = board.san(move)
            uci = move.uci()
            
            # Generate spoken paraphrases in 5 styles
            variations = generate_variations(board, move, san)
            
            for spoken_text, style in variations:
                # Semantic Validation: spoken text must map to EXACTLY this move
                is_valid, reason, resolved_uci = SpeechValidator.validate_and_resolve(board, spoken_text, moves_by_dest)
                
                if not is_valid or resolved_uci != uci:
                    # Skip invalid or ambiguous phrases to guarantee 100% dataset integrity
                    continue
                
                # Classify move category
                move_cat = board_sample["category"]
                if board.is_capture(move):
                    move_cat = "capture"
                elif board.is_castling(move):
                    move_cat = "castling"
                elif board.is_en_passant(move):
                    move_cat = "en_passant"
                elif move.promotion:
                    move_cat = "promotion"
                elif board.gives_check(move):
                    move_cat = "check"

                # Define metadata dictionary
                metadata = {
                    "difficulty": "medium" if len(spoken_text.split()) > 4 else "easy",
                    "speakerStyle": "neutral",
                    "style": style,
                    "moveCategory": move_cat
                }
                
                sample = SpeechSample(
                    spokenText=spoken_text,
                    canonicalMove=uci,
                    SAN=san,
                    UCI=uci,
                    category=move_cat,
                    language="en",
                    variationType=style,
                    metadata=metadata,
                    generationReason=board_sample["generationReason"]
                )
                
                speech_samples.append(sample.to_dict())
                
        return speech_samples
