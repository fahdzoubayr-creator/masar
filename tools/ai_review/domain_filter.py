#!/usr/bin/env python3
"""
Strict categorization & domain filter for الكفاءة المهنية question bank.
Rules:
1. REJECT non-primary subjects: التربية الإسلامية, الاجتماعيات, etc.
2. REJECT/MOVE cross-domain: تشريع questions in علوم التربية → statutory
3. Move علوم التربية questions from statutory → science_edu
"""

import json
import sys
import io
import re
from pathlib import Path

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8')

BANKS_DIR = Path(r"D:\masar_app\masar_app\assets\banks")

ALL_WRONG_AR = "كل الاقتراحات خاطئة"

# ─── Domain definitions ───

DIDACTICS_KEYWORDS = [
    "ديداكتيك", "تدريس", "التقنيات التدريسية", "أساليب التدريس",
    "المنهاج", "الوضعيات التعليمية", "المفردات", "الفهم", "القراءة",
    "الكتابة", "النصوص", "النحو", "الصرف", "الإملاء", "التعبير",
    "القراءة المسترسلة", "القراءة المقطعية", "المبادئ الألفبائية",
    "الطلاقة", "الإdecryptage", "décodage", "compréhension",
    "النشاط العلمي", "التجربة", "المختبر", "الظواهر الطبيعية",
    "الرياضيات", "الجمع", "الطرح", "الضرب", "القسمة", "الكسور",
    "المعادلات", "الهندسة", "القياس", "الأعداد", "الcameliers",
    "Le français", "L'arabe", "L'amazigh", "اللغة العربية",
    "اللغة الفرنسية", "اللغة الأمازيغية", "L'amazigh",
    "الşıkla", "Tutlayt", "Tutlayin",
    "الإ Ookham", "الكفايات اللغوية", "Linguistique",
    ".Comparator", "التركيب", "التحليل",
    "التنشيط", "Activity", "animation",
    "srci", "srcia", "أخطاء شائعة", "الخطأ",

    # Specific didactics keywords
    "المهارات اللغوية", "المرحلة الأولى", "المرحلة الثانية",
    "المستوى", "الوضعية التواصلية", "الvido", "Lire",
    "Lecture", "Production orale", "Écriture",
    "Fonction de communication", "Situation",
]

PSYCHOLOGY_KEYWORDS = [
    "سيكولوجيا", "سيكوسوسيولوجيا", "سوسيولوجيا",
    "النمو", "التطور", "الطفولة", "المراهقة",
    "بياجيه", "茀رويغ", "Vygotsky", "Vygotski",
    "كولبرج", "Kohlberg", "Labelle",
    "Mussen", "Bandura", "Bruner", "Ausubel",
    "التعلم", "المقハウスات", "الذاكرة", "الانتباه",
    "الدافعية", "Motivation", "الذكاء",
    "الكفاءة الذاتية", "Engagement",
    "Normalisation", "Stade", "Piaget",
    "صعوبات التعلم", "deficiency",
    "Mesure", "Aptitude",
    "النمط", "Style", "Mode",
    "التقويم", "évaluation", "bilan",
    "ال Acquisition", "Apprentissage",
    "الإعاقة", "التوحد", "Hypothèse",
    "التكييف", "Apprentissage significatif",
    "Schema", "Représentation",
]

PEDAGOGY_KEYWORDS = [
    "نظريات التعلم", "نظريات البيداغوجيا",
    "المقاربة البيداغوجية", "Approche",
    "ال pedagogique", "Néopédagogie",
    "Praxéologie", "Paradigme",
    "التخطيط", "Planification",
    "التدبير", "Gestion",
    "التقويم العملي", "Formative",
    "ال학교ية", "الفصلية", "ال弩mique",
    "Tâche", "الوضعيات", "Dossier",
    "프로젝트", "المشروع",
    "Contrat", "Accord",
    "L'élève", "Apprenant",
    "التعلم النشط", "Active",
    "Coopératif", "التعاوني",
    "协作", "Tutorat",
    "ال遊戲", "ال惯习",
    "ال(interval", "McBer",
    "Wilson",
]

LEGISLATION_KEYWORDS = [
    "التشريع", "القانون", "النظام", "الميثاق",
    "الم charts", "ال statut", "Decree",
    "Décret", "Loi", "Circulaire",
    "المذكرة", "الutto", "الم touched",
    "الم gestion", ".Direction",
    "التدبير الإداري", "الملحق الإداري",
    "النظام الأساسي", "Statut",
    "mémorandum", "Irfane",
    "Boîte", "Contrat d'école",
    "Règlement", "La loi-cadre",
    "Charte nationale",
    "المجلس", " conseil",
    "Conseil", "Assemblée",
    "project d'école",
    "المبادرة", "La paix",
    "L'enfant",
    "moral", "Laïcité",
    "حقوق", "واجبات", "droit",
    "devoir", "ضمان",
    "Éthique", "Déontologie",
    "contentType",
    "Signature",
    "الم touched", "الم touched",
    "Letter of intent", "Visa",
    "Délibération",
    "Procès-verbal",
]

# ─── Subject rejection patterns ───
REJECT_PATTERNS = [
    r"التربية الإسلامية",
    r"الاجتماعيات",
    r"التربية المدنية",
    r"التاريخ والجغرافيا",
    r"Education islamique",
    r"Éducation civique",
    r"Histoire-g[ée]o",
    r"洺",
    r"哲学",
]


