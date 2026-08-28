# -*- coding: utf-8 -*-
"""Audit & clean the main quiz bank (assets/banks/game_challenges.json).

Usage:
  python tools/clean_game_bank.py --dry-run   # report only
  python tools/clean_game_bank.py --apply     # rewrite the JSON in place
"""
import argparse
import collections
import json
import re
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")

BANK = Path(__file__).resolve().parent.parent / "assets" / "banks" / "game_challenges.json"

TASHCHEEL = re.compile(r"[\u064B-\u065F\u0670\u0640\u200B-\u200F\u2028-\u202F\u2060-\u2069]")
AR = re.compile(r"[\u0600-\u06FF]")
LATIN = re.compile(r"[A-Za-z]")
DIGIT = re.compile(r"\d")


def _norm(s: str) -> str:
    return TASHCHEEL.sub("", s).replace(" ", "").replace("\u200c", "")


# --- خيارات «كل ما سبق خاطئ» بأشكالها المتباينة --------------------------
_BOGUS_OPTIONS = [
    "كل الاقتراحات خاطئة", "كل الاقتراحات السابقة خاطئة",
    "كل الاختيارات خاطئة", "كل الاختيارات السابقة خاطئة",
    "كل الخيارات خاطئة", "كل ما سبق", "كل ما سبق خاطئ", "كل ما ذكر",
    "جميع ما سبق", "جميع ما سبق خاطئ", "جميع الإجابات خاطئة",
    "جميع الاقتراحات خاطئة", "جميع الاختيارات خاطئة", "جميع الخيارات خاطئة",
    "جميع الإجابات أعلاه خاطئة", "جميع ما أعلاه خاطئ",
    "لا شيء مما سبق", "لاشيء مما سبق", "لا شيء مما سبق صحيح",
    "لا شيء مما ذكر", "لا شيء من هذا", "لا شيء من هذه",
    "لا توجد إجابة صحيحة", "لا توجد إجابة", "لا أي من الخيارات صحيحة",
    "كل الإجابات خاطئة", "لا شيء صحيح", "لا شيء مما سبق ذكره",
    "كل الاقتراحات السابقة صحيحة", "كل الاختيارات السابقة صحيحة",
    "جميع ما سبق صحيح", "كل ما سبق صحيح", "لا شيئ مما سبق",
]
_BOGUS_NORM = {_norm(x) for x in _BOGUS_OPTIONS}

# قرارات مصحّحة (عبر فحص Groq) لأسئلة كانت إجابتها «كل ما سبق خاطئ»:
# المفتاح = النص المطبع، القيمة = الخيار الصحيح (أ/ب/ج) أو "لا شيء" بحذفه.
RESOLVED = {k: v for k, v in
            json.loads((Path(__file__).resolve().parent / "bank_fix_resolutions.json")
                       .read_text(encoding="utf-8")).items()}


def is_bogus(opt: str) -> bool:
    return _norm(opt) in _BOGUS_NORM


# --- دمج الحروف المنفصلة (ك كلمة / الم تقاطع بينها) ----------------------
_CLITIC1 = {"و", "ف", "ب", "ك", "ل", "س", "ه"}
_CLITICPREF = {"ال", "وال", "فال", "بال", "كال", "لل", "الم", "والم", "فالم",
               "بالم", "كالم", "للم", "الإ", "والأ", "فلأ", "بلأ", "كلأ"}


def merge_tokens(toks):
    out = []
    for t in toks:
        if not t:
            continue
        if (out and AR.search(t) and not LATIN.search(t) and not DIGIT.search(t)):
            prev = out[-1]
            if prev in _CLITIC1:
                out[-1] = prev + t
                continue
            if prev in _CLITICPREF and not re.match(r"^[ال][ل]", t):
                out[-1] = prev + t
                continue
        out.append(t)
    return out


def fix_arabic(s: str) -> str:
    s = TASHCHEEL.sub("", s)
    s = re.sub(r"[ \t]+", " ", s)
    s = re.sub(r"\s+([،؛:؟?.,])", r"\1", s)
    s = re.sub(r"([({\[«])\s+", r"\1", s)
    s = re.sub(r"\s+([)\]}»])", r"\1", s)
    s = re.sub(r"\u200c", " ", s)
    s = s.strip()
    if not AR.search(s):
        return s
    merged = merge_tokens(s.split(" "))
    return " ".join(merged).strip()


