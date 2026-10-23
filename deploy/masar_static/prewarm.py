import io
import json
import time
import urllib.parse
import urllib.request

BASE = 'http://127.0.0.1:8123/api/review-files/file?path='

SLUGS = {
    'التشريع المدرسي': 'tachrii_madrasii',
    'التنشيط التربوي': 'tanshit_tarbawi',
    'خطاطات ذهنية': 'khatatat_dhihniya',
    'دورات تكوينية': 'dawrat_takwiniya',
    'ديداكتيك الرياضيات': 'didactique_maths',
    'ديداكتيك اللغة الأمازيغية': 'didactique_amazigh',
    'ديداكتيك اللغة العربية': 'didactique_arabe',
    'ديداكتيك اللغة الفرنسية': 'didactique_francais',
    'ديداكتيك النشاط العلمي': 'didactique_science',
    'علوم التربية': 'ouloum_tarbiya',
    'مؤسسات الريادة': 'mouassasat_riyada',
    'مراسلات ومذكرات': 'murasilat_mudhakkirat',
    'مشروع المؤسسة المندمج': 'mashroua_muassasa',
    'التعليم الثانوي بسلكيه': 'taalim_thaanawi',
    'بنك الاسئلة': 'bank_asila',
}


def pdfs(o, acc):
    if isinstance(o, dict):
        if 'pdf' in o and isinstance(o['pdf'], str):
            acc.append(o['pdf'])
        for v in o.values():
            pdfs(v, acc)
    elif isinstance(o, list):
        for v in o:
            pdfs(v, acc)


rel = json.load(open(r'E:\masar_static\releases.json', encoding='utf-8'))
v1 = [x for x in rel if x['tag_name'] == 'review-files-v1'][0]
sizes = {a['name']: a['size'] for a in v1['assets']}

mf = json.load(open(r'E:\masar_static\remote_manifest.json', encoding='utf-8'))
items = []
pdfs(mf, items)
seen = set()
order = []
for p in items:
    if p in seen:
        continue
    seen.add(p)
    parts = p.split('/')
    slug = SLUGS.get(parts[2]) if len(parts) >= 4 else None
    name = (slug + '__' + parts[3]) if slug else None
    sz = sizes.get(name, 10 ** 12)
    order.append((sz, p, name))

order.sort(key=lambda t: t[0])

log = io.open(r'E:\masar_static\prewarm_log.txt', 'w', encoding='utf-8')
log.write('total: %d\n' % len(order))
log.flush()

ok = 0
fail = 0
t_all = time.time()
for i, (sz, p, name) in enumerate(order, 1):
    url = BASE + urllib.parse.quote(p)
    t0 = time.time()
    try:
        r = urllib.request.urlopen(url, timeout=600)
        data = r.read()
        dt = time.time() - t0
        ok += 1
        log.write('%d/%d OK %s %.1fMB %.1fs %s\n' % (i, len(order), r.status, len(data) / 1e6, dt, p))
    except Exception as e:
        fail += 1
        dt = time.time() - t0
        log.write('%d/%d ERR %.1fs %r %s\n' % (i, len(order), dt, e, p))
    log.flush()

log.write('DONE ok=%d fail=%d total=%.0fs\n' % (ok, fail, time.time() - t_all))
log.close()
print('done')
