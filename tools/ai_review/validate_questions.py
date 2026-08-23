#!/usr/bin/env python3
"""
validate_questions.py — AI Review & Validation Pipeline for Masar Question Bank.

Sends batches of questions to Google Gemini for pedagogical audit, correction,
and format normalization. Outputs validated JSON ready for import.

Usage:
    set GEMINI_API_KEY=AIzaSy...
    python validate_questions.py --batch-size 5 --banks "教育科学"

    # Or with OpenAI:
    set OPENAI_API_KEY=sk-...
    python validate_questions.py --batch-size 5

Requirements:
    pip install openai

Environment:
    GEMINI_API_KEY  — Google Gemini API key (free tier).
    OPENAI_API_KEY  — OpenAI API key (alternative).
    AI_MODEL        — Override model name.
"""

import json
import os
import sys
import io
import time
import argparse
import hashlib
import re
from pathlib import Path

# Force UTF-8 on Windows
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8", errors="replace")

INPUT = Path(r"D:\masar_app\masar_app\tools\ai_review\filtered_questions.json")
OUTPUT = Path(r"D:\masar_app\masar_app\tools\ai_review\validated_questions.json")
PROGRESS = Path(r"D:\masar_app\masar_app\tools\ai_review\validation_progress.json")

BATCH_SIZE = 10

SYSTEM_PROMPT = """مهمتك: فحص وتصحيح أسئلة اختبار "الكفاءة المهنية" المغربي. أعد مصفوفة JSON مُصحّحة.

لكل سؤال: صحّح الأخطاء الإملائية/الحروف المفقودة، أزل metadata غير تربوي، اجعل 4 خيارات (أ ب ج د)، صحّح correctIndex (0-3)، أضف شرحاً مختصراً إن كان فارغاً. إذا كان 5 خيارات، احذف الأضعف. إذا الخيار الأخير "جميع ما سبق خاطئ"، حوّله للخيار د.

JSON لكل سؤال: {"id","subject","level","text","options":[4],"correctIndex":0-3,"explanation","source","situation","_changes":null,"_verdict":"PASS|FIXED|REJECTED","_rejection_reason":null}

أعد فقط JSON array صالح. لا markdown. كل سؤال مدخل يظهر في المخرجات."""


def load_progress() -> dict:
    if PROGRESS.exists():
        with open(PROGRESS, "r", encoding="utf-8") as f:
            return json.load(f)
    return {"processed_banks": {}, "processed_questions": {}}


def save_progress(progress: dict):
    with open(PROGRESS, "w", encoding="utf-8") as f:
        json.dump(progress, f, ensure_ascii=False, indent=2)


def question_hash(q: dict) -> str:
    h = hashlib.md5()
    h.update(q.get("text", "").encode())
    h.update(str(q.get("correctIndex", 0)).encode())
    return h.hexdigest()[:12]


