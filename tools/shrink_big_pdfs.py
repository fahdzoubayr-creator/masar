#!/usr/bin/env python3
"""
ضغط ملفات PDF الكبيرة (فوق 100MB) حتى تدخل في مستودع GitHub
(الحد الأقصى 100MB للملف الواحد) دون فقدان الوضوح.

الاستعمال: python tools/shrink_big_pdfs.py <مجلد>
"""
import os
import sys

import pymupdf

LIMIT = 100 * 1024 * 1024
folder = sys.argv[1] if len(sys.argv) > 1 else r"E:\masar_static\review_v3"

for name in sorted(os.listdir(folder)):
    if not name.lower().endswith(".pdf"):
        continue
    src = os.path.join(folder, name)
    size = os.stat(src).st_size
    if size <= LIMIT:
        continue
    print("%s: %.1f MB -> compressing..." % (name, size / 1e6))
    doc = pymupdf.open(src)
    out = os.path.join(folder, name + ".tmp")
    # deflate + garbage collection + إعادة بناء الصور بلا فقد
    doc.save(out, garbage=4, deflate=True, deflate_images=True, deflate_fonts=True, clean=True)
    doc.close()
    new_size = os.stat(out).st_size
    print("   result: %.1f MB" % (new_size / 1e6))
    if new_size < size and new_size <= LIMIT:
        os.replace(out, src)
        print("   replaced OK")
    else:
        os.remove(out)
        print("   kept original")
