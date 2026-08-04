from dataclasses import dataclass, asdict
from typing import Dict, Any

@dataclass
class SpeechSample:
    """
    Represents a single generated spoken command corresponding to a legal chess move.
    """
    spokenText: str
    canonicalMove: str  # e.g., 'e2e4'
    SAN: str
    UCI: str
    category: str
    language: str
    variationType: str  # formal, conversational, minimal, verbose, natural
    metadata: Dict[str, Any]
    generationReason: str

    def to_dict(self) -> Dict[str, Any]:
        """Converts the SpeechSample to a dictionary."""
        return {
            "spokenText": self.spokenText,
            "canonicalMove": self.canonicalMove,
            "SAN": self.SAN,
            "UCI": self.UCI,
            "category": self.category,
            "language": self.language,
            "variationType": self.variationType,
            "metadata": self.metadata,
            "generationReason": self.generationReason
        }
