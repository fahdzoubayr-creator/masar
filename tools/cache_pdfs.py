#!/usr/bin/env python3
"""Pre-download ALL review PDFs from GitHub Releases into server disk cache."""
import json, os, sys, re, time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
import requests as rq

PROJECT = Path(r"D:\masar_app\masar_app")
CACHE = PROJECT / "assets" / "review_files_cache"
MANIFEST = PROJECT / "assets" / "review_files" / "manifest.json"
RELEASE_BASE = "https://github.com/fahdzoubayr-creator/masar/releases/download/review-files-v1/"
FOLDER_SLUGS = {
    "التعليم الثانوي بسلكيه": "taalim_thaanawi",
    "بنك الاسئلة": "bank_asila",
    "خطاطات ذهنية": "khatatat_dhahniya",
    "دورات تكوينية": "dawrat_takwiniya",
    "ديداكتيك الرياضيات": "didaktik_riyadiya",
    "مؤسسة الريادة": "mouassasat_riyada",
    "مؤسسات الريادة": "mouassasat_riyada",
    "_misc_illustrations": "misc_illustrations",
    "مراسلات ومذكرات": "murasalat_wamudhakirat",
    "مشروع المؤسسة المندمج": "mashrou3_almassa_almudjam3",
    "مشروع الم长寿ية": "mashrou3_almassa_almudjam3",
    "نموذجيات": "namudhajiyat",
    "التشريع المدرسي": "tachrii_madrasii",
    "ديداكتيك اللغة العربية": "didaktik_lugha",
    "النشاط العلمي": "nashat_3ilmi",
    "التنشيط التربوي": "tanashit_tarbawi",
    "علوم التربية": "ouloum_tarbawiya",
    "ديداكتيك اللغة الفرنسية": "didaktik_francais",
}
NONE_SLUG = "none"


def main():
    CACHE.mkdir(parents=True, exist_ok=True)
    d = json.load(open(MANIFEST, encoding="utf-8"))
    existing = {f.name for f in CACHE.iterdir()} if CACHE.exists() else set()

    jobs = []
    for folder, entries in d.items():
        slug = FOLDER_SLUGS.get(folder, NONE_SLUG)
        for e in entries:
            pdf = e.get("pdf", "")
            m = re.search(r"[/\\](\d+)\.pdf$", pdf)
            if not m:
                continue
            num = m.group(1)
            release_name = f"{slug}__{num}.pdf"
            cache_name = f"{slug}__{num}.pdf"
            if cache_name in existing:
                continue
            url = RELEASE_BASE + release_name
            jobs.append((cache_name, url))

    if not jobs:
        print(f"All {len(existing)} files cached.")
        return

    print(f"Downloading {len(jobs)} files ({len(existing)} already cached)...")
    ok = fail = 0

    def dl(nu):
        name, url = nu
        tmp = CACHE / (name + ".part")
        try:
            r = rq.get(url, timeout=120, headers={"User-Agent": "masar-cache"})
            r.raise_for_status()
            tmp.write_bytes(r.content)
            tmp.rename(CACHE / name)
            return (name, len(r.content), None)
        except Exception as ex:
            tmp.unlink(missing_ok=True)
            return (name, 0, str(ex)[:80])

    t0 = time.time()
    with ThreadPoolExecutor(max_workers=4) as pool:
        futs = {pool.submit(dl, j): j for j in jobs}
        for i, fut in enumerate(as_completed(futs), 1):
            name, sz, err = fut.result()
            if err:
                fail += 1
                print(f"[{i}/{len(jobs)}] FAIL {name}: {err}")
            else:
                ok += 1
                print(f"[{i}/{len(jobs)}] OK {name} ({sz // 1024}KB)")

    elapsed = time.time() - t0
    total_bytes = sum(f.stat().st_size for f in CACHE.iterdir())
    print(f"\nDone in {elapsed:.0f}s: {ok} new, {fail} failed, {len(existing) + ok} total.")
    print(f"Cache: {total_bytes // 1024 // 1024}MB on disk.")


if __name__ == "__main__":
    main()
