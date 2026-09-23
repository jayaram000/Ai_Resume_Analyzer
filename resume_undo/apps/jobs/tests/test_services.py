from unittest.mock import patch
from django.test import TestCase
from django.contrib.auth import get_user_model
from jobs.models import Job, SelectedJob
from jobs.services import (
    SalaryNormalizationService,
    ApplicationTrackerService,
    generate_platform_links,
    is_relevant_tech_job,
    is_geo_compatible,
)

User = get_user_model()

class JobsServicesUnitTests(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            email="jobseeker@career.ai",
            username="jobseeker",
            password="securepassword123"
        )
        self.job = Job.objects.create(
            title="Senior Python Backend Developer",
            company_name="Acme Tech",
            location="Remote",
            apply_link="https://acme.tech/careers/123",
            jsearch_id="job_acme_123"
        )

    def test_salary_normalization_lpa(self):
        """Test Indian Lakhs Per Annum (LPA) salary parsing."""
        res = SalaryNormalizationService.normalize_salary("15 - 25 LPA")
        self.assertEqual(res["currency"], "INR")
        self.assertEqual(res["period"], "yearly")
        self.assertEqual(res["min"], 1500000)
        self.assertEqual(res["max"], 2500000)

    def test_salary_normalization_usd_hourly(self):
        """Test USD hourly wage normalization to annual rate."""
        res = SalaryNormalizationService.normalize_salary("$60 - $80 / hr")
        self.assertEqual(res["currency"], "USD")
        self.assertEqual(res["period"], "hourly")
        self.assertEqual(res["min"], 60 * 2080)
        self.assertEqual(res["max"], 80 * 2080)

    def test_salary_normalization_usd_yearly(self):
        """Test USD annual range parsing."""
        res = SalaryNormalizationService.normalize_salary("$120,000 - $150,000 a year")
        self.assertEqual(res["currency"], "USD")
        self.assertEqual(res["min"], 120000)
        self.assertEqual(res["max"], 150000)

    def test_application_tracker_allowed_transitions(self):
        """Test state machine valid/invalid status transitions."""
        self.assertTrue(ApplicationTrackerService.can_transition(
            SelectedJob.StatusChoices.SAVED,
            SelectedJob.StatusChoices.APPLIED
        ))
        self.assertTrue(ApplicationTrackerService.can_transition(
            SelectedJob.StatusChoices.APPLIED,
            SelectedJob.StatusChoices.INTERVIEWING
        ))
        self.assertTrue(ApplicationTrackerService.can_transition(
            SelectedJob.StatusChoices.INTERVIEWING,
            SelectedJob.StatusChoices.OFFER_RECEIVED
        ))
        # Direct jump from SAVED to OFFER_RECEIVED is disallowed
        self.assertFalse(ApplicationTrackerService.can_transition(
            SelectedJob.StatusChoices.SAVED,
            SelectedJob.StatusChoices.OFFER_RECEIVED
        ))

    def test_kanban_summary_and_conversion_funnel(self):
        """Test Kanban count calculation and conversion funnel rates."""
        SelectedJob.objects.create(
            user=self.user,
            job=self.job,
            company_name="Acme Tech",
            job_title="Senior Python Backend Developer",
            apply_link="https://acme.tech/careers/123",
            status=SelectedJob.StatusChoices.SAVED
        )
        SelectedJob.objects.create(
            user=self.user,
            company_name="Global Systems",
            job_title="Full Stack Engineer",
            apply_link="https://global.sys/apply",
            status=SelectedJob.StatusChoices.APPLIED
        )
        SelectedJob.objects.create(
            user=self.user,
            company_name="Cloud Corp",
            job_title="Cloud Engineer",
            apply_link="https://cloud.corp/apply",
            status=SelectedJob.StatusChoices.OFFER_RECEIVED
        )

        counts = ApplicationTrackerService.get_kanban_summary(self.user)
        self.assertEqual(counts[SelectedJob.StatusChoices.SAVED], 1)
        self.assertEqual(counts[SelectedJob.StatusChoices.APPLIED], 1)
        self.assertEqual(counts[SelectedJob.StatusChoices.OFFER_RECEIVED], 1)

        funnel = ApplicationTrackerService.get_conversion_funnel(self.user)
        self.assertIn("stages", funnel)
        self.assertEqual(funnel["total_tracked"], 3)
        self.assertEqual(len(funnel["stages"]), 5)

    def test_generate_platform_links(self):
        """Test platform search links generation."""
        links = generate_platform_links("Google", "Software Engineer", "Bangalore")
        self.assertIn("linkedin", links)
        self.assertIn("naukri", links)
        self.assertIn("glassdoor", links)
        self.assertIn("google", links["linkedin"].lower())

    def test_is_relevant_tech_job(self):
        """Test relevance heuristic filtering out non-tech titles."""
        self.assertTrue(is_relevant_tech_job("Backend Engineer", "Build Python APIs"))
        self.assertFalse(is_relevant_tech_job("Cashier", "Handle store transactions"))

    def test_is_geo_compatible(self):
        """Test geographical compatibility heuristics."""
        self.assertTrue(is_geo_compatible("Bangalore, Karnataka", "bangalore"))
        self.assertTrue(is_geo_compatible("Worldwide Remote", "Bangalore"))
        self.assertTrue(is_geo_compatible("Anywhere", "Remote"))