def call_llm(batch: list, model: str, api_key: str, base_url: str = None, provider: str = "groq") -> list:
    """Send a batch of questions to the LLM for validation."""
    import requests as _requests

    user_msg = json.dumps(batch, ensure_ascii=False, indent=2)
    full_prompt = SYSTEM_PROMPT + "\n\n## INPUT\n\n" + user_msg

    if provider == "gemini":
        url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={api_key}"
        body = {
            "contents": [{"parts": [{"text": full_prompt}]}],
            "generationConfig": {
                "temperature": 0.1,
                "maxOutputTokens": 16000,
            },
        }
    else:
        # Groq or any OpenAI-compatible endpoint
        url = base_url.rstrip("/") + "/chat/completions" if base_url else "https://api.groq.com/openai/v1/chat/completions"
        body = {
            "model": model,
            "messages": [
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user", "content": user_msg},
            ],
            "temperature": 0.1,
            "max_tokens": 4000,
        }

    max_retries = 3
    for attempt in range(max_retries):
        try:
            headers = {}
            if provider != "gemini":
                headers["Authorization"] = f"Bearer {api_key}"

            resp = _requests.post(url, json=body, headers=headers, timeout=120)
            data = resp.json()

            if resp.status_code == 429 or (resp.status_code == 403 and "rate" in str(data).lower()):
                wait = 30 * (attempt + 1)
                print(f"\n    Rate limited. Waiting {wait}s...", end="", flush=True)
                time.sleep(wait)
                continue

            # Extract content based on provider
            if provider == "gemini":
                if "candidates" not in data:
                    err = data.get("error", {})
                    print(f"\n    API error: {err.get('message', str(data))[:100]}", end="", flush=True)
                    if attempt < max_retries - 1:
                        time.sleep(5)
                        continue
                    for q in batch:
                        q["_verdict"] = "REJECTED"
                        q["_rejection_reason"] = "API error"
                    return batch
                content = data["candidates"][0]["content"]["parts"][0]["text"].strip()
            else:
                # OpenAI-compatible (Groq)
                if "choices" not in data or not data["choices"]:
                    err = data.get("error", {})
                    print(f"\n    API error: {err.get('message', str(data))[:100]}", end="", flush=True)
                    if attempt < max_retries - 1:
                        time.sleep(5)
                        continue
                    for q in batch:
                        q["_verdict"] = "REJECTED"
                        q["_rejection_reason"] = "API error"
                    return batch
                content = data["choices"][0]["message"]["content"].strip()

            # Strip thinking tags (Qwen, etc.) - greedy removal
            content = re.sub(r'<think>[\s\S]*?</think>', '', content)
            content = re.sub(r'<reasoning>[\s\S]*?</reasoning>', '', content)
            content = re.sub(r'<scratchpad>[\s\S]*?</scratchpad>', '', content)

            # Strip markdown code blocks
            content = re.sub(r'^```\w*\n?', '', content)
            content = re.sub(r'\n?```$', '', content)
            content = content.strip()

            # Try to find JSON array in the response
            arr_match = re.search(r'\[[\s\S]*\]', content, re.DOTALL)
            if arr_match:
                content = arr_match.group(0)

            # Try to repair common JSON issues
            from json_repair import repair_json
            repaired = repair_json(content, return_objects=False)

            try:
                result = json.loads(repaired)
            except json.JSONDecodeError:
                result = json.loads(content)  # fallback to original

            # Unwrap dict wrapper if present
            if isinstance(result, dict):
                for key in ["questions", "data", "results", "output"]:
                    if key in result and isinstance(result[key], list):
                        result = result[key]
                        break

            if isinstance(result, list) and len(result) == len(batch):
                return result
            else:
                got = len(result) if isinstance(result, list) else "non-list"
                print(f"\n    WARNING: Expected {len(batch)} questions, got {got}")
                if attempt < max_retries - 1:
                    print(f"    Retrying (attempt {attempt + 2})...")
                    time.sleep(3)
                    continue
                for q in batch:
                    q["_verdict"] = "REJECTED"
                    q["_rejection_reason"] = "LLM returned invalid response count"
                return batch

        except json.JSONDecodeError as e:
            print(f"\n    JSON parse error: {e}")
            if attempt < max_retries - 1:
                print(f"    Retrying (attempt {attempt + 2})...")
                time.sleep(3)
            else:
                for q in batch:
                    q["_verdict"] = "REJECTED"
                    q["_rejection_reason"] = f"JSON parse error"
                return batch

        except _requests.exceptions.Timeout:
            print(f"\n    Timeout", end="", flush=True)
            if attempt < max_retries - 1:
                time.sleep(5)
            else:
                for q in batch:
                    q["_verdict"] = "REJECTED"
                    q["_rejection_reason"] = "Timeout"
                return batch

        except Exception as e:
            error_str = str(e)
            if "429" in error_str or "rate" in error_str.lower() or "quota" in error_str.lower():
                wait = 15 * (attempt + 1)
                print(f"\n    Rate limited. Waiting {wait}s...", end="", flush=True)
                time.sleep(wait)
                continue
            print(f"\n    API error: {e}", end="", flush=True)
            if attempt < max_retries - 1:
                time.sleep(5)
            else:
                for q in batch:
                    q["_verdict"] = "REJECTED"
                    q["_rejection_reason"] = "API error"
                return batch

    return batch


