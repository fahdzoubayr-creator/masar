"""
Comprehensive Question Bank Validator & Auto-Fixer
===================================================
Checks:
  1. Structural: 5 options, each 3-30 words, correctIndex 0-4
  2. Blacklist: AI chatter keywords in option text
  3. Suspicious punctuation: ends with ':', starts with 'الخيار N:'
  4. Duplicate options: >80% similarity within same question
  5. Empty/placeholder options
  6. Short options (< 8 chars)
"""
import json, glob, os, re, sys
from difflib import SequenceMatcher

BANK_DIR = os.path.join(os.path.dirname(__file__), '..', '..', 'assets', 'banks')
REPLACEMENT = 'كل الاقتراحات خاطئة'

BLACKLIST_PATTERNS = [
    r'بالطبع',
    r'إليكم',
    r'إليك\b',
    r'إليكم',
    r'بالتأكيد',
    r'ها هي',
    r'هنا هي',
    r'ها ثلاث',
    r'هنا ثلاث',
    r'سأقوم',
    r'سأعيد',
    r'سأقدم',
    r'سأقدم',
    r'يمكنني إعادة',
    r'يمكنني تقديم',
    r'يمكنني تقديم',
    r'مرحباً',
    r'مرحبا',
    r'أهلاً',
    r'أهلا',
    r'بسم الله',
    r'شكراً',
    r'عذراً',
    r'عذرا على',
    r'عذراً على',
    r'أعتذر',
    r'كمساعد ذكاء',
    r'مساعد ذكاء',
    r'بصفتي',
    r'كنموذج ذكاء',
    r'كمساعد',
    r'الأكثر شيوعاً',
    r'الأكثر شيوعا',
    r'يمكنك اختيار',
    r'يمكنك اختيار',
]

LABEL_PREFIXES = [
    r'^الخيار\s+\d+\s*\(.*?\)\s*:\s*',
    r'^الخيار\s+\d+\s*:\s*',
    r'^خيار خاطئ\s*(?:مفصل\s*)?\d*\s*:\s*',
    r'^خيار خاطئ\s*(?:أول|ثان|ثالث)\s*(?:معدل|معدّل)\s*:\s*',
    r'^الخيار الخاطئ\s*(?:الأول|الثاني|الثالث)\s*:\s*',
    r'^خيار\s+(?:معتمد فقط على|يعتمد فقط على)\s*',
]

def words_ar(text):
    return len(text.split())

def has_blacklist(text):
    for p in BLACKLIST_PATTERNS:
        if re.search(p, text, re.IGNORECASE):
            return p
    return None

def has_label_prefix(text):
    for p in LABEL_PREFIXES:
        m = re.match(p, text)
        if m:
            return m, text[m.end():].strip()
    return None, None

def similarity(a, b):
    return SequenceMatcher(None, a, b).ratio()

def is_valid_option(opt):
    issues = []
    if not opt or not opt.strip():
        issues.append('empty')
        return issues
    opt = opt.strip()
    wc = words_ar(opt)
    if wc < 3:
        issues.append(f'too_short({wc}w)')
    if wc > 30:
        issues.append(f'too_long({wc}w)')
    if len(opt) < 8:
        issues.append(f'too_short_chars({len(opt)})')
    bl = has_blacklist(opt)
    if bl:
        issues.append(f'blacklist({bl})')
    m, stripped = has_label_prefix(opt)
    if m:
        issues.append(f'label_prefix')
    if opt.endswith(':') or opt.endswith('؟'):
        if not opt.endswith('؟'):
            issues.append(f'ends_colon')
    return issues

def fix_option(opt):
    if not opt or not opt.strip():
        return REPLACEMENT, 'empty_replaced'
    opt = opt.strip()
    # Try label prefix strip
    m, stripped = has_label_prefix(opt)
    if m and stripped and len(stripped) > 15:
        return stripped, 'label_stripped'
    # Pure chatter -> replace
    bl = has_blacklist(opt)
    if bl and words_ar(opt) < 8:
        return REPLACEMENT, 'chatter_replaced'
    # Chatter within text: try to strip leading chatter sentence
    for p in BLACKLIST_PATTERNS:
        cm = re.search(p, opt, re.IGNORECASE)
        if cm and cm.start() == 0:
            rest = opt[cm.end():].strip()
            rest = re.sub(r'^[:,\s]+', '', rest)
            if len(rest) > 15 and words_ar(rest) >= 3:
                return rest, 'chatter_stripped'
    return opt, 'ok'

def main():
    total_fixed = 0
    total_questions = 0
    total_options = 0
    issues_by_type = {}
    files_modified = set()

    for f in sorted(glob.glob(os.path.join(BANK_DIR, '*.json'))):
        data = json.loads(open(f, encoding='utf-8').read())
        changed = False
        fname = os.path.basename(f)

        for subj, qs in data.items():
            for q in qs:
                total_questions += 1
                opts = q.get('options', [])
                total_options += len(opts)

                # Fix individual options
                for i in range(len(opts)):
                    issues = is_valid_option(opts[i])
                    if issues:
                        fixed, method = fix_option(opts[i])
                        for issue in issues:
                            key = issue.split('(')[0]
                            issues_by_type[key] = issues_by_type.get(key, 0) + 1
                        if fixed != opts[i]:
                            opts[i] = fixed
                            total_fixed += 1
                            changed = True

                # Check duplicates
                prev_opts = []
                for i, opt in enumerate(opts):
                    opt_lower = opt.strip().lower()
                    is_dup = False
                    for prev_lower in prev_opts:
                        if similarity(opt_lower, prev_lower) > 0.80:
                            issues_by_type['duplicate_pair'] = issues_by_type.get('duplicate_pair', 0) + 1
                            opts[i] = REPLACEMENT
                            total_fixed += 1
                            changed = True
                            is_dup = True
                            break
                    if not is_dup:
                        prev_opts.append(opt_lower)

                # Re-verify: still 5 options
                while len(opts) < 5:
                    opts.append(REPLACEMENT)
                    changed = True
                while len(opts) > 5:
                    opts.pop()
                    changed = True

                # Re-verify correctIndex
                ci = q.get('correctIndex', 0)
                if ci < 0 or ci > 4:
                    q['correctIndex'] = 0
                    changed = True

        if changed:
            with open(f, 'w', encoding='utf-8') as out:
                json.dump(data, out, ensure_ascii=False, indent=2)
            files_modified.add(fname)

    print('=' * 60)
    print('VALIDATION & AUTO-FIX REPORT')
    print('=' * 60)
    print(f'Total questions scanned:     {total_questions}')
    print(f'Total options scanned:       {total_options}')
    print(f'Options fixed/replaced:      {total_fixed}')
    print(f'Files modified:              {len(files_modified)}')
    print()
    print('Issues found by type:')
    for k, v in sorted(issues_by_type.items(), key=lambda x: -x[1]):
        print(f'  {k:30s} : {v}')
    print()
    print('Files modified:')
    for f in sorted(files_modified):
        print(f'  - {f}')

if __name__ == '__main__':
    main()
