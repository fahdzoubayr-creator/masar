"""Fix the SKIP_LOCAL set in rag_generate_cloud.py"""
import re
p = r'D:\masar_app\masar_app\tools\ai_review\rag_generate_cloud.py'
with open(p, 'r', encoding='utf-8') as f:
    content = f.read()
# Replace SKIP_LOCAL line
content = content.replace(
    "SKIP_LOCAL = set()",
    "SKIP_LOCAL = {'\u0645\u0624\u0633\u0633\u0627\u062a \u0627\u0644\u0631\u064a\u0627\u062f\u0629'}"
)
with open(p, 'w', encoding='utf-8') as f:
    f.write(content)
with open(p, 'r', encoding='utf-8') as f:
    for i, line in enumerate(f, 1):
        if 'SKIP_LOCAL' in line:
            print(f'{i}: {line.strip()}')
