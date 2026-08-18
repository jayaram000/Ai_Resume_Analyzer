import os
import sys
import django
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from resumes.models import Resume
from jobs.models import JobRecommendation
from django.contrib.auth import get_user_model

User = get_user_model()
user = User.objects.first()

resumes = Resume.objects.filter(user=user)
deleted_count = 0
for resume in resumes:
    if hasattr(resume, "parsed_content") and resume.parsed_content:
        if resume.parsed_content.extracted_skills == ['Parsed Skill']:
            resume.delete()
            deleted_count += 1

print(f"Deleted {deleted_count} broken resumes.")

# Clear bad recommendations
JobRecommendation.objects.filter(user=user).delete()
print("Cleared old broken job recommendations.")
