import os
import sys
import django
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from jobs.models import JobRecommendation, Job
from django.contrib.auth import get_user_model

User = get_user_model()
user = User.objects.first()

recs = JobRecommendation.objects.filter(user=user)
print(f"User has {recs.count()} recommendations.")
for rec in recs:
    print(f"Rec Job ID: {rec.job.id}, Title: {rec.job.title}, Location: {rec.job.location}, From: {rec.job.company_name}")
