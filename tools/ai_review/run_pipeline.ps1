$env:GROQ_API_KEY="***REMOVED***"
$env:PYTHONIOENCODING="utf-8"
cd D:\masar_app\masar_app
python tools\ai_review\validate_questions.py --batch-size 10 --resume *> D:\masar_app\masar_app\tools\ai_review\pipeline_log.txt
