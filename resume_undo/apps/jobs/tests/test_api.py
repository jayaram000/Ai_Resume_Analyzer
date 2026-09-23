from django.contrib.auth import get_user_model
from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase
from jobs.models import Job, SelectedJob, JobRecommendation
from resumes.models import Resume
from parsing.tasks import extract_resume_text_task
from django.core.files.uploadedfile import SimpleUploadedFile
from subscriptions.models import SubscriptionPlan, UserSubscription
from django.utils import timezone

User = get_user_model()

VALID_PDF = (
    b"%PDF-1.4\n1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj\n"
    b"2 0 obj<</Type/Pages/Count 1/Kids[3 0 R]>>endobj\n"
    b"3 0 obj<</Type/Page/MediaBox[0 0 612 792]/Parent 2 0 R/Resources<<>>>>endobj\n"
    b"xref\n0 4\n0000000000 65535 f\n0000000009 00000 n\n0000000052 00000 n\n00000000101 00000 n\n"
    b"trailer<</Size 4/Root 1 0 R>>\nstartxref\n178\n%%EOF\n"
)


class JobsAPITests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            email="jobseeker@career.ai",
            username="seeker",
            password="password123"
        )
        self.client.force_authenticate(user=self.user)
        
        # Grant Premium access to user
        self.plan = SubscriptionPlan.objects.create(
            name="Premium Plan",
            price=499,
            duration_days=30,
            features=["All Tools"]
        )
        UserSubscription.objects.create(
            user=self.user,
            plan=self.plan,
            start_date=timezone.now(),
            end_date=timezone.now() + timezone.timedelta(days=30),
            status="active"
        )
        
        # Upload resume to compute recommendations
        self.resume = Resume.objects.create(
            user=self.user,
            title="Dev Resume",
            file=SimpleUploadedFile("dev.pdf", VALID_PDF, content_type="application/pdf")
        )

        # Create base job
        self.job = Job.objects.create(
            jsearch_id="test_job_uuid",
            title="Django Developer",
            company_name="Innovate Ltd",
            location="Berlin, DE",
            apply_link="https://innovate.link",
            description="We want a Django Python developer with SQL skills."
        )

        self.search_url = reverse("jobs-search")
        self.recommendations_url = reverse("jobs-recommendations")
        self.save_job_url = reverse("selected-jobs-list")

    def test_job_search_proxy(self):
        response = self.client.post(self.search_url, {"query": "Python"}, format="json")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(response.data["success"])

    def test_save_and_unsave_job(self):
        # 1. Save Job
        response = self.client.post(self.save_job_url, {
            "company_name": "Innovate Ltd",
            "job_title": "Django Developer",
            "apply_link": "https://innovate.link",
            "status": "SAVED"
        }, format="json")
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        
        # Check database
        self.assertTrue(SelectedJob.objects.filter(user=self.user, job_title="Django Developer").exists())
