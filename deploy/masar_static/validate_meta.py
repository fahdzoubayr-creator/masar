import json
import urllib.parse
import urllib.request

BASE = 'http://127.0.0.1:8123/api/review-files/meta?path='


def pdfs(o, acc):
    if isinstance(o, dict):
        if 'pdf' in o and isinstance(o['pdf'], str):
            acc.append(o['pdf'])
        for v in o.values():
            pdfs(v, acc)
    elif isinstance(o, list):
        for v in o:
            pdfs(v, acc)


mf = json.load(open(r'E:\masar_static\remote_manifest.json', encoding='utf-8'))
items = []
pdfs(mf, items)
seen = []
for p in items:
    if p not in seen:
        seen.append(p)

ok = 0
bad = []
pages_total = 0
for p in seen:
    url = BASE + urllib.parse.quote(p)
    try:
        r = urllib.request.urlopen(url, timeout=120)
        j = json.loads(r.read().decode('utf-8'))
        if j.get('mode') == 'png' and isinstance(j.get('pages'), int) and j['pages'] > 0:
            ok += 1
            pages_total += j['pages']
        else:
            bad.append((p, j.get('mode')))
    except Exception as e:
        bad.append((p, repr(e)))

print('unique pdfs: %d' % len(seen))
print('ok: %d  bad: %d  total_pages: %d' % (ok, len(bad), pages_total))
for p, why in bad:
    print('BAD:', why, p)
