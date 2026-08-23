#!/usr/bin/env python3
import re, sys, io, json
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

content = open(r"D:\masar_app\masar_app\lib\core\data\french_didactics_bank_4_data.dart", encoding="utf-8").read()

pattern = re.compile(r"(?:const\s+)?Question\s*\(", re.MULTILINE)
matches = list(pattern.finditer(content))
print(f"Found {len(matches)} Question( blocks")

def extract_string_value(text, key):
    for quote in ["'", '"']:
        pat = rf"{key}\s*:\s*{quote}"
        m = re.search(pat, text)
        if not m:
            continue
        start = m.end()
        buf = []
        i = start
        while i < len(text):
            ch = text[i]
            if ch == "\\" and i + 1 < len(text):
                nxt = text[i + 1]
                if nxt == quote:
                    buf.append(quote)
                elif nxt == "'":
                    buf.append("'")
                elif nxt == '"':
                    buf.append('"')
                elif nxt == "n":
                    buf.append("\n")
                elif nxt == "\\":
                    buf.append("\\")
                else:
                    buf.append(ch)
                    buf.append(nxt)
                i += 2
            elif ch == quote:
                break
            else:
                buf.append(ch)
                i += 1
        return "".join(buf).strip()
    return None

def extract_int_value(text, key):
    m = re.search(rf"{key}\s*:\s*(\d+)", text)
    return int(m.group(1)) if m else None

def parse_options_array(text):
    m = re.search(r"options\s*:\s*\[", text)
    if not m:
        return []
    start = m.end()
    depth = 1
    pos = start
    while pos < len(text) and depth > 0:
        if text[pos] == "[":
            depth += 1
        elif text[pos] == "]":
            depth -= 1
        pos += 1
    options_text = text[start:pos - 1]
    options = []
    i = 0
    n = len(options_text)
    while i < n:
        c = options_text[i]
        if c in ("'", '"'):
            quote = c
            i += 1
            buf = []
            while i < n:
                ch = options_text[i]
                if ch == "\\" and i + 1 < n:
                    nxt = options_text[i + 1]
                    if nxt == quote:
                        buf.append(quote)
                    elif nxt == "'":
                        buf.append("'")
                    elif nxt == '"':
                        buf.append('"')
                    elif nxt == "n":
                        buf.append("\n")
                    elif nxt == "\\":
                        buf.append("\\")
                    else:
                        buf.append(ch)
                        buf.append(nxt)
                    i += 2
                elif ch == quote:
                    i += 1
                    break
                else:
                    buf.append(ch)
                    i += 1
            options.append("".join(buf))
        elif c.isalpha() or c == "_":
            j = i
            while j < n and (options_text[j].isalnum() or options_text[j] in "_."):
                j += 1
            var_name = options_text[i:j]
            options.append(f"__ref__{var_name}")
            i = j
        else:
            i += 1
    return options

# Parse first 3 blocks
for idx, m in enumerate(matches[:3]):
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

    text_val = extract_string_value(inner, "text")
    opts = parse_options_array(inner)
    ci = extract_int_value(inner, "correctIndex")

    print(f"\n--- Q{idx+1} ---")
    print(f"  text: {text_val[:80] if text_val else 'NONE'}...")
    print(f"  options({len(opts)}): {opts[:3]}...")
    print(f"  correctIndex: {ci}")
