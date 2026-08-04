import random

class ConfigurableNoiseGenerator:
    """
    A configurable phonetic corruption engine to simulate STT transcription mistakes.
    """
    SUBSTITUTIONS = {
        'rook': ['rock', 'ruk', 'roch', 'brook', 'look', 'hook', 'ruke', 'ruuk', 'wook'],
        'bishop': ['fishup', 'bishup', 'bishep', 'b shop', 'bisop', 'biship'],
        'knight': ['night', 'nite', 'nait', 'knite', 'light', 'fight', 'kite'],
        'queen': ['clean', 'green', 'screen', 'keen', 'qween', 'quean', 'kween'],
        'king': ['ring', 'wing', 'sing', 'thing', 'kling', 'ging', 'kin'],
        'pawn': ['pon', 'pan', 'pawnn', 'paun', 'palm', 'pong'],
        
        # Files
        'a': ['ey', 'ay', 'a', 'eh'],
        'b': ['bee', 'be', 'b', 'beat'],
        'c': ['see', 'sea', 'c', 'she'],
        'd': ['dee', 'de', 'd', 'tea'],
        'e': ['ee', 'e', 'he', 'eat'],
        'f': ['eff', 'ef', 'f', 'half'],
        'g': ['gee', 'je', 'g', 'chief'],
        'h': ['aitch', 'h', 'age', 'each', 'eight'],
        
        # Ranks / numbers
        '1': ['one', 'won', 'wonn', '1', "won't"],
        '2': ['two', 'to', 'too', '2', 'through'],
        '3': ['three', 'free', 'tree', '3', 'thread'],
        '4': ['four', 'for', 'fore', '4', 'fall'],
        '5': ['five', 'fife', '5', 'fight'],
        '6': ['six', 'sicks', '6', 'seek'],
        '7': ['seven', 'sevan', '7', 'send'],
        '8': ['eight', 'ate', '8', 'hate'],
        
        # Actions
        'to': ['two', 'too', 'do', '2'],
        'takes': ['tax', 'take', 'techs', 'ticks'],
        'captures': ['captors', 'capture', 'copters'],
        'castle': ['cassel', 'vessel', 'passable', 'cast']
    }

    INSERTIONS = ['uh', 'um', 'please', 'like', 'actually', 'move', 'now', 'play']

    def __init__(self, 
                 sub_rate=0.30, 
                 del_rate=0.08, 
                 ins_rate=0.10, 
                 repeat_rate=0.10, 
                 split_rate=0.12, 
                 merge_rate=0.08):
        self.sub_rate = sub_rate
        self.del_rate = del_rate
        self.ins_rate = ins_rate
        self.repeat_rate = repeat_rate
        self.split_rate = split_rate
        self.merge_rate = merge_rate

    def corrupt(self, clean_text):
        """
        Takes a clean spoken string and applies configurable corruption operations.
        """
        words = clean_text.lower().strip().split()
        corrupted_words = []
        
        i = 0
        while i < len(words):
            word = words[i]
            
            # 1. Word Merging (Check if we can merge current word with next word)
            if self.merge_rate > 0 and (i + 1 < len(words)) and random.random() < self.merge_rate:
                merged = f"{word}{words[i+1]}"
                corrupted_words.append(merged)
                i += 2
                continue
                
            # 2. Word Deletion (Drop word entirely)
            if self.del_rate > 0 and random.random() < self.del_rate:
                i += 1
                continue
                
            # 3. Word Splitting (e.g. e1 -> e one, or knight -> kni ght)
            if self.split_rate > 0 and len(word) == 2 and random.random() < self.split_rate:
                # E.g. e1 -> e one
                char1 = word[0]
                char2 = word[1]
                # Map rank digit to word form sometimes
                if char2 in self.SUBSTITUTIONS:
                    char2 = random.choice(self.SUBSTITUTIONS[char2])
                corrupted_words.extend([char1, char2])
                i += 1
                continue

            # 4. Word Substitution / Phonetic Swaps
            if self.sub_rate > 0 and word in self.SUBSTITUTIONS and random.random() < self.sub_rate:
                corrupted_words.append(random.choice(self.SUBSTITUTIONS[word]))
            else:
                corrupted_words.append(word)

            # 5. Stutter / Word Repetition
            if self.repeat_rate > 0 and random.random() < self.repeat_rate:
                corrupted_words.append(word)
                
            i += 1

        # 6. Random Word Insertions (hesitations, fillers)
        if self.ins_rate > 0 and random.random() < self.ins_rate:
            filler = random.choice(self.INSERTIONS)
            insert_idx = random.randint(0, len(corrupted_words))
            corrupted_words.insert(insert_idx, filler)
            
        return " ".join([w for w in corrupted_words if w]).strip()
