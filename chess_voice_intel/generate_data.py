import chess
import random
import json
import os
from noise_generator import corrupt_move

def get_move_metadata(board, move):
    """
    Extracts structured metadata for a move from python-chess.
    """
    san = board.san(move)
    piece = board.piece_at(move.from_square)
    piece_symbol = piece.symbol().lower() if piece else 'p'
    
    # Target and origin squares
    to_sq = chess.square_name(move.to_square)
    from_sq = chess.square_name(move.from_square)
    
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
      
    # Disambiguation check: how many other pieces of the same type can move to the same target square?
    same_type_count = 0
    for m in board.legal_moves:
      if m.to_square == move.to_square:
        p = board.piece_at(m.from_square)
        if p and p.piece_type == piece.piece_type:
          same_type_count += 1
          
    origin_file = ''
    origin_rank = ''
    
    # If same_type_count > 1, SAN includes disambiguation details (e.g. Nbd2)
    # Let's extract the disambiguation details from the SAN
    clean_san = san.replace('+', '').replace('#', '').replace('x', '')
    if clean_san.startswith('O-O'):
      pass
    elif same_type_count > 1:
      # SAN structure: [Piece][OriginConstraints][TargetSquare]
      # target square is always last 2 chars (or 3 if promotion, but clean_san has promotion stripped)
      # e.g., clean_san is Nbd2. Piece is N. Target is d2. Origin constraint is b.
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
        'same_type_count': same_type_count
    }

def play_random_game_to_moves(moves_count=15):
    """
    Plays a random game of chess up to moves_count ply.
    """
    board = chess.Board()
    for _ in range(moves_count):
      if board.is_game_over():
        break
      move = random.choice(list(board.legal_moves))
      board.push(move)
    return board

def generate_dataset(num_examples=10000):
    examples = []
    print(f"Generating {num_examples} dataset examples...")
    
    # 70% standard, 15% ambiguous, 15% noise-injected
    num_ambig = int(num_examples * 0.15)
    num_noise = int(num_examples * 0.15)
    num_std = num_examples - num_ambig - num_noise
    
    generated = 0
    attempts = 0
    
    # Generate ambiguous moves first
    print("Generating ambiguous move scenarios...")
    while len(examples) < num_ambig and attempts < num_ambig * 15:
      attempts += 1
      board = play_random_game_to_moves(random.randint(5, 45))
      legal_moves_list = [board.san(m) for m in board.legal_moves]
      if not legal_moves_list:
        continue
        
      # Find a move with same_type_count > 1
      ambig_moves = []
      for m in board.legal_moves:
        meta = get_move_metadata(board, m)
        if meta['same_type_count'] > 1:
          ambig_moves.append((m, meta))
          
      if ambig_moves:
        move, meta = random.choice(ambig_moves)
        raw_speech, stt, normalized = corrupt_move(meta)
        
        examples.append({
            "rawSpeech": raw_speech,
            "stt": stt,
            "normalized": normalized,
            "fen": board.fen(),
            "legalMoves": legal_moves_list,
            "correctMove": meta['san'],
            "piece": meta['piece'],
            "destination": meta['to'],
            "originFile": meta['originFile'],
            "originRank": meta['originRank'],
            "capture": meta['capture'],
            "promotion": meta['promotion'],
            "castle": meta['castle'],
            "reason": f"Disambiguation move: multiple {meta['piece']} pieces can reach target square. Origin constraints resolved."
        })
        
    print(f"Ambiguous moves generated: {len(examples)} after {attempts} attempts.")
    
    # Generate noise-injected moves
    attempts = 0
    noise_start_len = len(examples)
    print("Generating noise-injected coordinate scenarios...")
    while len(examples) < (noise_start_len + num_noise) and attempts < num_noise * 15:
      attempts += 1
      board = play_random_game_to_moves(random.randint(5, 45))
      legal_moves_list = [board.san(m) for m in board.legal_moves]
      if not legal_moves_list:
        continue
        
      # Find a move where only ONE piece of this type can reach the target square
      candidate_moves = []
      for m in board.legal_moves:
        meta = get_move_metadata(board, m)
        if meta['same_type_count'] == 1 and not meta['castle'] and meta['piece'] != 'p':
          candidate_moves.append((m, meta))
          
      if candidate_moves:
        move, meta = random.choice(candidate_moves)
        
        # We inject a fake originFile or originRank to simulate transcription noise
        # E.g. Rook is on g1, target is e1. Fake origin file is 'h'.
        fake_file = random.choice([f for f in 'abcdefgh' if f != meta['from'][0]])
        
        # Modify the clean move dictionary for noise generation to contain a fake origin constraint
        noisy_meta = dict(meta)
        noisy_meta['originFile'] = fake_file
        
        raw_speech, stt, normalized = corrupt_move(noisy_meta)
        
        examples.append({
            "rawSpeech": raw_speech,
            "stt": stt,
            "normalized": normalized,
            "fen": board.fen(),
            "legalMoves": legal_moves_list,
            "correctMove": meta['san'],
            "piece": meta['piece'],
            "destination": meta['to'],
            "originFile": "",  # Correct origin constraints is empty because the fake file was noise
            "originRank": "",
            "capture": meta['capture'],
            "promotion": meta['promotion'],
            "castle": meta['castle'],
            "reason": f"Input '{fake_file}' is treated as noise. Only one {meta['piece']} piece (on {meta['from']}) can legally reach {meta['to']}."
        })
        
    print(f"Noise-injected moves generated: {len(examples) - noise_start_len} after {attempts} attempts.")
    
    # Generate standard moves
    std_start_len = len(examples)
    print("Generating standard move scenarios...")
    while len(examples) < num_examples:
      board = play_random_game_to_moves(random.randint(3, 40))
      legal_moves_list = [board.san(m) for m in board.legal_moves]
      if not legal_moves_list:
        continue
        
      move = random.choice(list(board.legal_moves))
      meta = get_move_metadata(board, move)
      
      raw_speech, stt, normalized = corrupt_move(meta)
      
      examples.append({
          "rawSpeech": raw_speech,
          "stt": stt,
          "normalized": normalized,
          "fen": board.fen(),
          "legalMoves": legal_moves_list,
          "correctMove": meta['san'],
          "piece": meta['piece'],
          "destination": meta['to'],
          "originFile": meta['originFile'],
          "originRank": meta['originRank'],
          "capture": meta['capture'],
          "promotion": meta['promotion'],
          "castle": meta['castle'],
          "reason": "Standard legal move match."
      })
      
    print(f"Standard moves generated: {len(examples) - std_start_len}.")
    
    # Shuffle dataset
    random.shuffle(examples)
    return examples

if __name__ == "__main__":
    dataset = generate_dataset(10000)
    
    # Ensure save directory exists
    os.makedirs("chess_voice_intel", exist_ok=True)
    
    output_path = "chess_voice_intel/dataset.json"
    with open(output_path, "w") as f:
      json.dump(dataset, f, indent=2)
      
    print(f"Successfully generated and saved {len(dataset)} examples to {output_path}")
