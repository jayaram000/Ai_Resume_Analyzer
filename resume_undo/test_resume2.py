import os
import sys
import django
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from resumes.models import Resume
from django.contrib.auth import get_user_model

User = get_user_model()
user = User.objects.first()

if user:
    resumes = Resume.objects.filter(user=user).order_by("-created_at")
    print(f"User has {resumes.count()} resumes")
    for resume in resumes:
        print(f"Title: {resume.title}, Created: {resume.created_at}")
        if hasattr(resume, "parsed_content") and resume.parsed_content:
            print("  Skills:", resume.parsed_content.extracted_skills)
        else:
            print("  No parsed content!")
