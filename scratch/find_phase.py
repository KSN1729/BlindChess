import os
import sys

sys.stdout.reconfigure(encoding='utf-8')

log_path = r"C:\Users\nnysu\.gemini\antigravity\brain\b2de28a2-02c4-41d4-9735-9287ee7a22c7\.system_generated\tasks\task-10691.log"
if os.path.exists(log_path):
    with open(log_path, "r", encoding="utf-8") as f:
        content = f.read()
    
    # Find all EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK
    idx = 0
    while True:
        idx = content.find("EXCEPTION CAUGHT BY", idx)
        if idx == -1:
            break
        print("=== EXCEPTION FOUND ===")
        print(content[idx:idx+1500])
        print("="*60)
        idx += 1500
else:
    print("Log file not found.")
