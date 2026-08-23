#!/usr/bin/env python3
import requests, json, sys, io

key = "***REMOVED***"
url = "https://api.groq.com/openai/v1/chat/completions"
headers = {"Authorization": f"Bearer {key}", "Content-Type": "application/json"}

SYSTEM_PROMPT = """مهمتك: فحص وتصحيح أسئلة اختبار "الكفاءة المهنية" المغربي. أعد مصفوفة JSON مُصحّحة.

لكل سؤال: صحّح الأخطاء الإملائية/الحروف المفقودة، أزل metadata غير تربوي، اجعل 4 خيارات (أ ب ج د)، صحّح correctIndex (0-3)، أضف شرحاً مختصراً إن كان فارغاً. إذا كان 5 خيارات، احذف الأضعف. إذا الخيار الأخير "جميع ما سبق خاطئ"، حوّله للخيار د.

JSON لكل سؤال: {"id","subject","level","text","options":[4],"correctIndex":0-3,"explanation","source","situation","_changes":null,"_verdict":"PASS|FIXED|REJECTED","_rejection_reason":null}

أعد فقط JSON array صالح. لا markdown. كل سؤال مدخل يظهر في المخرجات."""

with open(r"D:\masar_app\masar_app\tools\ai_review\filtered_questions.json", "r", encoding="utf-8") as f:
    data = json.load(f)

q = data["academies_eval_bank_data"]["questions"][0]
user_msg = json.dumps([q], ensure_ascii=False, indent=2)

print(f"System prompt: {len(SYSTEM_PROMPT)} chars")
print(f"User msg: {len(user_msg)} chars")

body = {
    "model": "openai/gpt-oss-120b",
    "messages": [
        {"role": "system", "content": SYSTEM_PROMPT},
        {"role": "user", "content": user_msg},
    ],
    "temperature": 0.1,
    "max_tokens": 4000,
}

body_str = json.dumps(body)
print(f"Body JSON: {len(body_str)} bytes")

r = requests.post(url, json=body, headers=headers, timeout=30)
print(f"Status: {r.status_code}")
data_r = r.json()
if "choices" in data_r:
    content = data_r["choices"][0]["message"]["content"]
    print(f"OK! Response length: {len(content)} chars")
    print(f"First 200: {content[:200]}")
else:
    print(f"Error: {json.dumps(data_r, ensure_ascii=False)[:300]}")
