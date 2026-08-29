"""رفع الصفحات المصوّرة (assets/review_pages_cache) إلى استضافة سحابية CORS.

افتراضياً يطبع الأوامر فقط (--dry-run). نزّل البنية للتحقق ثم نفّذ:

  python tools/upload_pages.py --provider gs --bucket masar-review --prefix review_pages
  python tools/upload_pages.py --provider s3 --bucket masar-review --prefix review_pages --run

البنية المرفوعة لكل ملف (slug__NN):
  <prefix>/<slug>__NN/meta.json
  <prefix>/<slug>__NN/p01.png … pNN.png

ثم مرِّر القاعدة العامة عند بناء التطبيق:
  --dart-define=REVIEW_PAGE_BASE=<https base>/
مثال Firebase: https://firebasestorage.googleapis.com/v0/b/<bucket>/o/
مع قاعدة فتحهم للقراءة العامة. (S3 يحتاج سياسة CORS + public-read أو CDN.)
"""
import argparse
import os
import subprocess


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--provider", choices=["gs", "s3"], required=True,
                    help="gs = Google Cloud Storage / Firebase Storage tools")
    ap.add_argument("--bucket", required=True)
    ap.add_argument("--prefix", default="review_pages")
    ap.add_argument("--cache-dir", default="assets/review_pages_cache")
    ap.add_argument("--run", action="store_true",
                    help="نفّذ الأوامر فعلياً بدل طباعتها فقط")
    args = ap.parse_args()

    if not os.path.isdir(args.cache_dir):
        raise SystemExit(f"المجلد غير موجود: {args.cache_dir}")

    dest_root = f"gs://{args.bucket}/{args.prefix}"
    if args.provider == "gs":
        cmd = ["gsutil", "-m", "cp", "-r", f"{args.cache_dir}/*", dest_root]
    else:  # s3
        cmd = ["aws", "s3", "sync", args.cache_dir, f"s3://{args.bucket}/{args.prefix}",
               "--exclude", "*", "--include", "*/p*.png", "--include", "*/meta.json"]

    if args.run:
        print("+", " ".join(cmd))
        subprocess.run(cmd, check=True)
    else:
        print("أمر الرفع (بدون تنفيذ — أضف --run):")
        print("  ", " ".join(cmd))

    print("\nبعد الرفع: قاعدة عامة للبناء:")
    if args.provider == "gs":
        print(f"  --dart-define=REVIEW_PAGE_BASE="
              f"https://firebasestorage.googleapis.com/v0/b/{args.bucket}/o/")
        print("  مع قواعد Firebase Storage تسمح بالقراءة العامة")
        print("  (match /{prefix}/** { allow read: if request.auth != null } "
              "أو public حسب حاجتك).")
    else:
        print(f"  --dart-define=REVIEW_PAGE_BASE="
              f"https://{args.bucket}.s3.<region>.amazonaws.com/{args.prefix}/")
        print("  مع سياسة CORS على الدلو + قراءة عامة أو CDN (CloudFront).")


if __name__ == "__main__":
    main()