def main():
    parser = argparse.ArgumentParser(description="AI validation of question bank")
    parser.add_argument("--input", type=Path, default=INPUT)
    parser.add_argument("--output", type=Path, default=OUTPUT)
    parser.add_argument("--batch-size", type=int, default=BATCH_SIZE)
    parser.add_argument("--banks", type=str, default=None,
                        help="Comma-separated bank keys to validate")
    parser.add_argument("--limit", type=int, default=None,
                        help="Max questions per bank (for testing)")
    parser.add_argument("--resume", action="store_true",
                        help="Resume from last progress checkpoint")
    parser.add_argument("--dry-run", action="store_true",
                        help="Show batches without calling API")
    args = parser.parse_args()

    # Resolve API key and model
    api_key = os.environ.get("GROQ_API_KEY") or os.environ.get("GEMINI_API_KEY") or os.environ.get("OPENAI_API_KEY")
    model = os.environ.get("AI_MODEL", "openai/gpt-oss-120b")
    base_url = os.environ.get("AI_BASE_URL")
    provider = os.environ.get("AI_PROVIDER", "groq")

    if not api_key and not args.dry_run:
        print("ERROR: No API key found.")
        print("  For Groq: set GROQ_API_KEY=gsk_...")
        print("  For Gemini: set GEMINI_API_KEY=AIzaSy...")
        print("  Or use --dry-run to test without API calls.")
        sys.exit(1)

    # Auto-configure
    if os.environ.get("GROQ_API_KEY"):
        provider = "groq"
        model = os.environ.get("AI_MODEL", "openai/gpt-oss-20b")
        print(f"Using Groq: {model}")
    elif os.environ.get("GEMINI_API_KEY"):
        provider = "gemini"
        model = os.environ.get("AI_MODEL", "gemini-3-flash-preview")
        print(f"Using Google Gemini: {model}")
    else:
        provider = "openai"
        model = os.environ.get("AI_MODEL", "gpt-4o")
        print(f"Using OpenAI: {model}")
    print(f"  Model: {model}")

    # Load input
    if not args.input.exists():
        print(f"ERROR: Input file not found: {args.input}")
        print("  Run audit_and_filter.py first to generate filtered_questions.json")
        sys.exit(1)

    with open(args.input, "r", encoding="utf-8") as f:
        data = json.load(f)

    banks = data if isinstance(data, dict) and "questions" not in data else {"all": data}

    # Check if it's the audit format (bank_key -> {source_file, questions})
    if all(isinstance(v, dict) and "questions" in v for v in banks.values()):
        total_q = sum(len(v["questions"]) for v in banks.values())
    else:
        print("ERROR: Unexpected input format")
        sys.exit(1)

    print(f"Loaded {total_q} questions from {len(banks)} banks")

    # Filter banks if specified
    if args.banks:
        bank_filter = [k.strip() for k in args.banks.split(",")]
        banks = {k: v for k, v in banks.items() if k in bank_filter}
        print(f"Filtered to {len(banks)} banks: {list(banks.keys())}")

    # Load progress
    progress = load_progress() if args.resume else {"processed_banks": {}, "processed_questions": {}}

    # Load existing output if resuming
    validated = {}
    if args.resume and args.output.exists():
        with open(args.output, "r", encoding="utf-8") as f:
            existing = json.load(f)
            if isinstance(existing, dict):
                validated = existing.get("banks", existing)

    total_validated = 0
    total_rejected = 0
    total_fixed = 0
    total_questions = 0

    for bank_key, bank_data in banks.items():
        questions = bank_data["questions"]
        if args.limit:
            questions = questions[:args.limit]

        print(f"\n{'='*60}")
        print(f"Bank: {bank_key} ({len(questions)} questions)")
        print(f"  Source: {bank_data.get('source_file', 'unknown')}")

        # Skip if already processed
        if bank_key in progress.get("processed_banks", {}) and bank_key in validated:
            print(f"  SKIP (already processed)")
            total_q_bank = len(validated[bank_key].get("questions", []))
            for q in validated[bank_key].get("questions", []):
                v = q.get("_verdict", "UNKNOWN")
                if v == "REJECTED": total_rejected += 1
                elif v == "FIXED": total_fixed += 1
                else: total_validated += 1
            total_questions += total_q_bank
            continue

        # Split into batches
        batches = []
        for i in range(0, len(questions), args.batch_size):
            batches.append(questions[i : i + args.batch_size])

        bank_validated = []
        for batch_idx, batch in enumerate(batches):
            batch_num = batch_idx + 1
            total_batches = len(batches)
            q_start = batch_idx * args.batch_size + 1
            q_end = q_start + len(batch) - 1
            print(f"  Batch {batch_num}/{total_batches} (Q{q_start}-Q{q_end})...", end=" ", flush=True)

            if args.dry_run:
                print("DRY RUN")
                for q in batch:
                    q["_verdict"] = "DRY_RUN"
                bank_validated.extend(batch)
                continue

            result = call_llm(batch, model, api_key, base_url, provider=provider)
            bank_validated.extend(result)

            # Count verdicts
            for q in result:
                v = q.get("_verdict", "UNKNOWN")
                if v == "REJECTED":
                    total_rejected += 1
                elif v == "FIXED":
                    total_fixed += 1
                else:
                    total_validated += 1
                total_questions += 1

            print(f"OK")

            # Save progress
            progress["processed_questions"] = progress.get("processed_questions", {})
            for q in result:
                progress["processed_questions"][q.get("id", "")] = q.get("_verdict", "UNKNOWN")
            save_progress(progress)

            # Rate limit protection
            if not args.dry_run:
                if provider == "groq":
                    time.sleep(10)  # Groq free: avoid rate limits
                elif provider == "gemini":
                    time.sleep(30)  # Gemini free: very strict
                else:
                    time.sleep(1)

        # Save bank results
        validated[bank_key] = {
            "source_file": bank_data.get("source_file", "unknown"),
            "questions": bank_validated,
        }
        progress["processed_banks"][bank_key] = len(bank_validated)
        save_progress(progress)

        # Save output after each bank
        output_data = {"banks": validated}
        with open(args.output, "w", encoding="utf-8") as f:
            json.dump(output_data, f, ensure_ascii=False, indent=2)

    # Final summary
    print(f"\n{'='*60}")
    print(f"  Validation Complete!")
    print(f"{'='*60}")
    print(f"  Total:   {total_questions}")
    print(f"  Passed:  {total_validated}")
    print(f"  Fixed:   {total_fixed}")
    print(f"  Rejected: {total_rejected}")
    print(f"  Output:  {args.output}")

    if total_rejected > 0:
        print(f"\n  Rejected questions:")
        for bk, bd in validated.items():
            for q in bd.get("questions", []):
                if q.get("_verdict") == "REJECTED":
                    print(f"    [{bk}] {q.get('id')}: {q.get('_rejection_reason', '?')}")


if __name__ == "__main__":
    main()
