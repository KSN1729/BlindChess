import tensorflow as tf
import os
import json
import numpy as np

def load_data_samples(num_samples=100):
    # Load some inputs for calibration / representative dataset just in case full INT8 is requested
    with open("chess_voice_intel/dataset.json", "r") as f:
        dataset = json.load(f)
    
    # Load tokenizer
    with open("chess_voice_intel/tokenizer.json", "r") as f:
        tokenizer_data = json.load(f)
    token_to_id = tokenizer_data["token_to_id"]
    vocab_size = tokenizer_data["vocab_size"]
    
    def encode(text, max_len=256):
        text = text.lower().strip()
        words = text.split()
        tokens = ["[SOS]"]
        for word in words:
            if word in token_to_id:
                tokens.append(word)
            else:
                for char in word:
                    tokens.append(char if char in token_to_id else "[UNK]")
        tokens.append("[EOS]")
        if len(tokens) < max_len:
            tokens += ["[PAD]"] * (max_len - len(tokens))
        else:
            tokens = tokens[:max_len]
        return [token_to_id[t] for t in tokens]

    enc_in = []
    dec_in = []
    for ex in dataset[:num_samples]:
        prompt = f"{ex['stt']} [SEP] {ex['fen']} [SEP] {','.join(ex['legalMoves'])}"
        target_move = ex['correctMove']
        
        enc_in.append(encode(prompt, 256))
        
        # Target [SOS] ...
        dec_tokens = [token_to_id["[SOS]"]] + [token_to_id[c] if c in token_to_id else token_to_id["[UNK]"] for c in target_move] + [token_to_id["[EOS]"]]
        dec_in_seq = dec_tokens[:-1]
        if len(dec_in_seq) < 10:
            dec_in_seq += [token_to_id["[PAD]"]] * (10 - len(dec_in_seq))
        else:
            dec_in_seq = dec_in_seq[:10]
        dec_in.append(dec_in_seq)
        
    return np.array(enc_in, dtype=np.int32), np.array(dec_in, dtype=np.int32)

def representative_dataset_generator():
    enc_in, dec_in = load_data_samples(50)
    for i in range(len(enc_in)):
        yield [
            np.expand_dims(enc_in[i], axis=0),
            np.expand_dims(dec_in[i], axis=0)
        ]

def main():
    model_path = "chess_voice_intel/checkpoints/transformer_model.keras"
    if not os.path.exists(model_path):
        print(f"Keras model not found at {model_path}")
        return

    # Load custom model
    print("Loading Keras model...")
    # Since we have custom layers, we must load them with custom_objects
    from train_model import PositionalEmbedding, TransformerEncoder, TransformerDecoder
    model = tf.keras.models.load_model(
        model_path,
        custom_objects={
            "PositionalEmbedding": PositionalEmbedding,
            "TransformerEncoder": TransformerEncoder,
            "TransformerDecoder": TransformerDecoder
        }
    )
    print("Keras model loaded successfully.")

    # 1. Export Standard Float32 TFLite Model
    print("Converting to standard Float32 TFLite...")
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    # Enable TF Select Ops just in case MHA needs flex operators
    converter.target_spec.supported_ops = [
        tf.lite.OpsSet.TFLITE_BUILTINS,
        tf.lite.OpsSet.SELECT_TF_OPS
    ]
    tflite_model = converter.convert()
    
    tflite_path = "chess_voice_intel/checkpoints/model.tflite"
    with open(tflite_path, "wb") as f:
        f.write(tflite_model)
    print(f"Saved Float32 model to {tflite_path} ({len(tflite_model) / (1024*1024):.2f} MB)")

    # 2. Export Dynamic Range INT8 Quantized TFLite Model
    print("Converting to dynamic-range INT8 TFLite...")
    converter_quant = tf.lite.TFLiteConverter.from_keras_model(model)
    converter_quant.optimizations = [tf.lite.Optimize.DEFAULT]
    converter_quant.target_spec.supported_ops = [
        tf.lite.OpsSet.TFLITE_BUILTINS,
        tf.lite.OpsSet.SELECT_TF_OPS
    ]
    tflite_quant_model = converter_quant.convert()
    
    tflite_quant_path = "chess_voice_intel/checkpoints/model_quantized.tflite"
    with open(tflite_quant_path, "wb") as f:
        f.write(tflite_quant_model)
    print(f"Saved quantized INT8 model to {tflite_quant_path} ({len(tflite_quant_model) / (1024*1024):.2f} MB)")

if __name__ == "__main__":
    main()
