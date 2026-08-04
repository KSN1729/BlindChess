import json
import numpy as np
import tensorflow as tf
from tensorflow.keras import layers, Model
import os
import random
import keras

# Set random seed for reproducibility
np.random.seed(42)
tf.random.set_seed(42)

# Load dataset
def load_dataset(path="chess_voice_intel/dataset.json"):
    with open(path, "r") as f:
        return json.load(f)

# Vocabulary and Tokenizer Definition
class ChessVoiceTokenizer:
    def __init__(self, pad_token="[PAD]", sos_token="[SOS]", eos_token="[EOS]", sep_token="[SEP]", unk_token="[UNK]"):
        self.pad_token = pad_token
        self.sos_token = sos_token
        self.eos_token = eos_token
        self.sep_token = sep_token
        self.unk_token = unk_token
        
        # Build character & word piece vocabulary from domain rules
        special_tokens = [pad_token, sos_token, eos_token, sep_token, unk_token]
        files = list("abcdefgh")
        ranks = list("12834567")
        pieces = ["pawn", "knight", "bishop", "rook", "queen", "king"]
        noise_words = [
            "rock", "ruk", "roch", "brook", "look", "hook", "ruke", "ruuk", "wook",
            "fishup", "b", "shop", "bishep", "bishup", "bishopp", "bisop", "biship",
            "night", "nite", "nait", "knite", "light", "fight", "kite",
            "clean", "green", "screen", "keen", "qween", "quean", "kween",
            "ring", "wing", "sing", "thing", "kling", "ging", "kin",
            "pon", "pan", "pawnn", "paun", "palm", "pong"
        ]
        spellings = [
            "ey", "ay", "a", "eh", "bee", "be", "beat", "see", "sea", "she",
            "dee", "de", "tea", "ee", "he", "eat", "eff", "ef", "half", "gee", "je",
            "chief", "aitch", "age", "each", "one", "won", "wonn", "two", "to", "too",
            "three", "free", "tree", "four", "for", "fore", "five", "fife", "six", "sicks",
            "seven", "sevan", "eight", "ate", "hate", "castle", "kingside", "queenside",
            "takes", "takes on", "captures", "x", "promote to", "equals", "promotion to",
            "please", "move", "go", "i", "want", "play", "can", "you", "do", "let's",
            "make", "the", "uh", "um", "how", "about", "think"
        ]
        
        # Merge all into vocab
        unique_tokens = list(dict.fromkeys(special_tokens + files + ranks + pieces + noise_words + spellings))
        # Ensure single characters are available
        for char in "abcdefghijklmnopqrstuvwxyz12345678#+=-/\\ ":
            if char not in unique_tokens:
                unique_tokens.append(char)
                
        self.vocab = unique_tokens
        self.token_to_id = {token: i for i, token in enumerate(self.vocab)}
        self.id_to_token = {i: token for token, i in self.token_to_id.items()}
        self.vocab_size = len(self.vocab)

    def encode(self, text, max_len=256, is_target=False):
        # Normalize and split into words/characters
        text = text.lower().strip()
        words = text.split()
        tokens = []
        
        if is_target:
            tokens.append(self.sos_token)
            # Targets are typically SAN moves, tokenized character-by-character
            for char in text.replace(" ", ""):
                tokens.append(char if char in self.token_to_id else self.unk_token)
            tokens.append(self.eos_token)
        else:
            tokens.append(self.sos_token)
            for word in words:
                if word in self.token_to_id:
                    tokens.append(word)
                else:
                    # Split unknown words into characters
                    for char in word:
                        tokens.append(char if char in self.token_to_id else self.unk_token)
            tokens.append(self.eos_token)

        # Padding
        if len(tokens) < max_len:
            tokens += [self.pad_token] * (max_len - len(tokens))
        else:
            tokens = tokens[:max_len]
            
        return [self.token_to_id[t] for t in tokens]

    def decode(self, ids):
        tokens = []
        for idx in ids:
            token = self.id_to_token.get(idx, self.unk_token)
            if token == self.eos_token or token == self.pad_token:
                break
            if token not in [self.sos_token, self.sep_token]:
                tokens.append(token)
        return "".join(tokens)

    def save(self, path="chess_voice_intel/tokenizer.json"):
        data = {
            "vocab": self.vocab,
            "token_to_id": self.token_to_id,
            "vocab_size": self.vocab_size
        }
        with open(path, "w") as f:
            json.dump(data, f, indent=2)


