# Piece Name Variations
PIECE_NAMES = {
    "P": ["pawn", "the pawn", "my pawn", "this pawn", "that pawn", ""],
    "N": ["knight", "the knight", "my knight", "this knight", "that knight", "horse", "the horse"],
    "B": ["bishop", "the bishop", "my bishop", "this bishop", "that bishop"],
    "R": ["rook", "the rook", "my rook", "this rook", "that rook", "castle", "the castle"],
    "Q": ["queen", "the queen", "my queen", "this queen", "that queen"],
    "K": ["king", "the king", "my king", "this king", "that king"]
}

# Capture Verbs
CAPTURE_VERBS = [
    "takes",
    "captures",
    "capture",
    "take",
    "takes on",
    "capture on",
    "takes the piece on",
    "captures on"
]

# Castling Variations
KINGSIDE_CASTLING = [
    "castle",
    "castle kingside",
    "kingside castle",
    "castle short",
    "short castle",
    "go ahead and castle short",
    "i'll castle kingside"
]

QUEENSIDE_CASTLING = [
    "castle queenside",
    "queenside castle",
    "castle long",
    "long castle",
    "go ahead and castle long",
    "i'll castle queenside"
]

# Promotion Variations
PROMOTION_TARGETS = {
    "q": ["queen", "a queen", "to queen", "to a queen", "promote to queen"],
    "r": ["rook", "a rook", "to rook", "to a rook", "promote to rook"],
    "b": ["bishop", "a bishop", "to bishop", "to a bishop", "promote to bishop"],
    "n": ["knight", "a knight", "to knight", "to a knight", "promote to knight"]
}

PROMOTION_PHRASES = [
    "promote to {target}",
    "promotion to {target}",
    "make it a {target}",
    "promote pawn to {target}",
    "and promote to {target}",
    "promoting to {target}"
]

# Check Variations
CHECK_SUFFIXES = [
    "check",
    "giving check",
    "check the king",
    "with check",
    "putting the king in check"
]

# Checkmate Variations
MATE_SUFFIXES = [
    "mate",
    "checkmate",
    "that's mate",
    "deliver checkmate",
    "and that is checkmate",
    "mating move"
]

# En-Passant Wording
EN_PASSANT_PHRASES = [
    "en passant",
    "capture the pawn en passant",
    "take en passant",
    "capture en passant",
    "takes en passant"
]

# Conversational & Natural Openers
NATURAL_OPENERS = [
    "let's move",
    "can you move",
    "go ahead and move",
    "i'll play",
    "please move",
    "how about",
    "let's play",
    "can you play",
    "move",
    "i want to move",
    "i'll move"
]

# Square Name Conversions (supporting spelling variations like 'f three' or 'f3')
FILE_NAMES = {
    "a": ["a", "alpha"],
    "b": ["b", "bravo"],
    "c": ["c", "charlie"],
    "d": ["d", "delta"],
    "e": ["e", "echo"],
    "f": ["f", "foxtrot"],
    "g": ["g", "golf"],
    "h": ["h", "hotel"]
}

RANK_NAMES = {
    "1": ["one", "1"],
    "2": ["two", "2"],
    "3": ["three", "3"],
    "4": ["four", "4"],
    "5": ["five", "5"],
    "6": ["six", "6"],
    "7": ["seven", "7"],
    "8": ["eight", "8"]
}
