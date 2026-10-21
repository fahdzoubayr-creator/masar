"""ضغط صور الخطاطات الذهنية قبل نشرها في التطبيق.

- تصغير最长 ضلع إلى 1400 بكسل (يكفي لقراءة الخطاطة على الهاتف).
- إعادة الترميز JPEG بجودة 82 (أو PNG إن كانت الصورة شفافة ضروريّة).
- الحفاظ على نفس الأسماء حتى يبقى الفهرس صالحاً.
"""
import os
import sys
from PIL import Image

DST = r"E:\DRestore\masar_app\masar_app\assets\mindmaps"
MAX_SIDE = 1400
QUALITY = 82

total_before = 0
total_after = 0
count = 0

for name in sorted(os.listdir(DST)):
    path = os.path.join(DST, name)
    if not os.path.isfile(path):
        continue
    ext = os.path.splitext(name)[1].lower()
    if ext not in (".jpg", ".jpeg", ".png", ".jfif", ".webp"):
        continue

    before = os.path.getsize(path)
    total_before += before

    try:
        with Image.open(path) as im:
            im = im.convert("RGB")
            w, h = im.size
            scale = min(1.0, MAX_SIDE / max(w, h))
            if scale < 1.0:
                im = im.resize((max(1, int(w * scale)), max(1, int(h * scale))), Image.LANCZOS)
            out = os.path.splitext(path)[0] + ".jpg"
            im.save(out, "JPEG", quality=QUALITY, optimize=True, progressive=True)
            if out != path:
                os.remove(path)
            after = os.path.getsize(out)
            total_after += after
            count += 1
            print("%s  %dx%d -> %dx%d   %.0fKB -> %.0fKB" % (
                name, w, h, im.size[0], im.size[1], before / 1024, after / 1024))
    except Exception as exc:  # noqa: BLE001
        print("SKIP %s (%s)" % (name, exc), file=sys.stderr)

print("----")
print("files=%d  before=%.1fMB  after=%.1fMB" % (
    count, total_before / 1048576, total_after / 1048576))
