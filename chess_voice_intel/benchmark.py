import tensorflow as tf
import numpy as np
import json
import time
import os

class BaselineRulesParser:
    """
    A Python replica of the baseline rules-based parser for benchmark comparison.
    """
    @staticmethod
    def parse_command(text, legal_moves):
        text = text.lower().strip()
        
        # Piece matching
        pieces = {
            'rook': 'r', 'rock': 'r', 'ruk': 'r', 'roch': 'r', 'brook': 'r', 'look': 'r',
            'bishop': 'b', 'fishup': 'b', 'b shop': 'b', 'bishep': 'b', 'bishup': 'b',
            'knight': 'n', 'night': 'n', 'nite': 'n', 'nait': 'n', 'knite': 'n',
            'queen': 'q', 'clean': 'q', 'green': 'q', 'screen': 'q', 'keen': 'q',
            'king': 'k', 'ring': 'k', 'wing': 'k', 'sing': 'k',
            'pawn': 'p', 'pon': 'p', 'pan': 'p'
        }
        
        found_piece = None
        for p_name, p_symbol in pieces.items():
            if p_name in text:
                found_piece = p_symbol
                break
                
        # Castling keywords
        if 'castle' in text or 'castling' in text:
            if 'queenside' in text or 'queen side' in text or 'long' in text:
                for m in legal_moves:
                    if m.startswith('O-O-O'):
                        return m
            else:
                for m in legal_moves:
                    if m.startswith('O-O') and not m.startswith('O-O-O'):
                        return m
                        
        # Square matching (regex for letter followed by digit or phonetic name)
        files = 'abcdefgh'
        ranks = '12345678'
        
        found_file = None
        for f in files:
            if f in text:
                found_file = f
                break
                
        found_rank = None
        ranks_map = {'one': '1', 'won': '1', 'two': '2', 'to': '2', 'too': '2',
                     'three': '3', 'free': '3', 'four': '4', 'for': '4', 'five': '5',
                     'six': '6', 'seven': '7', 'eight': '8', 'ate': '8'}
        for word, val in ranks_map.items():
            if word in text:
                found_rank = val
                break
        for r in ranks:
            if r in text:
                found_rank = r
                break
                
        if not found_file or not found_rank:
            # Try square words (e.g. e1 -> he won, ee one)
            for sq in ['e1', 'e4', 'h1', 'a8', 'c3', 'f3']:
                if sq in text.replace(" ", ""):
                    found_file, found_rank = sq[0], sq[1]
                    
        if not found_file or not found_rank:
            return None # Fails destination square check
            
        target_square = f"{found_file}{found_rank}"
        
        # Filter legal moves matching piece and target square
        matches = []
        for m in legal_moves:
            clean_m = m.replace('+', '').replace('#', '').replace('x', '')
            
            # Castling handled separately
            if clean_m.startswith('O-O'):
                continue
                
            # If target matches
            if clean_m.endswith(target_square):
                # Check piece type
                first_char = clean_m[0]
                m_piece = 'p'
                if first_char in 'KQRBN':
                    m_piece = first_char.lower()
                
                # Default pawn check
                expected_piece = found_piece if found_piece else 'p'
                if m_piece == expected_piece:
                    matches.append(m)
                    
        if len(matches) == 1:
            return matches[0]
        elif len(matches) > 1:
            # Check if origin file helps
            # Filter matches containing origin files
            words = text.split()
            origin_files = [w for w in words if w in files and w != found_file]
            if origin_files:
                orig_f = origin_files[0]
                narrowed = [m for m in matches if orig_f in m]
                if len(narrowed) == 1:
                    return narrowed[0]
            return None # Ambiguous
            
        return None # No matching move found


