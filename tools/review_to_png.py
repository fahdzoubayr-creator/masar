#!/usr/bin/env python3
"""تحويل صفحات مراجعات PDF إلى صور عالية الدقة عبر MuPDF.

الغرض: تحرير العارض المتصفح من تشكيل الحروف العربية داخل pdf.js (الذي يفسد
الملفات غير المضمّنة الخط) — تُحوَّل كل صفحة إلى منحنيات/صورة نهائية سليمة.

الاستخدام:
  python tools/review_to_png.py --pdf <ملف.pdf> --out <مجلد> [--zoom 2] [--page <N>]
"""
import argparse
import json
import sys
from pathlib import Path
import pymupdf


def rasterize(pdf_path: Path, out_dir: Path, zoom: float, page_only: int | None) -> dict:
    out_dir.mkdir(parents=True, exist_ok=True)
    doc = pymupdf.open(pdf_path)
    pages = doc.page_count
    natural = []
    targets = range(1, pages + 1) if page_only is None else [page_only]
    for pn in targets:
        page = doc.load_page(pn - 1)
        r = page.rect
        scale = zoom
        mat = pymupdf.Matrix(scale, scale)
        pix = page.get_pixmap(matrix=mat, alpha=False)
        target = out_dir / f"p{pn:02d}.png"
        pix.save(target)
        natural.append((round(r.width), round(r.height)))
    doc.close()
    return {"mode": "png", "pages": pages, "natural": natural, "zoom": zoom}


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--pdf", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--zoom", type=float, default=2.0)
    ap.add_argument("--page", type=int, default=None)
    args = ap.parse_args()

    pdf = Path(args.pdf)
    if not pdf.is_file():
        print(json.dumps({"error": "NOT_FOUND"}), file=sys.stderr)
        sys.exit(2)
    meta = rasterize(pdf, Path(args.out), args.zoom, args.page)
    if args.page is None:
        (Path(args.out) / "meta.json").write_text(
            json.dumps(meta, ensure_ascii=False), encoding="utf-8"
        )
    print(json.dumps(meta, ensure_ascii=False))


if __name__ == "__main__":
    main()