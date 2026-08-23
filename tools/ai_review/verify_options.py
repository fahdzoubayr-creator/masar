#!/usr/bin/env python3
"""Debug: verify option count and correctIndex for every question in a file."""
import re, sys, io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

def verify_file(path):
    with open(path, encoding='utf-8') as f:
        content = f.read()
    
    # Split on Question( 
    blocks = content.split('Question(')
    print(f"File: {path.split(chr(92))[-1]}  -- {len(blocks)-1} questions")
    
    issues = 0
    for i, b in enumerate(blocks[1:], 1):
        m_opts = re.search(r'options:\s*\[(.*?)\]', b, re.DOTALL)
        m_idx = re.search(r'correctIndex:\s*(\d+)', b)
        if not m_opts or not m_idx:
            continue
        opts_raw = m_opts.group(1)
        opts = re.findall(r"'[^']*'|\"[^\"]*\"", opts_raw)
        idx = int(m_idx.group(1))
        m_txt = re.search(r"text:\s*'((?:[^'\\]|\\.)*)'", b)
        txt = m_txt.group(1)[:50] if m_txt else "?"
        
        if idx >= len(opts):
            print(f"  Q{i}: correctIndex={idx} >= {len(opts)} options -- FIX NEEDED: {txt}")
            issues += 1
        elif len(opts) != 4:
            print(f"  Q{i}: {len(opts)} options (not 4) -- correctIndex={idx}: {txt}")
            issues += 1
    
    print(f"  -> {issues} issues found\n")
    return issues

total = 0
import glob
for f in glob.glob(r'D:\masar_app\masar_app\lib\core\data\*bank*.dart'):
    if 'education_sciences' in f:
        continue
    total += verify_file(f)
print(f"TOTAL across all files: {total}")
