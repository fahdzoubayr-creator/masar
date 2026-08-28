#!/usr/bin/env python3
"""توليد صور صفحات جميع ملفات الكاش دفعة واحدة عبر review_to_png."""
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

PROJECT = Path(r"D:\masar_app\masar_app")
CACHE = PROJECT / "assets" / "review_files_cache"
OUT = PROJECT / "assets" / "review_pages_cache"
TOOL = PROJECT / "tools" / "review_to_png.py"


def done_key(pdf: Path) -> Path:
    return OUT / (pdf.name[: -len(".pdf")]) / "meta.json"


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    pdfs = sorted(p for p in CACHE.iterdir() if p.suffix.lower() == ".pdf")
    jobs = [p for p in pdfs if not done_key(p).exists()]
    if not jobs:
        print(f"All {len(pdfs)} files already rasterized.")
        return
    print(f"Rasterizing {len(jobs)} files x2...")

    def work(p: Path):
        out_dir = OUT / p.name[: -len(".pdf")]
        r = subprocess.run(
            [sys.executable, str(TOOL), "--pdf", str(p), "--out", str(out_dir), "--zoom", "2.0"],
            capture_output=True, text=True, encoding="utf-8", timeout=300,
        )
        if r.returncode == 0:
            return (p.name, True, "")
        return (p.name, False, (r.stderr or r.stdout)[-200:])

    t0 = time.time()
    ok = fail = 0
    with ThreadPoolExecutor(max_workers=4) as pool:
        futs = {pool.submit(work, p): p for p in jobs}
        for i, fut in enumerate(as_completed(futs), 1):
            name, good, err = fut.result()
            if good:
                ok += 1
            else:
                fail += 1
                print(f"[{i}/{len(jobs)}] FAIL {name}: {err}")
            if i % 10 == 0:
                print(f"... {i}/{len(jobs)} ({ok} ok)")
    print(f"\nDone in {time.time() - t0:.0f}s: {ok} ok, {fail} failed.")


if __name__ == "__main__":
    main()