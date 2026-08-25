#!/usr/bin/env python3
"""Upload review PDFs from a local tree to GitHub Release `review-files-v1`.

Folder layout expected:
    <SRC_DIR>/<Arabic folder name>/*.pdf

Each PDF is re-numbered <NN>.pdf (sorted by filename) and uploaded as
`<slug>__<NN>.pdf` because GitHub strips non-ASCII from release asset names.

After uploading it writes `release_manifest.json` next to this script with the
full mapping (folder -> [{pdf, name}]) so it can be pushed to the repository as
`assets/review_files/manifest.json`.

Usage:
    set SRC_DIR=C:\\path\\to\\files
    python upload_review_release.py [--delete-missing] [--dry-run]
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import urllib.parse
import urllib.request

API = "https://api.github.com/repos/fahdzoubayr-creator/masar"
UPLOADS = "https://uploads.github.com/repos/fahdzoubayr-creator/masar"
TAG = "review-files-v1"

# Arabic folder name -> ASCII slug used in release asset names.
SLUGS = {
    "التشريع المدرسي": "tachrii_madrasii",
    "التنشيط التربوي": "tanshit_tarbawi",
    "خطاطات ذهنية": "khatatat_dhihniya",
    "دورات تكوينية": "dawrat_takwiniya",
    "ديداكتيك الرياضيات": "didactique_maths",
    "ديداكتيك اللغة الأمازيغية": "didactique_amazigh",
    "ديداكتيك اللغة العربية": "didactique_arabe",
    "ديداكتيك اللغة الفرنسية": "didactique_francais",
    "ديداكتيك النشاط العلمي": "didactique_science",
    "علوم التربية": "ouloum_tarbiya",
    "مؤسسات الريادة": "mouassasat_riyada",
    "مراسلات ومذكرات": "murasilat_mudhakkirat",
    "مشروع المؤسسة المندمج": "mashroua_muassasa",
    "التعليم الثانوي بسلكيه": "taalim_thaanawi",
    "بنك الاسئلة": "bank_asila",
}


def gh_token() -> str:
    out = subprocess.run(["gh", "auth", "token"], capture_output=True, text=True)
    tok = out.stdout.strip()
    if not tok:
        sys.exit("ERROR: gh auth token unavailable — run `gh auth login` first")
    return tok


def api_req(url: str, token: str, method: str = "GET", data: bytes | None = None,
            headers: dict | None = None, timeout: int = 120):
    h = {"Authorization": f"Bearer {token}", "User-Agent": "masar-uploader",
         "Accept": "application/vnd.github+json"}
    if data is not None:
        h["Content-Type"] = "application/octet-stream"
    if headers:
        h.update(headers)
    req = urllib.request.Request(url, data=data, headers=h, method=method)
    return urllib.request.urlopen(req, timeout=timeout)


def get_release(token: str) -> dict:
    try:
        with api_req(f"{API}/releases/tags/{TAG}", token) as r:
            return json.load(r)
    except Exception:
        req = urllib.request.Request(
            f"{API}/releases", data=json.dumps({
                "tag_name": TAG,
                "name": "ملفات المراجعة PDF",
                "body": "Review files served directly inside Masar app.",
            }).encode(),
            headers={"Authorization": f"Bearer {token}", "User-Agent": "m",
                     "Content-Type": "application/json", "Accept": "application/vnd.github+json"},
            method="POST")
        with urllib.request.urlopen(req, timeout=60) as r:
            return json.load(r)


def scan_source(src: str):
    """-> [(folder_ar, slug, [abs pdf paths sorted])], skipping empty/unknown."""
    plan = []
    unknown = []
    for d in sorted(os.listdir(src)):
        p = os.path.join(src, d)
        if not os.path.isdir(p):
            continue
        pdfs = sorted(
            (f for f in os.listdir(p) if f.lower().endswith(".pdf")),
            key=str.lower,
        )
        if not pdfs:
            continue
        slug = SLUGS.get(d)
        if slug is None:
            unknown.append(d)
            continue
        plan.append((d, slug, [os.path.join(p, f) for f in pdfs]))
    return plan, unknown


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--keep-existing", action="store_true",
                    help="do not delete release assets whose number changed")
    args = ap.parse_args()

    src = os.environ.get("SRC_DIR")
    if not src or not os.path.isdir(src):
        sys.exit("ERROR: set SRC_DIR to the source folder first")

    token = gh_token()
    rel = get_release(token)
    rid = rel["id"]
    existing = {a["name"]: a["id"] for a in rel.get("assets", [])}
    plan, unknown = scan_source(src)

    wanted: dict[str, tuple[str, str]] = {}   # asset name -> (abs path, display)
    manifest: dict[str, list[dict]] = {}
    for folder, slug, paths in plan:
        entries = []
        for i, path in enumerate(paths, start=1):
            num = f"{i:02d}.pdf"
            asset = f"{slug}__{num}"
            title = os.path.splitext(os.path.basename(path))[0]
            wanted[asset] = (path, title)
            entries.append({
                "pdf": f"assets/review_files/{folder}/{num}",
                "name": title,
                "quiz": True,
            })
        manifest[folder] = entries

    stale = [n for n in existing if n not in wanted and n != "_99.txt" ]
    stale += [n for n in ("_99.txt", "tajriba_98.txt") if n in existing]

    print(f"folders={len(plan)} files_to_upload={len(wanted)} "
          f"existing_assets={len(existing)} stale={len(stale)} "
          f"unknown_folders={len(unknown)}")

    if args.dry_run:
        for n in sorted(wanted)[:5]:
            print("would upload:", n.encode("ascii", "replace").decode())
        return 0

    for name, aid in existing.items():
        if name in stale or (not args.keep_existing and name not in wanted):
            try:
                with api_req(f"{API}/releases/assets/{aid}", token, method="DELETE") as r:
                    r.read()
                print("deleted:", name.encode("ascii", "replace").decode())
            except Exception as e:
                print("delete-failed:", name.encode("ascii", "replace").decode(), e)

    ok = fail = skip = 0
    for name, (path, _title) in sorted(wanted.items()):
        if args.keep_existing and name in existing:
            skip += 1
            continue
        q = urllib.parse.urlencode({"name": name})
        try:
            with open(path, "rb") as fh:
                data = fh.read()
            with api_req(f"{UPLOADS}/releases/{rid}/assets?{q}", token,
                         method="POST", data=data, timeout=900) as r:
                json.load(r)
            ok += 1
            print(f"[{ok + skip}/{len(wanted)}] up OK {ok} fail {fail} "
                  f"{name.encode('ascii', 'replace').decode()} {len(data)//1024}KB",
                  flush=True)
        except Exception as e:
            fail += 1
            print("upload-failed:", name.encode("ascii", "replace").decode(), e,
                  flush=True)

    out = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                       "release_manifest.json")
    with open(out, "w", encoding="utf-8") as fh:
        json.dump(manifest, fh, ensure_ascii=False, indent=1)
    total_mb = sum(os.path.getsize(p) for p, _ in wanted.values()) // 1024 // 1024
    print(f"DONE ok={ok} fail={fail} skip={skip} total={total_mb}MB "
          f"manifest={out}")
    return 0 if fail == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
