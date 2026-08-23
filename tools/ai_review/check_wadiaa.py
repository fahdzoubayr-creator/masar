#!/usr/bin/env python3
import re, sys, io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
with open(r'D:\masar_app\masar_app\lib\core\data\wadiaa_bank_data.dart', encoding='utf-8') as f:
    content = f.read()
blocks = content.split('Question(')
for i, b in enumerate(blocks[1:], 1):
    m_opts = re.search(r'options:\s*\[(.*?)\]', b, re.DOTALL)
    m_idx = re.search(r'correctIndex:\s*(\d+)', b)
    if not m_opts or not m_idx:
        continue
    opts = re.findall(r"'[^']*'", m_opts.group(1))
    idx = int(m_idx.group(1))
    if len(opts) != 5 or idx >= len(opts):
        print(f"Q{i}: {len(opts)} opts, idx={idx}")
