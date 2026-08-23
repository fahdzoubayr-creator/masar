#!/usr/bin/env python3
"""
run_pipeline.py — Master orchestrator for the AI Review Pipeline.

Runs: Export → Validate → Import in sequence.

Usage:
    # Full pipeline:
    python run_pipeline.py

    # With specific banks:
    python run_pipeline.py --banks "الكفاءة المهنية,ديداكتيك الرياضيات"

    # Dry run (no API calls):
    python run_pipeline.py --dry-run

    # Resume interrupted validation:
    python run_pipeline.py --resume

    # Export only:
    python run_pipeline.py --export-only

Environment:
    OPENAI_API_KEY   — Required for validation (not needed for export/import)
    OPENAI_MODEL     — Optional. Default: gpt-4o
    OPENAI_BASE_URL  — Optional. For local/proxy endpoints.
"""

import subprocess
import sys
import os
import io
from pathlib import Path

# Force UTF-8 on Windows
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8", errors="replace")

TOOLS_DIR = Path(__file__).parent


def run_step(name: str, script: str, args: list = None):
    """Run a pipeline step."""
    print(f"\n{'='*60}")
    print(f"STEP: {name}")
    print(f"{'='*60}")

    cmd = [sys.executable, str(TOOLS_DIR / script)] + (args or [])
    result = subprocess.run(cmd, cwd=str(TOOLS_DIR))

    if result.returncode != 0:
        print(f"\nERROR: {name} failed with exit code {result.returncode}")
        return False
    return True


def main():
    import argparse

    parser = argparse.ArgumentParser(description="Run AI Review Pipeline")
    parser.add_argument("--banks", type=str, default=None,
                        help="Comma-separated bank keys to process")
    parser.add_argument("--batch-size", type=int, default=10)
    parser.add_argument("--resume", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--export-only", action="store_true")
    parser.add_argument("--validate-only", action="store_true")
    parser.add_argument("--import-only", action="store_true")
    args = parser.parse_args()

    bank_args = ["--banks", args.banks] if args.banks else []

    # Step 1: Export
    if not args.validate_only and not args.import_only:
        if not run_step("Export Questions (Dart -> JSON)", "export_questions.py"):
            sys.exit(1)

    if args.export_only:
        print("\nExport complete. Run without --export-only to continue.")
        return

    # Step 2: Validate
    if not args.export_only and not args.import_only:
        validate_args = ["--batch-size", str(args.batch_size)] + bank_args
        if args.resume:
            validate_args.append("--resume")
        if args.dry_run:
            validate_args.append("--dry-run")
        if not run_step("AI Validation", "validate_questions.py", validate_args):
            sys.exit(1)

    if args.validate_only:
        print("\nValidation complete. Run without --validate-only to continue.")
        return

    # Step 3: Import
    if not args.export_only and not args.validate_only:
        import_args = bank_args
        if args.dry_run:
            import_args.append("--dry-run")
        if not run_step("Import Corrections (JSON -> Dart)", "import_questions.py", import_args):
            sys.exit(1)

    print(f"\n{'='*60}")
    print("Pipeline Complete!")
    print(f"{'='*60}")
    print("\nOutput files:")
    print(f"  {TOOLS_DIR / 'raw_questions.json'}")
    print(f"  {TOOLS_DIR / 'validated_questions.json'}")
    print(f"  {TOOLS_DIR / 'validation_progress.json'}")
    print(f"\nNext: Review corrected Dart files and apply to bank sources.")


if __name__ == "__main__":
    main()
