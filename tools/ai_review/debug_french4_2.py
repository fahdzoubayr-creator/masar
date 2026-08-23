#!/usr/bin/env python3
import re, sys, io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

content = open(r"D:\masar_app\masar_app\lib\core\data\french_didactics_bank_4_data.dart", encoding="utf-8").read()

pattern = re.compile(r"(?:const\s+)?Question\s*\(", re.MULTILINE)
m = list(pattern.finditer(content))[0]
start = m.start()
depth = 1
pos = m.end()
while pos < len(content) and depth > 0:
    if content[pos] == "(":
        depth += 1
    elif content[pos] == ")":
        depth -= 1
    pos += 1
block = content[start:pos]
inner = block[block.index("(") + 1: -1]

print("=== FULL INNER TEXT ===")
print(repr(inner))
print()
print("=== SEARCHING FOR options ===")
opt_match = re.search(r"options\s*:\s*\[", inner)
print(f"options match: {opt_match}")
print()
print("=== SEARCHING FOR correctIndex ===")
ci_match = re.search(r"correctIndex\s*:\s*(\d+)", inner)
print(f"correctIndex match: {ci_match}")
if ci_match:
    print(f"  value: {ci_match.group(1)}")
