import os
import sys
import django
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from jobs.services import JobAggregationService
from django.conf import settings

print(f"JSEARCH_API_KEY inside settings: {getattr(settings, 'JSEARCH_API_KEY', None)}")

jobs = JobAggregationService.fetch_jobs("Software Developer", "New York")
print(f"Fetched {len(jobs)} jobs. First job title: {jobs[0].title if jobs else 'None'}")