class TFLiteInferenceEngine:
    def __init__(self, model_path="chess_voice_intel/checkpoints/model_quantized.tflite"):
        self.interpreter = tf.lite.Interpreter(model_path=model_path)
        self.interpreter.allocate_tensors()
        
        self.input_details = self.interpreter.get_input_details()
        self.output_details = self.interpreter.get_output_details()
        
        # Map inputs by name
        self.enc_index = next(x['index'] for x in self.input_details if 'encoder_inputs' in x['name'])
        self.dec_index = next(x['index'] for x in self.input_details if 'decoder_inputs' in x['name'])
        
        # Load tokenizer
        with open("chess_voice_intel/tokenizer.json", "r") as f:
            tokenizer_data = json.load(f)
        self.token_to_id = tokenizer_data["token_to_id"]
        self.id_to_token = {v: k for k, v in self.token_to_id.items()}
        
    def encode_prompt(self, text, max_len=256):
        text = text.lower().strip()
        words = text.split()
        tokens = ["[SOS]"]
        for word in words:
            if word in self.token_to_id:
                tokens.append(word)
            else:
                for char in word:
                    tokens.append(char if char in self.token_to_id else "[UNK]")
        tokens.append("[EOS]")
        if len(tokens) < max_len:
            tokens += ["[PAD]"] * (max_len - len(tokens))
        else:
            tokens = tokens[:max_len]
        return np.array([self.token_to_id[t] for t in tokens], dtype=np.int32)
        
    def predict(self, stt, fen, legal_moves_list):
        prompt = f"{stt} [SEP] {fen} [SEP] {','.join(legal_moves_list)}"
        enc_input = self.encode_prompt(prompt, 256)
        
        # Autoregressive decoding
        dec_input = np.zeros((1, 10), dtype=np.int32)
        dec_input[0, 0] = self.token_to_id["[SOS]"]
        
        predicted_chars = []
        
        for t in range(1, 10):
            # Set input tensors
            self.interpreter.set_tensor(self.enc_index, np.expand_dims(enc_input, axis=0))
            self.interpreter.set_tensor(self.dec_index, dec_input)
            
            # Run inference
            self.interpreter.invoke()
            
            # Get logits
            output_data = self.interpreter.get_tensor(self.output_details[0]['index'])
            next_token_logits = output_data[0, t - 1]
            next_id = int(np.argmax(next_token_logits))
            
            next_token = self.id_to_token.get(next_id, "[UNK]")
            if next_token == "[EOS]" or next_token == "[PAD]":
                break
                
            predicted_chars.append(next_token)
            if t < 9:
                dec_input[0, t] = next_id
                
        pred_move = "".join(predicted_chars)
        
        # Constrained alignment: map output string to closest legal move
        if pred_move in legal_moves_list:
            return pred_move
            
        # Fallback to closest edit distance/exact match substring
        best_match = None
        best_dist = 999
        for m in legal_moves_list:
            # Edit distance
            dist = self.levenshtein_distance(pred_move, m)
            if dist < best_dist:
                best_dist = dist
                best_match = m
        return best_match

    @staticmethod
    def levenshtein_distance(s1, s2):
        if len(s1) < len(s2):
            return TFLiteInferenceEngine.levenshtein_distance(s2, s1)
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


def run_benchmark(num_eval_samples=500):
    with open("chess_voice_intel/dataset.json", "r") as f:
        dataset = json.load(f)
        
    eval_set = dataset[-num_eval_samples:]
    
    # Initialize engines
    quant_engine = TFLiteInferenceEngine("chess_voice_intel/checkpoints/model_quantized.tflite")
    float_engine = TFLiteInferenceEngine("chess_voice_intel/checkpoints/model.tflite")
    
    print(f"Benchmarking on {num_eval_samples} validation samples...")
    
    # Metrics trackers
    baseline_correct = 0
    float_correct = 0
    quant_correct = 0
    
    baseline_times = []
    float_times = []
    quant_times = []
    
    for ex in eval_set:
        stt = ex['stt']
        moves = ex['legalMoves']
        correct = ex['correctMove']
        fen = ex['fen']
        
        # 1. Baseline Rules Parser
        start = time.perf_counter()
        base_res = BaselineRulesParser.parse_command(stt, moves)
        baseline_times.append(time.perf_counter() - start)
        if base_res == correct:
            baseline_correct += 1
            
        # 2. Float32 TFLite Model
        start = time.perf_counter()
        float_res = float_engine.predict(stt, fen, moves)
        float_times.append(time.perf_counter() - start)
        if float_res == correct:
            float_correct += 1
            
        # 3. Quantized INT8 TFLite Model
        start = time.perf_counter()
        quant_res = quant_engine.predict(stt, fen, moves)
        quant_times.append(time.perf_counter() - start)
        if quant_res == correct:
            quant_correct += 1
            
    # File Sizes
    float_size_mb = os.path.getsize("chess_voice_intel/checkpoints/model.tflite") / (1024*1024)
    quant_size_mb = os.path.getsize("chess_voice_intel/checkpoints/model_quantized.tflite") / (1024*1024)
    
    # Print Results Summary Table
    print("\n" + "="*50)
    print("CHESS VOICE INTELLIGENCE BENCHMARK RESULTS")
    print("="*50)
    print(f"{'Engine':<20} | {'Accuracy (%)':<12} | {'Latency (ms)':<12} | {'File Size (MB)':<14}")
    print("-"*65)
    
    base_acc = (baseline_correct / num_eval_samples) * 100
    base_lat = np.mean(baseline_times) * 1000
    print(f"{'Rules-Based Baseline':<20} | {base_acc:<12.2f} | {base_lat:<12.2f} | {'N/A (Code)':<14}")
    
    float_acc = (float_correct / num_eval_samples) * 100
    float_lat = np.mean(float_times) * 1000
    print(f"{'TFLite Float32 Model':<20} | {float_acc:<12.2f} | {float_lat:<12.2f} | {float_size_mb:<14.2f}")
    
    quant_acc = (quant_correct / num_eval_samples) * 100
    quant_lat = np.mean(quant_times) * 1000
    print(f"{'TFLite Quant INT8':<20} | {quant_acc:<12.2f} | {quant_lat:<12.2f} | {quant_size_mb:<14.2f}")
    print("="*50)
    
    print("\nDisambiguation and Noise-Tolerance details:")
    print(f"Total noise-injected cases evaluated: {sum(1 for x in eval_set if 'noise' in x['reason'])}")
    print(f"Total ambiguous cases evaluated: {sum(1 for x in eval_set if 'Disambiguation' in x['reason'])}")

if __name__ == "__main__":
    run_benchmark(500)
