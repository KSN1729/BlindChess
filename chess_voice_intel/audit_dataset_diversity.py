import chess
import math
import json
import time
from board_generator import BoardGenerator, PROMOTION_FENS, EN_PASSANT_FENS, CHECKMATE_FENS, ROOK_FENS, BISHOP_FENS, KNIGHT_FENS, ENDGAME_FENS

CATEGORIES = [
    "opening",
    "middlegame",
    "endgame",
    "promotion",
    "castling",
    "en_passant",
    "check",
    "checkmate_in_one",
    "ambiguous_rook",
    "ambiguous_bishop",
    "ambiguous_knight"
]

def calculate_entropy(probabilities):
    entropy = 0.0
    for p in probabilities:
        if p > 0:
            entropy -= p * math.log2(p)
    return entropy

def audit_dataset():
    print("==================================================")
    print("STARTING DATASET DIVERSITY & INTEGRITY AUDIT")
    print("==================================================")
    
    # 1. Audit hardcoded FEN pools
    pools = {
        "PROMOTION_FENS": PROMOTION_FENS,
        "EN_PASSANT_FENS": EN_PASSANT_FENS,
        "CHECKMATE_FENS": CHECKMATE_FENS,
        "ROOK_FENS": ROOK_FENS,
        "BISHOP_FENS": BISHOP_FENS,
        "KNIGHT_FENS": KNIGHT_FENS,
        "ENDGAME_FENS": ENDGAME_FENS
    }
    
    print("Hardcoded FEN Pools Audit:")
    for name, pool in pools.items():
        unique_pool = set(pool)
        malformed = []
        for fen in pool:
            try:
                b = chess.Board(fen)
                if not b.is_valid():
                    malformed.append(fen)
            except Exception:
                malformed.append(fen)
                
        print(f"  - {name:<16}: {len(pool):>2} FENs | Unique: {len(unique_pool):>2} | Malformed: {len(malformed):>2}")
        
    print("\nGenerating 10,000 samples for diversity sweep...")
    total_samples = 10000
    samples_per_cat = total_samples // len(CATEGORIES)
    
    category_positions = {cat: [] for cat in CATEGORIES}
    square_counts = {}
    piece_type_counts = {pt: 0 for pt in chess.PIECE_TYPES}
    
    t_start = time.perf_counter()
    for cat in CATEGORIES:
        for _ in range(samples_per_cat):
            sample = BoardGenerator.generate_sample(cat)
            fen = sample["fen"]
            category_positions[cat].append(fen)
            
            # Count destination squares of legal moves
            board = chess.Board(fen)
            for m in board.legal_moves:
                sq_name = chess.square_name(m.to_square)
                square_counts[sq_name] = square_counts.get(sq_name, 0) + 1
                
            # Count piece types on the board
            for sq in board.piece_map().keys():
                pt = board.piece_at(sq).piece_type
                piece_type_counts[pt] += 1
                
    t_end = time.perf_counter()
    print(f"Sweep complete in {t_end - t_start:.2f} seconds.")
    
    # Calculate Square target entropy
    total_sq_count = sum(square_counts.values())
    sq_probs = [count / total_sq_count for count in square_counts.values()] if total_sq_count > 0 else []
    square_entropy = calculate_entropy(sq_probs)
    
    # Calculate Piece distribution entropy
    total_piece_count = sum(piece_type_counts.values())
    piece_probs = [count / total_piece_count for count in piece_type_counts.values()] if total_piece_count > 0 else []
    piece_entropy = calculate_entropy(piece_probs)
    
    # Category level diversity metrics
    category_metrics = {}
    print("\nCategory Position Diversity Stats:")
    for cat in CATEGORIES:
        fens = category_positions[cat]
        unique_fens = set(fens)
        dup_rate = (len(fens) - len(unique_fens)) / len(fens) * 100.0
        
        category_metrics[cat] = {
            "total_generated": len(fens),
            "unique": len(unique_fens),
            "duplicate_rate_pct": dup_rate
        }
        print(f"  - {cat:<20}: Unique: {len(unique_fens):>4}/{len(fens):>4} | Duplicate Rate: {dup_rate:6.2f}%")
        
    p_names = {
        chess.PAWN: "pawns",
        chess.KNIGHT: "knights",
        chess.BISHOP: "bishops",
        chess.ROOK: "rooks",
        chess.QUEEN: "queens",
        chess.KING: "kings"
    }
    
    piece_percentages = {
        p_names[pt]: (count / total_piece_count * 100.0) if total_piece_count > 0 else 0.0
        for pt, count in piece_type_counts.items()
    }
    
    summary = {
        "square_target_entropy": square_entropy,
        "piece_type_entropy": piece_entropy,
        "total_generated_samples": total_samples,
        "piece_percentages": piece_percentages,
        "category_diversity": category_metrics,
        "fen_pools_summary": {
            name: {
                "total": len(pool),
                "unique": len(set(pool)),
                "malformed": len([fen for fen in pool if not chess.Board(fen).is_valid()])
            } for name, pool in pools.items()
        }
    }
    
    print("\n==================================================")
    print("DIVERSITY AUDIT REPORT SUMMARY")
    print("==================================================")
    print(f"Square Target Entropy:   {square_entropy:.3f} bits (Max: 6.00 bits for 64 squares)")
    print(f"Piece Type Entropy:      {piece_entropy:.3f} bits (Max: 2.58 bits for 6 types)")
    print(f"Avg Piece Percentages:")
    for p_name, pct in piece_percentages.items():
        print(f"  - {p_name:<10}: {pct:5.2f}%")
    print("==================================================")
    
    with open("diversity_results.json", "w") as f:
        json.dump(summary, f, indent=2)
    print("Saved diversity audit results to diversity_results.json")

if __name__ == "__main__":
    audit_dataset()
