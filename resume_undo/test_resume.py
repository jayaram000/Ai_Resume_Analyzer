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
    resume = Resume.objects.filter(user=user).order_by("-created_at").first()
    if resume:
        print("Resume title:", resume.title)
        if hasattr(resume, "parsed_content") and resume.parsed_content:
            print("Parsed experience:", resume.parsed_content.extracted_experience)
            print("Parsed skills:", resume.parsed_content.extracted_skills)
        else:
            print("No parsed content!")
    else:
        print("No resume found!")
