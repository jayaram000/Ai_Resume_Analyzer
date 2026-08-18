from django.contrib.auth import get_user_model
from django.urls import reverse
from django.core.files.uploadedfile import SimpleUploadedFile
from rest_framework import status
from rest_framework.test import APITestCase
from resumes.models import Resume
from resumes.services import parse_and_save_resume
from analysis.models import ATSAnalysis
from analysis.services import generate_ats_analysis

User = get_user_model()

class DashboardTests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            email="dashboard@career.ai",
            username="dashuser",
            password="password123"
        )
        self.client.force_authenticate(user=self.user)
        
        VALID_PDF = b"%PDF-1.4\n1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj\n2 0 obj<</Type/Pages/Count 1/Kids[3 0 R]>>endobj\n3 0 obj<</Type/Page/MediaBox[0 0 612 792]/Parent 2 0 R/Resources<<>>>>endobj\nxref\n0 4\n0000000000 65535 f\n0000000009 00000 n\n0000000052 00000 n\n00000000101 00000 n\ntrailer<</Size 4/Root 1 0 R>>\nstartxref\n178\n%%EOF\n"

        # Create multiple resumes
        self.r1 = Resume.objects.create(
            user=self.user,
            title="Resume Alpha",
            file=SimpleUploadedFile("alpha.pdf", VALID_PDF, content_type="application/pdf")
        )
        parse_and_save_resume(self.r1)
        
        self.r2 = Resume.objects.create(
            user=self.user,
            title="Resume Beta",
            file=SimpleUploadedFile("beta.pdf", VALID_PDF, content_type="application/pdf")
        )
        parse_and_save_resume(self.r2)

        # Trigger ATS analysis to generate scores
        generate_ats_analysis(self.r1)
        generate_ats_analysis(self.r2)

    def test_dashboard_stats_endpoint(self):
        url = reverse("dashboard-stats")
        response = self.client.get(url)
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(response.data["success"])
        
        data = response.data["data"]
        
        # Verify counts
        self.assertEqual(data["resume_analytics"]["total_resumes"], 2)
        
        # Verify aggregates
        best = data["resume_analytics"]["best_resume_score"]
        lowest = data["resume_analytics"]["lowest_resume_score"]
        self.assertTrue(best >= lowest)
        
        career_readiness = data["career_analytics"]["career_readiness_score"]
        self.assertTrue(career_readiness > 0)
        
        # Verify trend has records
        self.assertEqual(len(data["resume_analytics"]["ats_trend"]), 2)

    def test_career_score_endpoint(self):
        url = reverse("career-score")
        response = self.client.get(url)
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(response.data["success"])
        
        data = response.data["data"]
        self.assertIn("career_score", data)
        self.assertIn("factors", data)
        self.assertIn("trend", data)
        self.assertIn("recommended_actions", data)
        
        # There should be at least one trend snapshot created
        self.assertTrue(len(data["trend"]) >= 1)

    def test_admin_analytics_gating_normal_user(self):
        # A normal authenticated user (non-staff) should be blocked
        url = reverse("admin-analytics")
        response = self.client.get(url)
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_admin_analytics_for_admin_user(self):
        # Create an admin/staff user
        admin_user = User.objects.create_superuser(
            email="admin@career.ai",
            username="adminuser",
            password="adminpassword123"
        )
        self.client.force_authenticate(user=admin_user)
        
        # Create subscription for calculation check
        from subscriptions.models import SubscriptionPlan, UserSubscription
        from django.utils import timezone
        
        plan = SubscriptionPlan.objects.create(
            name="Super Premium",
            price=600,
            duration_days=30,
            is_active=True
        )
        UserSubscription.objects.create(
            user=self.user,
            plan=plan,
            start_date=timezone.now(),
            end_date=timezone.now() + timezone.timedelta(days=30),
            status="active"
        )
        
        url = reverse("admin-analytics")
        response = self.client.get(url)
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(response.data["success"])
        
        data = response.data["data"]
        self.assertIn("users", data)
        self.assertIn("resumes", data)
        self.assertIn("jobs", data)
        self.assertIn("revenue", data)
        self.assertIn("subscriptions", data)
        
        # Verify total users count (self.user + admin_user)
        self.assertEqual(data["users"]["total_users"], 2)
        
        # Verify MRR calculation (600 / (30/30) = 600)
        self.assertEqual(data["revenue"]["monthly_recurring_revenue"], 600.0)
        self.assertEqual(data["revenue"]["annual_run_rate"], 7200.0)