# Custom Transformer Block Layers for TFLite compilation
class PositionalEmbedding(layers.Layer):
    def __init__(self, sequence_length, vocab_size, embed_dim, **kwargs):
        super().__init__(**kwargs)
        self.token_embeddings = layers.Embedding(input_dim=vocab_size, output_dim=embed_dim)
        self.position_embeddings = layers.Embedding(input_dim=sequence_length, output_dim=embed_dim)
        self.sequence_length = sequence_length
        self.vocab_size = vocab_size
        self.embed_dim = embed_dim

    def call(self, inputs):
        import keras.ops as ops
        length = ops.shape(inputs)[-1]
        positions = ops.arange(length)
        embedded_tokens = self.token_embeddings(inputs)
        embedded_positions = self.position_embeddings(positions)
        return embedded_tokens + embedded_positions

    def compute_mask(self, inputs, mask=None):
        import keras.ops as ops
        return ops.not_equal(inputs, 0)


class TransformerEncoder(layers.Layer):
    def __init__(self, embed_dim, dense_dim, num_heads, **kwargs):
        super().__init__(**kwargs)
        self.embed_dim = embed_dim
        self.dense_dim = dense_dim
        self.num_heads = num_heads
        self.attention = layers.MultiHeadAttention(num_heads=num_heads, key_dim=embed_dim)
        self.dense_proj = keras.Sequential([
            layers.Dense(dense_dim, activation="relu"),
            layers.Dense(embed_dim),
        ])
        self.layernorm_1 = layers.LayerNormalization()
        self.layernorm_2 = layers.LayerNormalization()

    def call(self, inputs, mask=None):
        import keras.ops as ops
        if mask is not None:
            # MultiHeadAttention mask must be of shape (batch, query_seq, key_seq)
            padding_mask = ops.cast(mask[:, None, :], dtype="int32")
        else:
            padding_mask = None
            
        attention_output = self.attention(
            query=inputs, value=inputs, key=inputs, attention_mask=padding_mask
        )
        proj_input = self.layernorm_1(inputs + attention_output)
        proj_output = self.dense_proj(proj_input)
        return self.layernorm_2(proj_input + proj_output)


class TransformerDecoder(layers.Layer):
    def __init__(self, embed_dim, latent_dim, num_heads, **kwargs):
        super().__init__(**kwargs)
        self.embed_dim = embed_dim
        self.latent_dim = latent_dim
        self.num_heads = num_heads
        self.attention_1 = layers.MultiHeadAttention(num_heads=num_heads, key_dim=embed_dim)
        self.attention_2 = layers.MultiHeadAttention(num_heads=num_heads, key_dim=embed_dim)
        self.dense_proj = keras.Sequential([
            layers.Dense(latent_dim, activation="relu"),
            layers.Dense(embed_dim),
        ])
        self.layernorm_1 = layers.LayerNormalization()
        self.layernorm_2 = layers.LayerNormalization()
        self.layernorm_3 = layers.LayerNormalization()

    def call(self, inputs, encoder_outputs, mask=None):
        import keras.ops as ops
        # Causal attention mask for decoder using coordinate comparison
        input_shape = ops.shape(inputs)
        seq_len = input_shape[1]
        
        q_idx = ops.arange(seq_len)[:, None]
        k_idx = ops.arange(seq_len)[None, :]
        causal_mask = ops.cast(q_idx >= k_idx, dtype="int32")
        causal_mask = ops.expand_dims(causal_mask, axis=0) # Shape: [1, seq_len, seq_len]

        attention_output_1 = self.attention_1(
            query=inputs, value=inputs, key=inputs, attention_mask=causal_mask
        )
        out_1 = self.layernorm_1(inputs + attention_output_1)

        # Cross attention block
        attention_output_2 = self.attention_2(
            query=out_1, value=encoder_outputs, key=encoder_outputs
        )
        out_2 = self.layernorm_2(out_1 + attention_output_2)

        # Feed Forward projection
        proj_output = self.dense_proj(out_2)
        return self.layernorm_3(out_2 + proj_output)