GARBAGE_ALL = re.compile(r"```|</?[a-zA-Z][^>]*>|\{\{|\}\}|OPTIONS:|CORRECT:|\blorem\b|\bplaceholder\b",
                         re.IGNORECASE)

# --- استرجاع «كل ما سبق خاطئ» عند كونه الإجابة الصحيحة --------------------
_POS = ["استقصاء", "ملاحظة", "تساؤل", "تجريب", "تجارب", "تحليل", "توجيه", "فرصة",
        "متدرج", "التدرج", "بناء", "تعلم", "تعلم", "مناقش", "استنتاج", "تعاون",
        "احترام", "ملموس", "مواد حية", "بيئته", "حقوق", "استقلال", "واقعه",
        "يفسر", "شرح", "توضيح", "واضح", "دقيقة", "مسبق", "خطط", "يبحث", "بحث",
        "حرية", "فضول", "ثقة", "تعديل", "تصورات", "يتعلم", "يطور", "ينم", "رابط"]
_NEG = ["فقط", "مجرد", "دون", "لا ", "لم ", "ليس", "تجاهل", "توبيخ", "معاقب",
        "مضيعة", "إيقاف", "يربك", "إرباك", "خاطئ", "خطأ", "غير مهم", "لا أهمية",
        "لا علاقة", "يُعاقب", "حفظ"]

def option_score(opt: str) -> int:
    s = 0
    for w in _POS:
        if w in opt:
            s += 2
    for w in _NEG:
        if w in opt:
            s -= 3
    if len(opt) >= 20:
        s += 1
    return s


def pick_real(real_opts, exclude_norm=None):
    """يختار الخيار الواقعي الصحيح من بين [ (index, text), ... ]."""
    scored = [(option_score(o), i, o) for i, o in real_opts
              if o and (exclude_norm is None or _norm(o) not in exclude_norm)]
    if not scored:
        return None
    scored.sort(key=lambda x: (-x[0], x[1]))
    best_s, best_i, best_o = scored[0]
    second_s = scored[1][0] if len(scored) > 1 else None
    if best_s <= 0:
        return None
    if second_s is not None and best_s - second_s < 3:
        return None
    return (best_i, best_o)


