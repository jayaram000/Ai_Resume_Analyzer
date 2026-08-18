from django.contrib.auth import get_user_model
from django.urls import reverse
from django.utils import timezone
from django.core.files.uploadedfile import SimpleUploadedFile
from rest_framework import status
from rest_framework.test import APITestCase
from resumes.models import Resume
from resumes.services import parse_and_save_resume
from analysis.models import ATSAnalysis, ResumeImprovement
from analysis.services import ATSScoringService
from subscriptions.models import SubscriptionPlan, UserSubscription

User = get_user_model()

class AnalysisTests(APITestCase):
    def setUp(self):
        # 1. Create Normal User
        self.user = User.objects.create_user(
            email="normal@career.ai",
            username="normaluser",
            password="password123"
        )
        
        # 2. Create Premium User
        self.premium_user = User.objects.create_user(
            email="premium@career.ai",
            username="premiumuser",
            password="password123"
        )
        
        # 3. Create active subscription for Premium User
        self.plan = SubscriptionPlan.objects.create(
            name="Premium Plan",
            price=499,
            duration_days=30,
            features=["All Tools"]
        )
        UserSubscription.objects.create(
            user=self.premium_user,
            plan=self.plan,
            start_date=timezone.now(),
            end_date=timezone.now() + timezone.timedelta(days=30),
            status="active"
        )
        
        VALID_PDF = b"%PDF-1.4\n1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj\n2 0 obj<</Type/Pages/Count 1/Kids[3 0 R]>>endobj\n3 0 obj<</Type/Page/MediaBox[0 0 612 792]/Parent 2 0 R/Resources<<>>>>endobj\nxref\n0 4\n0000000000 65535 f\n0000000009 00000 n\n0000000052 00000 n\n00000000101 00000 n\ntrailer<</Size 4/Root 1 0 R>>\nstartxref\n178\n%%EOF\n"
        
        # 4. Create resume for normal user
        self.resume = Resume.objects.create(
            user=self.user,
            title="Normal Resume",
            file=SimpleUploadedFile("normal.pdf", VALID_PDF, content_type="application/pdf")
        )
        parse_and_save_resume(self.resume)

        # 5. Create resume for premium user
        self.premium_resume = Resume.objects.create(
            user=self.premium_user,
            title="Premium Resume",
            file=SimpleUploadedFile("premium.pdf", VALID_PDF, content_type="application/pdf")
        )
        parse_and_save_resume(self.premium_resume)

    def test_ats_scoring_service_math(self):
        scores = ATSScoringService.calculate_ats_score(self.resume)
        self.assertIn("ats_score", scores)
        self.assertIn("keyword_score", scores)
        self.assertIn("skills_score", scores)
        self.assertIn("experience_score", scores)
        self.assertIn("education_score", scores)
        self.assertIn("completeness_score", scores)
        
        # Check weighted formula correctness
        calculated_weighted = int(
            (scores["keyword_score"] * 0.25) +
            (scores["skills_score"] * 0.20) +
            (scores["experience_score"] * 0.20) +
            (scores["formatting_score"] * 0.15) +
            (scores["education_score"] * 0.10) +
            (scores["completeness_score"] * 0.10)
        )
        self.assertEqual(scores["ats_score"], calculated_weighted)

    def test_normal_user_allowed_apis(self):
        self.client.force_authenticate(user=self.user)
        
        # Test ATS Analysis trigger
        url = reverse("analysis-ats", kwargs={"resume_id": str(self.resume.id)})
        response = self.client.post(url, format="json")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(response.data["success"])
        
        # Test JD Match trigger
        url = reverse("analysis-match-jd", kwargs={"resume_id": str(self.resume.id)})
        response = self.client.post(url, {"job_description": "Looking for Python, Django developer"}, format="json")
        self.assertEqual(response.status_code, status.HTTP_200_OK)

    def test_normal_user_blocked_from_premium_apis(self):
        self.client.force_authenticate(user=self.user)
        
        # Test Skill Gap blocked
        url = reverse("analysis-skill-gap")
        response = self.client.post(url, {"target_role": "Flutter Developer"}, format="json")
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)
        
        # Test Career Roadmap blocked
        url = reverse("analysis-roadmap")
        response = self.client.post(url, {"current_role": "Junior", "target_role": "Senior"}, format="json")
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_premium_user_allowed_on_premium_apis(self):
        self.client.force_authenticate(user=self.premium_user)
        
        # Test Skill Gap allowed
        url = reverse("analysis-skill-gap")
        response = self.client.post(url, {"target_role": "Flutter Developer"}, format="json")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(response.data["success"])
        
        # Test Interview Prep allowed
        url = reverse("analysis-interview", kwargs={"resume_id": str(self.premium_resume.id)})
        response = self.client.post(url, {"target_role": "Mobile Engineer"}, format="json")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
