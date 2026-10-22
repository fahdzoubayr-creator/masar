#!/usr/bin/env python3
"""
استخراج نصوص ملفات المراجعة إلى ملفات .txt لتوليد كويزات المحاور.

المدخلات:  <stage>/manifest-plan.json  (المخرجات من tools/prep_review_files.cjs)
المخرجات:  <stage>/<slug>__<NN>.txt
            وي��دَّث الفهرس assets/review_files/manifest.json بإضافة حقل txt.
"""
import json
import os
import sys
import time

import pymupdf

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STAGE = sys.argv[1] if len(sys.argv) > 1 else r"E:\masar_static\review_v3"
MANIFEST = os.path.join(REPO, "assets", "review_files", "manifest.json")
LIMIT = int(sys.argv[2]) if len(sys.argv) > 2 else 0  # 0 = الكل

plan = json.load(open(os.path.join(STAGE, "manifest-plan.json"), "r", encoding="utf-8"))
files = plan["files"]
if LIMIT:
    files = files[:LIMIT]

manifest = json.load(open(MANIFEST, "r", encoding="utf-8"))
# pdf path -> entry
by_pdf = {}
for folder, entries in manifest.items():
    for e in entries:
        by_pdf[e["pdf"]] = (folder, e)

t0 = time.time()
ok = empty = fail = 0
for i, f in enumerate(files, 1):
    src = f["src"]
    dst = os.path.join(STAGE, f["release"].replace(".pdf", ".txt"))
    try:
        doc = pymupdf.open(src)
        chunks = [page.get_text("text") for page in doc]
        doc.close()
        lines = [ln.strip() for ln in "\n".join(chunks).splitlines()]
        lines = [ln for ln in lines if ln]
        out = "\n".join(lines)
        if len(out) < 40:
            empty += 1
            continue
        with open(dst, "w", encoding="utf-8") as fh:
            fh.write(out)
        ok += 1
    except Exception as exc:  # noqa: BLE001
        fail += 1
        print("  ! %s: %s" % (f["release"], exc))
    if i % 25 == 0:
        print("  %d/%d  (%.1fs)" % (i, len(files), time.time() - t0))

print("texts ok=%d empty=%d failed=%d  elapsed=%.1fs" % (ok, empty, fail, time.time() - t0))

# تحديث الفهرس: إضافة مسار النص لكل ملف (نفس رقم ملف الـPDF)
n = 0
for f in files:
    pdf_path = f["pdf"]
    if pdf_path not in by_pdf:
        continue
    folder, entry = by_pdf[pdf_path]
    txt_release = f["release"].replace(".pdf", ".txt")
    if not os.path.exists(os.path.join(STAGE, txt_release)):
        # ملف ممسوح ضوئياً: لا نصّ مستخرج — يُترك بلا حقل txt.
        continue
    txt_path = "assets/review_files/%s/%s" % (folder, pdf_path.split("/")[-1].replace(".pdf", ".txt"))
    entry["txt"] = txt_path
    n += 1
json.dump(manifest, open(MANIFEST, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
print("manifest entries with txt: %d" % n)
