import chess
import time
import json
import re
from board_generator import BoardGenerator

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

def delivers_mate(board, move):
    c = board.copy()
    c.push(move)
    return c.is_checkmate()

def verify_category_satisfaction(board, category, sample_legal_moves):
    piece_count = len(board.piece_map())
    
    if category == "opening":
        if piece_count < 28:
            return False, f"Opening piece count is too low: {piece_count} (expected >= 28)"
        return True, ""
        
    elif category == "middlegame":
        if not (9 <= piece_count <= 27):
            return False, f"Middlegame piece count out of bounds: {piece_count} (expected 9 to 27)"
        return True, ""
        
    elif category == "endgame":
        if piece_count > 8:
            return False, f"Endgame piece count is too high: {piece_count} (expected <= 8)"
        return True, ""
        
    elif category == "promotion":
        has_promotion = any(m.promotion is not None for m in board.legal_moves)
        if not has_promotion:
            return False, "No legal promotion moves in board state"
        has_san_promotion = any("=" in m for m in sample_legal_moves)
        if not has_san_promotion:
            return False, "No promotion moves found in SAN moves list"
        return True, ""
        
    elif category == "castling":
        has_castling = any(board.is_castling(m) for m in board.legal_moves)
        if not has_castling:
            return False, "No legal castling moves in board state"
        has_san_castling = any("O-O" in m for m in sample_legal_moves)
        if not has_san_castling:
            return False, "No castling moves found in SAN moves list"
        if not board.castling_rights:
            return False, "Castling rights are empty"
        return True, ""
        
    elif category == "en_passant":
        has_ep = any(board.is_en_passant(m) for m in board.legal_moves)
        if not has_ep:
            return False, "No legal en-passant moves in board state"
        if board.ep_square is None:
            return False, "En-passant target square is not set"
        return True, ""
        
    elif category == "check":
        if not board.is_check():
            return False, "Board state is not in check"
        return True, ""
        
    elif category == "checkmate_in_one":
        has_mate_in_one = any(delivers_mate(board, m) for m in board.legal_moves)
        if not has_mate_in_one:
            return False, "No checkmate-in-one moves exist in this board state"
        return True, ""
        
    elif category in ["ambiguous_rook", "ambiguous_bishop", "ambiguous_knight"]:
        piece_char = {
            "ambiguous_rook": "R",
            "ambiguous_bishop": "B",
            "ambiguous_knight": "N"
        }[category]
        
        # Regex explanation:
        # ^[RBN] piece abbreviation
        # [a-h1-8] file or rank character used to disambiguate (e.g. Rad1, R1d1, Nbd5)
        # x? optional capture marker
        # [a-h][1-8] destination square
        pattern = re.compile(rf"^{piece_char}[a-h1-8]x?[a-h][1-8]")
        has_disambiguated_move = any(pattern.match(m) for m in sample_legal_moves)
        
        if not has_disambiguated_move:
            return False, f"No legal moves require SAN disambiguation for {category}"
        return True, ""
        
    return False, "Unknown category"