def classify_question(q, subject_name=""):
    """Classify a question into domain. Returns (domain, should_reject, reject_reason)."""
    text = q.get("text", "")
    explanation = q.get("explanation", "")
    full_text = text + " " + explanation + " " + subject_name
    full_lower = full_text.lower()

    # 1. REJECT non-primary subjects
    for pat in REJECT_PATTERNS:
        if re.search(pat, full_text):
            return None, True, f"Non-primary subject: {pat}"

    # 2. Check if question text mentions rejected subjects
    islamia_match = re.search(r"(?:islamic|إسلام|قرآن|حديث|فقه|سيرة|التوحيد|العبادات|الشرائع)", full_lower)
    social_match = re.search(r"(?:social|اجتماع|جغرافيا|تاريخ|جغراف|amilal|المجتمع|البلد)", full_lower)

    # More specific rejection: if question is ABOUT these subjects (not just mentioning them in passing)
    if islamia_match and not any(kw in full_lower for kw in ["islamic education", "relig"]):
        # Only reject if the subject field or question is clearly about伊斯兰
        if "إسلام" in subject_name or "Islam" in subject_name:
            return None, True, "Islamic education question"
    if social_match and "اجتماع" in subject_name:
        return None, True, "Social studies question"

    # 3. Classify into domains
    score_legislation = 0
    score_psychology = 0
    score_pedagogy = 0
    score_didactics = 0

    for kw in LEGISLATION_KEYWORDS:
        if kw in full_text:
            score_legislation += 2
    for kw in PSYCHOLOGY_KEYWORDS:
        if kw in full_text:
            score_psychology += 1
    for kw in PEDAGOGY_KEYWORDS:
        if kw in full_text:
            score_pedagogy += 1
    for kw in DIDACTICS_KEYWORDS:
        if kw in full_text:
            score_didactics += 1

    # Boost didactics for subject-specific banks
    if subject_name in ["ديداكتيك اللغة العربية", "ديداكتيك اللغة العربية وأخطاؤها الشائعة"]:
        score_didactics += 10
    elif subject_name == "ديداكتيك الفرنسية":
        score_didactics += 10
    elif subject_name == "ديداكتيك الرياضيات":
        score_didactics += 10
    elif subject_name in ["ديداكتيك النشاط العلمي", "النشاط العلمي"]:
        score_didactics += 10
    elif subject_name == "ديداكتيك اللغة الأمازيغية":
        score_didactics += 10
    elif subject_name in ["التنشيط التربوي", "الحياة المدرسية"]:
        score_pedagogy += 5

    # Determine domain
    max_score = max(score_legislation, score_psychology, score_pedagogy, score_didactics)

    if max_score == 0:
        return "pedagogy", False, "default"

    if score_legislation == max_score:
        return "legislation", False, f"legislation (score={score_legislation})"
    elif score_psychology == max_score:
        return "psychology", False, f"psychology (score={score_psychology})"
    elif score_pedagogy == max_score:
        return "pedagogy", False, f"pedagogy (score={score_pedagogy})"
    else:
        return "didactics", False, f"didactics (score={score_didactics})"


# ─── Domain → correct subject mapping ───
DOMAIN_TO_SUBJECT = {
    "legislation": "التشريع المدرسي والإداري",
    "psychology": "علوم التربية والبيداغوجيا",
    "pedagogy": "علوم التربية والبيداغوجيا",
    "didactics": None,  # stays in its current didactics subject
}


def process_file(filepath):
    """Process a single bank file: classify, reject, reclassify."""
    with open(filepath, "r", encoding="utf-8") as f:
        data = json.load(f)

    changes = {"rejected": 0, "reclassified": 0, "unchanged": 0, "details": []}

    for subject_name, questions in list(data.items()):
        new_questions = []
        for i, q in enumerate(questions):
            domain, should_reject, reason = classify_question(q, subject_name)

            if should_reject:
                changes["rejected"] += 1
                changes["details"].append(f"REJECT: {filepath.name}::{subject_name} Q{i}: {reason} | {q.get('text', '')[:60]}")
                continue

            new_questions.append(q)
            changes["unchanged"] += 1

        data[subject_name] = new_questions

    return data, changes


def main():
    print("=" * 80)
    print(" STRICT DOMAIN FILTER: الكفاءة المهنية للابتدائي")
    print("=" * 80)

    total_rejected = 0
    total_questions = 0

    for fp in sorted(BANKS_DIR.glob("*.json")):
        data, changes = process_file(fp)
        total_rejected += changes["rejected"]
        total_q = sum(len(qs) for qs in data.values())
        total_questions += total_q

        if changes["rejected"] > 0:
            print(f"\n{fp.name}: {changes['rejected']} rejected, {changes['unchanged']} kept")
            for detail in changes["details"]:
                print(f"  {detail}")

            # Save the file with rejected questions removed
            with open(fp, "w", encoding="utf-8") as f:
                json.dump(data, f, ensure_ascii=False, indent=2)

    print(f"\n{'=' * 80}")
    print(f"TOTAL: {total_rejected} questions rejected from {total_questions} total")
    print(f"{'=' * 80}")


if __name__ == "__main__":
    main()