def build_seq2seq_model(src_seq_len, tar_seq_len, vocab_size, embed_dim=128, dense_dim=256, num_heads=4):
    # Encoder
    encoder_inputs = layers.Input(shape=(src_seq_len,), dtype="int32", name="encoder_inputs")
    x = PositionalEmbedding(src_seq_len, vocab_size, embed_dim)(encoder_inputs)
    encoder_outputs = TransformerEncoder(embed_dim, dense_dim, num_heads)(x)
    
    # Decoder
    decoder_inputs = layers.Input(shape=(tar_seq_len,), dtype="int32", name="decoder_inputs")
    y = PositionalEmbedding(tar_seq_len, vocab_size, embed_dim)(decoder_inputs)
    y = TransformerDecoder(embed_dim, dense_dim, num_heads)(y, encoder_outputs)
    
    # Dense Projection
    decoder_outputs = layers.Dense(vocab_size, activation="softmax", name="outputs")(y)
    
    model = Model([encoder_inputs, decoder_inputs], decoder_outputs, name="chess_voice_transformer")
    return model


def main():
    # Load dataset
    dataset = load_dataset()
    tokenizer = ChessVoiceTokenizer()
    tokenizer.save()
    print(f"Tokenizer vocabulary size: {tokenizer.vocab_size}")
    
    # Preprocess inputs and targets
    src_seq_len = 256
    tar_seq_len = 10
    
    encoder_input_data = []
    decoder_input_data = []
    decoder_target_data = []
    
    # Prepare board generalization FEN split (Out-of-distribution FEN logic)
    fens = list(set([ex['fen'] for ex in dataset]))
    random.shuffle(fens)
    split_idx = int(len(fens) * 0.8)
    train_fens = set(fens[:split_idx])
    
    train_examples = []
    val_examples = []
    
    for ex in dataset:
        if ex['fen'] in train_fens:
            train_examples.append(ex)
        else:
            val_examples.append(ex)
            
    print(f"Train examples: {len(train_examples)}, Validation examples: {len(val_examples)}")
    
    def process_split(examples):
        enc_in = []
        dec_in = []
        dec_tar = []
        for ex in examples:
            # Prompt syntax: STT [SEP] FEN [SEP] LEGAL_MOVES
            stt = ex['stt']
            fen = ex['fen']
            legal_moves = ",".join(ex['legalMoves'])
            
            prompt = f"{stt} [SEP] {fen} [SEP] {legal_moves}"
            
            # Correct SAN move
            target_move = ex['correctMove']
            
            enc_encoded = tokenizer.encode(prompt, max_len=src_seq_len, is_target=False)
            dec_encoded = tokenizer.encode(target_move, max_len=tar_seq_len + 1, is_target=True)
            
            enc_in.append(enc_encoded)
            # Decoder input is shifted by 1 (starts with [SOS] and omits [EOS])
            dec_in.append(dec_encoded[:-1])
            # Target output is shifted by 1 (omits [SOS] and ends with [EOS])
            dec_tar.append(dec_encoded[1:])
            
        return np.array(enc_in), np.array(dec_in), np.array(dec_tar)
        
    X_train_enc, X_train_dec, y_train = process_split(train_examples)
    X_val_enc, X_val_dec, y_val = process_split(val_examples)
    
    # Build Keras Seq2Seq model
    model = build_seq2seq_model(src_seq_len, tar_seq_len, tokenizer.vocab_size)
    model.summary()
    
    # Cosine decay scheduler
    initial_learning_rate = 1e-3
    decay_steps = 1000
    lr_decayed_fn = tf.keras.optimizers.schedules.CosineDecay(
        initial_learning_rate, decay_steps, alpha=0.0
    )
    
    optimizer = tf.keras.optimizers.AdamW(learning_rate=lr_decayed_fn, weight_decay=1e-4)
    model.compile(
        optimizer=optimizer,
        loss="sparse_categorical_crossentropy",
        metrics=["accuracy"]
    )
    
    # Train the model
    print("Starting training...")
    history = model.fit(
        [X_train_enc, X_train_dec],
        y_train,
        batch_size=64,
        epochs=10,
        validation_data=([X_val_enc, X_val_dec], y_val)
    )
    
    # Save the Keras model
    os.makedirs("chess_voice_intel/checkpoints", exist_ok=True)
    model.save("chess_voice_intel/checkpoints/transformer_model.keras")
    print("Model successfully trained and saved to chess_voice_intel/checkpoints/transformer_model.keras")

if __name__ == "__main__":
    main()
