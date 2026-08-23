"""
Conservative AI Chatter Cleaner
================================
ONLY removes actual AI-generated preamble/chatter from options.
Does NOT touch short legitimate answers, does NOT flag similar options.
"""
import json, glob, os, re

BANK_DIR = os.path.join(os.path.dirname(__file__), '..', '..', 'assets', 'banks')
REPLACEMENT = 'كل الاقتراحات خاطئة'

# Pure AI chatter patterns (start-of-option only, must be the MAIN content)
CHATTER_START = re.compile(
    r'^(?:'
    r'بالطبع[,:]?\s*'
    r'|إليكم[,:]?\s*'
    r'|إليك[,:]?\s*'
    r'|إليكم[,:]?\s*'
    r'|بالتأكيد[,:]?\s*'
    r'|ها هي[,:]?\s*'
    r'|هنا هي[,:]?\s*'
    r'|ها ثلاث[,:]?\s*'
    r'|هنا ثلاث[,:]?\s*'
    r'|سأقوم[,:]?\s*'
    r'|سأعيد[,:]?\s*'
    r'|سأقدم[,:]?\s*'
    r'|يمكنني إعادة\s+'
    r'|يمكنني تقديم\s+'
    r'|يمكنني تعديل\s+'
    r'|أقدم\s+'
    r'|بطبيعة الحال[,:]?\s*'
    r'|كمساعد ذكاء[^,]*,?\s*'
    r'|بصفتي[^,]*,?\s*'
    r'|كنموذج[^,]*,?\s*'
    r'|عذراً?[,:]\s*'
    r'|عذراً على[^.]*[.]\s*'
    r'|أعتذر[^,]*,?\s*'
    r'|في سياق[^.]*[،,]\s*'
    r'|في إطار[^.]*[،,]\s*'
    r'|خلال[^.]*[،,]\s*'
    r'|في المقاربة[^.]*[،,]\s*'
    r'|في مرحلة[^.]*[،,]\s*'
    r'|في مجال[^.]*[،,]\s*'
    r'|الخيارات المقترحة[^.]*[.]\s*'
    r'|الخيارات الخاطئة[^.]*[،,]\s*'
    r')', re.IGNORECASE
)

# Label prefixes to strip (keep content after the colon)
LABEL_PREFIX = re.compile(
    r'^(?:'
    r'الخيار\s+\d+\s*\(.*?\)\s*:\s*'
    r'|الخيار\s+\d+\s*:\s*'
    r'|خيار خاطئ\s*(?:مفصل\s*)?\d*\s*:\s*'
    r'|خيار خاطئ\s*(?:أول|ثان|ثالث)\s*(?:معدل|معدّل)\s*:\s*'
    r'|الخيار الخاطئ\s*(?:الأول|الثاني|الثالث)\s*:\s*'
    r')', re.IGNORECASE
)

def fix_option(opt):
    if not opt or not opt.strip():
        return REPLACEMENT, 'empty'
    opt = opt.strip()

    # 0. Strip leading comma/semicolon leftover from option splitting
    opt = re.sub(r'^[,،;]\s*', '', opt).strip()
    if not opt:
        return REPLACEMENT, 'empty'

    # 1. Pure chatter preamble (short options that are just AI text)
    m = CHATTER_START.match(opt)
    if m:
        rest = opt[m.end():].strip()
        # If option is mostly chatter (total < 20 chars after stripping) -> replace
        if len(rest) < 15 or words_ar(opt) < 6:
            return REPLACEMENT, 'chatter_pure'
        # If there's substantial content after chatter, strip the prefix
        if words_ar(rest) >= 3:
            return rest, 'chatter_stripped'
        return REPLACEMENT, 'chatter_short'

    # 2. Label prefix -> strip and keep content
    m = LABEL_PREFIX.match(opt)
    if m:
        rest = opt[m.end():].strip()
        if len(rest) > 10 and words_ar(rest) >= 2:
            return rest, 'label_stripped'

    return opt, 'ok'

def words_ar(text):
    return len(text.split())

def main():
    total_fixed = 0
    total_questions = 0
    methods = {}
    files_modified = set()

    for f in sorted(glob.glob(os.path.join(BANK_DIR, '*.json'))):
        data = json.loads(open(f, encoding='utf-8').read())
        changed = False
        fname = os.path.basename(f)

        for subj, qs in data.items():
            for q in qs:
                total_questions += 1
                opts = q.get('options', [])
                for i in range(len(opts)):
                    fixed, method = fix_option(opts[i])
                    if method != 'ok':
                        if fixed != opts[i]:
                            opts[i] = fixed
                            total_fixed += 1
                            changed = True
                            methods[method] = methods.get(method, 0) + 1

        if changed:
            with open(f, 'w', encoding='utf-8') as out:
                json.dump(data, out, ensure_ascii=False, indent=2)
            files_modified.add(fname)

    print('=' * 60)
    print('CONSERVATIVE AI CHATTER CLEANUP REPORT')
    print('=' * 60)
    print(f'Total questions scanned:  {total_questions}')
    print(f'Options cleaned:          {total_fixed}')
    print(f'Files modified:           {len(files_modified)}')
    print()
    print('By method:')
    for k, v in sorted(methods.items(), key=lambda x: -x[1]):
        print(f'  {k:25s} : {v}')
    print()
    print('Files modified:')
    for f in sorted(files_modified):
        print(f'  - {f}')

if __name__ == '__main__':
    main()
