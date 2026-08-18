import os
import sys
import django
from django.test import RequestFactory
import json

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from django.contrib.auth import get_user_model
from jobs.views import JobSearchView

User = get_user_model()
user = User.objects.first()

factory = RequestFactory()
request = factory.post('/api/jobs/search/', data=json.dumps({
    "query": "flutter",
    "location": "kochi"
}), content_type='application/json')
request.user = user

from rest_framework.test import force_authenticate
force_authenticate(request, user=user)

view = JobSearchView.as_view()
response = view(request)
print("Status Code:", response.status_code)
data = response.data
for item in data.get("data", [])[:3]:
    print(item["job"]["title"], "-", item["job"]["location"])
