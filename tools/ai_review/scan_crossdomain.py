import json, sys, io, re
from pathlib import Path
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
BANKS_DIR = Path(r'D:\masar_app\masar_app\assets\banks')
LEGIS_PAT = re.compile(r'(?:مشروع المؤسسة|المجلس|القانون الإطار|الميثاق|المذكرة|الرؤية الاستراتيجية|حقوق وواجبات|النظام الأساسي|التشريع|décret|loi-cadre|charte|conseil.*école|projet.*école|دفتر التحملات)', re.I)
PEDAGOGY_PAT = re.compile(r'(?:نظريات التعلم|المقاربة|Approche|pedagog|Professeur|.schema|Brown|Wiggins|McTighe|Marzano|Bloom|Anderson|Krathwohl|Genèse|stimulus|réponse|Tal quest|Question|التعلّم|Student|Apprenant|Cognitif|Metacognition|تصور المتعلم|ال생각|البنية|الچдель|سقف|م猜|تعلم نشط|المشروع التعلمي|شرح|Mentor|Elaboration|الإرشاد|التأطير|Osiris|เล่น|Diaporama|Parcours|التصحيح|screening)', re.I)

for fp in sorted(BANKS_DIR.glob('*.json')):
    data = json.load(open(fp, 'r', encoding='utf-8'))
    issues = []
    for s, qs in data.items():
        for i, q in enumerate(qs):
            text = q.get('text', '')
            exp = q.get('explanation', '')
            full = text + ' ' + exp
            
            # Cross-domain: legislation question in a non-legislation subject
            if s != 'التشريع المدرسي والإداري' and s != 'المجالس التعليمية' and s != 'مشروع المؤسسة المندمج' and s != 'الإصلاح التربوي والسياسة التعليمية':
                if LEGIS_PAT.search(full) and not PEDAGOGY_PAT.search(full):
                    # Check more carefully - only flag if it's clearly about legislation
                    if re.search(r'(?:المجلس|المؤسسة|القانون|النظام|التشريع|الميثاق|الرؤية الاستراتيجية|حقوق وواجبات)', text):
                        issues.append((s, i, 'LEGIS_IN_WRONG', text[:80]))
    
    if issues:
        print(f'\n{fp.name}: {len(issues)} cross-domain issues')
        for subj, idx, typ, txt in issues[:10]:
            print(f'  {typ}: {subj} Q{idx}: {txt}')
