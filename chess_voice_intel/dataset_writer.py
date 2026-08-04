import json

class DatasetWriter:
    """
    Handles file writing operations for the generated dataset, support JSONL stream output.
    """
    def __init__(self, file_path):
        self.file_path = file_path
        # Open file in write mode
        self.file = open(file_path, 'w', encoding='utf-8')

    def write_example(self, example):
        """
        Appends a single validated example as a JSON Line.
        """
        line = json.dumps(example, ensure_ascii=False)
        self.file.write(line + '\n')
        self.file.flush()

    def close(self):
        """
        Closes the file stream.
        """
        if self.file and not self.file.closed:
            self.file.close()

    @staticmethod
    def save_all_as_json_array(file_path, examples):
        """
        Saves the entire list of examples as a single formatted JSON array.
        """
        with open(file_path, 'w', encoding='utf-8') as f:
            json.dump(examples, f, indent=2, ensure_ascii=False)
