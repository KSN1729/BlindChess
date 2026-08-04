import math

class DatasetStatisticsReporter:
    """
    Analyzes the final dataset list of dictionaries and compiles a comprehensive statistical report.
    """
    @staticmethod
    def generate_report(examples):
        total = len(examples)
        if total == 0:
            return "Empty dataset. No statistics to report."

        # Initialize counts
        pieces = {'p': 0, 'n': 0, 'b': 0, 'r': 0, 'q': 0, 'k': 0, 'castle': 0}
        squares = {}
        noise_count = 0
        capture_count = 0
        promotion_count = 0
        castling_count = 0
        total_ambiguity = 0
        difficulties = {'easy': 0, 'medium': 0, 'hard': 0, 'expert': 0}

        for ex in examples:
            # Piece
            p = ex.get('piece', '')
            is_castle = bool(ex.get('castle', ''))
            if is_castle:
                pieces['castle'] += 1
                castling_count += 1
            else:
                pieces[p] = pieces.get(p, 0) + 1

            # Square
            dest = ex.get('destination', '')
            if dest:
                squares[dest] = squares.get(dest, 0) + 1

            # Noise
            stt = ex.get('stt', '').strip()
            normalized = ex.get('normalized', '').strip()
            # If STT transcript is different from clean normalized transcript, it has noise
            if stt != normalized:
                noise_count += 1

            # Capture
            if ex.get('capture', False):
                capture_count += 1

            # Promotion
            if ex.get('promotion', ''):
                promotion_count += 1

            # Ambiguity (number of legal moves in FEN state)
            total_ambiguity += len(ex.get('legalMoves', []))

            # Difficulty
            diff = ex.get('difficulty', ex.get('difficultyLevel', 'easy'))
            # Backward compatibility check
            if not diff:
                diff = 'easy'
            difficulties[diff] = difficulties.get(diff, 0) + 1

        avg_ambiguity = total_ambiguity / total
        noise_frequency = (noise_count / total) * 100
        capture_freq = (capture_count / total) * 100
        promotion_freq = (promotion_count / total) * 100
        castling_freq = (castling_count / total) * 100

        # Sort squares
        sorted_squares = sorted(squares.items(), key=lambda x: x[1], reverse=True)
        top_squares = sorted_squares[:8]
        bottom_squares = sorted_squares[-8:]

        # Calculate dataset balance score using entropy of piece distribution (excluding castle)
        # Higher entropy = more balanced piece distribution
        piece_counts = [count for p, count in pieces.items() if p != 'castle']
        total_pieces_counted = sum(piece_counts)
        entropy = 0.0
        if total_pieces_counted > 0:
            for count in piece_counts:
                prob = count / total_pieces_counted
                if prob > 0:
                    entropy -= prob * math.log2(prob)
        max_entropy = math.log2(len(piece_counts)) # Max possible entropy for 6 classes
        balance_index = (entropy / max_entropy) * 100 if max_entropy > 0 else 0

        # Compile report
        report = []
        report.append("# Chess Voice Intelligence - Dataset Statistics Report")
        report.append(f"**Total Examples Generated**: {total}\n")
        
        report.append("## 1. Dataset Difficulty Profile")
        report.append("| Difficulty | Count | Proportion (%) |")
        report.append("|------------|-------|----------------|")
        for diff, count in difficulties.items():
            report.append(f"| {diff.capitalize():<10} | {count:<5} | {(count/total)*100:<14.2f} |")
        report.append("")

        report.append("## 2. Speech & Phonetic Noise metrics")
        report.append(f"- **Proportion of Noisy Transcripts (STT != Clean)**: {noise_frequency:.2f}%")
        report.append(f"- **Average Legal Move Ambiguity (Average branching factor)**: {avg_ambiguity:.2f} moves")
        report.append(f"- **Capture Frequency**: {capture_freq:.2f}%")
        report.append(f"- **Promotion Frequency**: {promotion_freq:.2f}%")
        report.append(f"- **Castling Frequency**: {castling_freq:.2f}%")
        report.append("")

        report.append("## 3. Piece Distribution")
        report.append("| Piece | Count | Proportion (%) |")
        report.append("|-------|-------|----------------|")
        p_names = {'p': 'Pawn', 'n': 'Knight', 'b': 'Bishop', 'r': 'Rook', 'q': 'Queen', 'k': 'King', 'castle': 'Castling'}
        for p, count in pieces.items():
            name = p_names.get(p, p)
            report.append(f"| {name:<8} | {count:<5} | {(count/total)*100:<14.2f} |")
        report.append(f"\n- **Dataset Balance Index (Entropy based)**: {balance_index:.2f}% (Higher is more balanced across pieces)\n")

        report.append("## 4. Square Frequencies (Top 8 and Bottom 8 Destination Squares)")
        report.append("### Top 8 Squares")
        report.append("| Square | Frequency | Percentage (%) |")
        report.append("|--------|-----------|----------------|")
        for sq, count in top_squares:
            report.append(f"| {sq:<6} | {count:<9} | {(count/total)*100:<14.2f} |")
            
        report.append("\n### Bottom 8 Squares")
        report.append("| Square | Frequency | Percentage (%) |")
        report.append("|--------|-----------|----------------|")
        for sq, count in bottom_squares:
            report.append(f"| {sq:<6} | {count:<9} | {(count/total)*100:<14.2f} |")
            
        return "\n".join(report)
