import chess
import random
import os
import json
from board_generator import BoardGenerator
from speech_generator import CleanSpeechGenerator
from noise_generator import ConfigurableNoiseGenerator
from context_generator import ContextGenerator
from validator import DatasetValidator
from dataset_writer import DatasetWriter
from statistics import DatasetStatisticsReporter

def extract_move_properties(board, move):
    san = board.san(move)
    piece = board.piece_at(move.from_square)
    piece_symbol = piece.symbol().lower() if piece else 'p'
    
    from_sq = chess.square_name(move.from_square)
    to_sq = chess.square_name(move.to_square)
    
    capture = board.is_capture(move)
    promotion = ''
    if move.promotion:
        p_map = {chess.QUEEN: 'q', chess.ROOK: 'r', chess.BISHOP: 'b', chess.KNIGHT: 'n'}
        promotion = p_map.get(move.promotion, '')
        
    castle = ''
    if board.is_kingside_castling(move):
        castle = 'k'
    elif board.is_queenside_castling(move):
        castle = 'q'
        
    # Temporary apply move to check check/mate states after move
    board.push(move)
    is_check = board.is_check()
    is_mate = board.is_checkmate()
    board.pop()
    
    # Calculate same piece type candidates reaching target square
    same_type_count = 0
    for m in board.legal_moves:
        if m.to_square == move.to_square:
            p = board.piece_at(m.from_square)
            if p and p.piece_type == piece.piece_type:
                same_type_count += 1
                
    origin_file = ''
    origin_rank = ''
    
    # Exclude castling moves from origin parsing
    clean_san = san.replace('+', '').replace('#', '').replace('x', '')
    if not clean_san.startswith('O-O') and same_type_count > 1:
        body = clean_san[:-2]
        if body.startswith(piece.symbol()):
            body = body[1:]
        if len(body) == 1:
            if body in 'abcdefgh':
                origin_file = body
            else:
                origin_rank = body
        elif len(body) == 2:
            origin_file = body[0]
            origin_rank = body[1]
            
    return {
        'piece': piece_symbol,
        'from': from_sq,
        'to': to_sq,
        'san': san,
        'originFile': origin_file,
        'originRank': origin_rank,
        'capture': capture,
        'promotion': promotion,
        'castle': castle,
        'check': is_check,
        'checkmate': is_mate,
        'same_type_count': same_type_count
    }

def main():
    target_count = 100000
    output_path = "chess_voice_intel/dataset_v2.jsonl"
    
    print("="*60)
    print("STARTING MASSIVE CHESS SPEECH DATASET GENERATOR")
    print("="*60)
    print(f"Target count: {target_count} validated examples")
    print(f"Output path: {output_path}")
    
    # Initialize generators
    noise_gen = ConfigurableNoiseGenerator()
    writer = DatasetWriter(output_path)
    
    validated_examples = []
    discarded_count = 0
    generated_count = 0
    
    # Progress intervals
    progress_step = 10000
    
    while len(validated_examples) < target_count:
        board, category = BoardGenerator.get_random_board()
        legal_moves = [board.san(m) for m in board.legal_moves]
        if not legal_moves:
            continue
            
        move = random.choice(list(board.legal_moves))
        props = extract_move_properties(board, move)
        
        # 1. Clean Speech Generation
        clean_text = CleanSpeechGenerator.get_random_variation(props)
        raw_speech = clean_text # Vocalization
        normalized = clean_text # Normal target
        
        # 2. Phonetic Noise corruption
        stt = noise_gen.corrupt(clean_text)
        
        # 3. Handle coordinate noise injection (15% probability for non-pawn, non-castle, unique destination moves)
        was_noise_injected = False
        if props['piece'] != 'p' and not props['castle'] and props['same_type_count'] == 1 and random.random() < 0.15:
            # Inject a fake origin file to simulate speech noise (e.g. rook h e1)
            fake_file = random.choice([f for f in 'abcdefgh' if f != props['from'][0]])
            
            # Re-synthesize STT with fake file
            noisy_props = dict(props)
            noisy_props['originFile'] = fake_file
            
            fake_clean_text = CleanSpeechGenerator.get_random_variation(noisy_props)
            stt = noise_gen.corrupt(fake_clean_text)
            was_noise_injected = True
            
        # 4. Resolve Context & Tag Difficulty Level
        difficulty, reason = ContextGenerator.get_difficulty_and_reason(
            board, props['san'], clean_text, stt, was_noise_injected
        )
        
        # 5. Assemble Example
        example = {
            "id": f"example_{len(validated_examples) + 1}",
            "rawSpeech": raw_speech,
            "stt": stt,
            "normalized": normalized,
            "fen": board.fen(),
            "sideToMove": "white" if board.turn == chess.WHITE else "black",
            "legalMoves": legal_moves,
            "correctMove": props['san'],
            "piece": props['piece'],
            "destination": props['to'],
            "originFile": props['originFile'],
            "originRank": props['originRank'],
            "originSquare": props['from'],
            "capture": props['capture'],
            "promotion": props['promotion'],
            "castle": props['castle'],
            "check": props['check'],
            "checkmate": props['checkmate'],
            "difficulty": difficulty,
            "reason": reason
        }
        
        # 6. Validate example
        is_valid, err_reason = DatasetValidator.validate_example(example)
        if is_valid:
            writer.write_example(example)
            validated_examples.append(example)
            generated_count += 1
            
            if generated_count % progress_step == 0:
                print(f"Progress: {generated_count} examples validated & written...")
        else:
            discarded_count += 1
            # print(f"Discarded example: {err_reason}") # Debug log
            
    # Close write stream
    writer.close()
    
    print("\nGeneration finished successfully!")
    print(f"Total validated examples written: {len(validated_examples)}")
    print(f"Total discarded examples: {discarded_count}")
    
    # 7. Generate Statistics Report
    print("\nCompiling Dataset Statistics...")
    report = DatasetStatisticsReporter.generate_report(validated_examples)
    
    # Save Report
    report_path = "chess_voice_intel/statistics_report.md"
    with open(report_path, "w", encoding="utf-8") as f:
        f.write(report)
        
    print(f"Saved statistics report to {report_path}")
    print("\n" + "="*60)
    print("DATASET PROFILE SUMMARY")
    print("="*60)
    print(report)
    print("="*60)

if __name__ == "__main__":
    main()