def validate_dataset():
    print("==================================================")
    print("STARTING 100,000 SAMPLES DATASET VALIDATION SWEEP")
    print("==================================================")
    
    total_samples = 100000
    category_counts = {cat: 0 for cat in CATEGORIES}
    category_success = {cat: 0 for cat in CATEGORIES}
    rejections = []
    category_rejections = {cat: {} for cat in CATEGORIES}
    
    unique_fens = set()
    total_pieces = 0
    total_legal_moves = 0
    
    t_start = time.perf_counter()
    
    for i in range(total_samples):
        category = CATEGORIES[i % len(CATEGORIES)]
        category_counts[category] += 1
        
        try:
            sample = BoardGenerator.generate_sample(category)
            
            # Step 2 Verification
            fen = sample["fen"]
            board = chess.Board(fen)
            
            # 1. Legal FEN / python-chess accepts
            if not board.is_valid():
                reason = "Illegal board state FEN"
                rejections.append((category, reason))
                category_rejections[category][reason] = category_rejections[category].get(reason, 0) + 1
                continue
                
            # 2. Has legal moves
            if not sample["legalMoves"]:
                reason = "No legal moves in sample"
                rejections.append((category, reason))
                category_rejections[category][reason] = category_rejections[category].get(reason, 0) + 1
                continue
                
            # 3. sideToMove correct
            expected_side = "white" if board.turn == chess.WHITE else "black"
            if sample["sideToMove"] != expected_side:
                reason = "Inconsistent sideToMove"
                rejections.append((category, reason))
                category_rejections[category][reason] = category_rejections[category].get(reason, 0) + 1
                continue
                
            # 4. legalMoves exactly match python-chess
            expected_sans = set([board.san(m) for m in board.legal_moves])
            if set(sample["legalMoves"]) != expected_sans:
                reason = "Inconsistent legalMoves set"
                rejections.append((category, reason))
                category_rejections[category][reason] = category_rejections[category].get(reason, 0) + 1
                continue
                
            # 5. Metadata and generation reason populated
            metadata = sample["metadata"]
            if "pieceCount" not in metadata or "hasCastlingRights" not in metadata or "isCheck" not in metadata:
                reason = "Incomplete metadata fields"
                rejections.append((category, reason))
                category_rejections[category][reason] = category_rejections[category].get(reason, 0) + 1
                continue
            if not sample["generationReason"]:
                reason = "Missing generation reason"
                rejections.append((category, reason))
                category_rejections[category][reason] = category_rejections[category].get(reason, 0) + 1
                continue
                
            # 6. Category satisfaction check
            satisfied, reason = verify_category_satisfaction(board, category, sample["legalMoves"])
            if not satisfied:
                rejections.append((category, reason))
                category_rejections[category][reason] = category_rejections[category].get(reason, 0) + 1
                continue
                
            # Accept sample
            unique_fens.add(fen)
            total_pieces += len(board.piece_map())
            total_legal_moves += board.legal_moves.count()
            category_success[category] += 1
            
        except Exception as e:
            reason = f"Exception during generation: {str(e)}"
            rejections.append((category, reason))
            category_rejections[category][reason] = category_rejections[category].get(reason, 0) + 1
            
        if (i + 1) % 20000 == 0:
            elapsed = time.perf_counter() - t_start
            print(f"Processed {i + 1}/100000 samples | Elapsed: {elapsed:.2f}s")
            
    t_end = time.perf_counter()
    total_elapsed = t_end - t_start
    avg_latency = (total_elapsed / total_samples) * 1000.0 # ms
    
    accepted_count = sum(category_success.values())
    rejected_count = len(rejections)
    duplicate_count = accepted_count - len(unique_fens)
    duplicate_pct = (duplicate_count / accepted_count * 100.0) if accepted_count > 0 else 0.0
    
    rejection_reasons = {}
    for cat, reason in rejections:
        rejection_reasons[reason] = rejection_reasons.get(reason, 0) + 1
        
    avg_pieces = total_pieces / accepted_count if accepted_count > 0 else 0.0
    avg_branching = total_legal_moves / accepted_count if accepted_count > 0 else 0.0
    
    report = {
        "total_generated": total_samples,
        "accepted": accepted_count,
        "rejected": rejected_count,
        "rejection_reasons": rejection_reasons,
        "duplicate_rate_pct": duplicate_pct,
        "unique_fens": len(unique_fens),
        "average_piece_count": avg_pieces,
        "average_branching_factor": avg_branching,
        "average_generation_latency_ms": avg_latency,
        "category_rejections": category_rejections,
        "category_metrics": {
            cat: {
                "generated": category_counts[cat],
                "accepted": category_success[cat],
                "success_rate_pct": (category_success[cat] / category_counts[cat] * 100.0) if category_counts[cat] > 0 else 0.0
            } for cat in CATEGORIES
        }
    }
    
    print("\n==================================================")
    print("VALIDATION SWEEP COMPLETE")
    print("==================================================")
    print(f"Total Generated:  {total_samples}")
    print(f"Accepted:         {accepted_count}")
    print(f"Rejected:         {rejected_count}")
    print(f"Duplicate Rate:   {duplicate_pct:.2f}%")
    print(f"Unique FENs:      {len(unique_fens)}")
    print(f"Avg Pieces:       {avg_pieces:.2f}")
    print(f"Avg Branching:    {avg_branching:.2f}")
    print(f"Avg Latency:      {avg_latency:.3f} ms")
    
    print("\nRejection Reasons Summary:")
    for reason, count in rejection_reasons.items():
        print(f"  - {reason}: {count}")
        
    print("\nCategory-specific Rejections:")
    for cat in CATEGORIES:
        if category_rejections[cat]:
            print(f"  Category: {cat}")
            for r, count in category_rejections[cat].items():
                print(f"    * {r}: {count}")
                
    print("\nCategory Success Rates:")
    for cat, metrics in report["category_metrics"].items():
        print(f"  - {cat:<20}: {metrics['success_rate_pct']:.2f}% success")
    print("==================================================")
    
    with open("validation_report.json", "w") as f:
        json.dump(report, f, indent=2)
    print("Saved validation report to validation_report.json")

if __name__ == "__main__":
    validate_dataset()