def clean_one(q):
    """يُرجع (cleaned_q | None, reason)"""
    text = (q.get("text") or "").strip()
    opts = [(o or "").strip() for o in q.get("options", [])]
    ci = q.get("correctIndex", -1)

    if len(text) < 8:
        return None, "empty_text"
    if TASHCHEEL.sub("", text).lstrip().startswith("المحور الخامس"):
        return None, "starts_mohor_5"
    if GARBAGE_ALL.search(text) or GARBAGE_ALL.search(" ".join(opts)):
        return None, "garbage"
    if ci < 0 or ci >= len(opts):
        return None, "bad_correct_index"
    if any(not o for o in opts):
        return None, "empty_option"
    if len(set(_norm(o) for o in opts)) != len(opts):
        return None, "dup_options_before"

    bogus_idx = [i for i, o in enumerate(opts) if is_bogus(o)]

    # الحالة 1: الإجابة الصحيحة مسندة لخيار «كل ما سبق خاطئ» -> استرجاعه
    if bogus_idx and ci in bogus_idx:
        real = [(i, o) for i, o in enumerate(opts) if i not in bogus_idx]
        letters = ["أ", "ب", "ج", "د", "هـ"]
        decided = RESOLVED.get(_norm(text))
        if decided == "لا شيء":
            return None, "all_wrong_no_real"
        if decided and decided in letters:
            chosen = real[letters.index(decided)] if len(real) >= letters.index(decided) + 1 else None
            best_o = chosen[1] if chosen else None
        else:
            picked = pick_real(real)
            best_o = picked[1] if picked else None
        if best_o is None:
            return None, "all_wrong_no_real"
        copts = [o for o in (fix_arabic(o) for _, o in real) if o and not is_bogus(o)]
        copts = list(dict.fromkeys(copts))
        target = fix_arabic(best_o)
        if target not in copts:
            return None, "recover_target_lost"
        cci = copts.index(target)
        if len(set(_norm(o) for o in copts)) != len(copts):
            return None, "dup_options_after_clean"
        cq = dict(q)
        cq["text"] = fix_arabic(text)
        cq["options"] = copts
        cq["correctIndex"] = cci
        cq["explanation"] = fix_arabic(q.get("explanation") or "")
        return cq, None

    # الحالة 2: خيار «كل ما سبق خاطئ» مشرك (ليس الإجابة) -> احذفه
    copts = [o for o in (fix_arabic(o) for o in opts) if o and not is_bogus(o)]
    copts = list(dict.fromkeys(copts))
    removed_before = sum(1 for i0, o in enumerate(opts)
                         if i0 < ci and (not o or is_bogus(o)))
    cci = ci - removed_before
    if not copts:
        return None, "no_options_after_clean"
    if cci < 0 or cci >= len(copts):
        return None, "bad_correct_after_clean"
    if len(set(_norm(o) for o in copts)) != len(copts):
        return None, "dup_options_after_clean"
    cq = dict(q)
    cq["text"] = fix_arabic(text)
    cq["options"] = copts
    cq["correctIndex"] = cci
    cq["explanation"] = fix_arabic(q.get("explanation") or "")
    return cq, None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true")
    args = ap.parse_args()

    data = json.loads(BANK.read_text(encoding="utf-8"))
    allq = [(theme, q) for theme, arr in data.items() for q in arr]
    total = len(allq)

    stats = collections.Counter()
    samples = collections.defaultdict(list)
    recovered = collections.Counter()

    def log(key, msg):
        if len(samples[key]) < 10:
            samples[key].append(msg)

    best_by_key = {}
    removed_reasons = collections.Counter()
    order_keys = []

    for theme, q in allq:
        cq, reason = clean_one(q)
        if cq is None:
            removed_reasons[reason] += 1
            log(reason, (theme, (q.get("text") or "")[:110], q.get("subject", theme)))
            continue
        if reason is None:
            key = _norm(cq["text"])
            prev = best_by_key.get(key)
            if prev is None or len(cq["explanation"]) > len(prev[1]["explanation"]):
                best_by_key[key] = (theme, cq)
            else:
                stats["duplicate_dropped"] += 1
    stats["total"] = total
    stats["kept"] = len(best_by_key)

    # إحصاء المكررات
    dup_groups = collections.defaultdict(lambda: [None, []])
    for key, (theme, cq) in best_by_key.items():
        dup_groups[key][0] = cq["text"]
        dup_groups[key][1].append(cq.get("subject") or theme)
    # نعيد بناء قائمة كل النصوص (قبل الdedup) لعد المكررات
    counts = collections.Counter()
    texts_all = collections.Counter()
    for theme, q in allq:
        cq, reason = clean_one(q)
        if cq is not None:
            texts_all[_norm(cq["text"])] += 1
    stats["duplicate_extra_instances"] = sum(c - 1 for c in texts_all.values() if c > 1)

    # توزيع أوضاع الخيارات بعد التنظيف
    n3 = n4 = n5 = 0
    for key, (theme, cq) in best_by_key.items():
        l = len(cq["options"])
        if l == 3: n3 += 1
        elif l == 4: n4 += 1
        elif l == 5: n5 += 1
    stats["options_3/4/5"] = f"{n3}/{n4}/{n5}"

    final = collections.Counter()
    for key, (theme, cq) in best_by_key.items():
        final[cq.get("subject") or theme] += 1

    lines = []
    lines.append("=== game_challenges.json audit ===")
    lines.append("total=%d kept=%d duplicate_extra_instances=%d" %
                 (stats['total'], stats['kept'], stats['duplicate_extra_instances']))
    lines.append("removed_by_reason=" + json.dumps(removed_reasons, ensure_ascii=False))
    lines.append("options_lengths_3_4_5=" + stats["options_3/4/5"])
    for k, v in sorted(samples.items()):
        lines.append(f"\n-- [{k}] ({len(v)} samples) --")
        for s in v:
            lines.append("   " + json.dumps(s, ensure_ascii=False)[:170])
    lines.append("\nFINAL per subject after cleaning:")
    for k, v in sorted(final.items()):
        lines.append(f"  {v:4d}  {k}")

    out_txt = BANK.parent / "bank_clean_report.txt"
    out_txt.write_text("\n".join(lines), encoding="utf-8")
    print("\n".join(lines))

    if args.apply:
        grouped = collections.defaultdict(list)
        for key, (theme, cq) in best_by_key.items():
            grouped[theme].append(cq)
        out = {t: grouped[t] for t in data if t in grouped}
        tmp = BANK.with_suffix(".json.tmp")
        tmp.write_text(json.dumps(out, ensure_ascii=False, indent=1), encoding="utf-8")
        tmp.replace(BANK)
        print(f"\nAPPLIED: {BANK} rewritten ({len(best_by_key)} questions)")


if __name__ == "__main__":
    main()