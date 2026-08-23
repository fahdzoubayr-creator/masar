#!/usr/bin/env python3
import sys, io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
with open(r"D:\masar_app\masar_app\lib\core\services\question_validator.dart", "r", encoding="utf-8") as f:
    lines = f.readlines()
for i in range(95, 108):
    print(f"{i+1}: {repr(lines[i])}")
