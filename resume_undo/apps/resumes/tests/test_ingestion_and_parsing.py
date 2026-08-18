import io
from unittest.mock import patch
from django.test import TestCase
from django.contrib.auth import get_user_model
from django.core.files.uploadedfile import SimpleUploadedFile
from django.core.exceptions import ValidationError
from rest_framework.test import APIClient
from rest_framework import status

from parsing.services.file_validator import FileValidationService
from parsing.services.section_detector import SectionDetectionService
from resumes.models import Resume, ResumeSection
from resumes.use_cases.upload_resume import UploadResumeUseCase
from resumes.repositories.postgres_repository import PostgresResumeRepository

User = get_user_model()

# Valid minimal 1-page PDF bytes
VALID_MINIMAL_PDF_BYTES = (
    b"%PDF-1.4\n"
    b"1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj\n"
    b"2 0 obj<</Type/Pages/Count 1/Kids[3 0 R]>>endobj\n"
    b"3 0 obj<</Type/Page/MediaBox[0 0 612 792]/Parent 2 0 R/Resources<<>>>>endobj\n"
    b"xref\n0 4\n0000000000 65535 f\n0000000009 00000 n\n0000000052 00000 n\n0000000101 00000 n\n"
    b"trailer<</Size 4/Root 1 0 R>>\nstartxref\n178\n%%EOF\n"
)


class FileValidationServiceTestCase(TestCase):
    def test_valid_pdf_file_passes_validation(self):
        uploaded_file = SimpleUploadedFile("sample.pdf", VALID_MINIMAL_PDF_BYTES, content_type="application/pdf")
        
        is_valid, file_type = FileValidationService.validate_resume_file(uploaded_file)
        self.assertTrue(is_valid)
        self.assertEqual(file_type, "pdf")

    def test_valid_docx_file_passes_validation(self):
        docx_content = b"PK\x03\x04 Sample DOCX Zip Header"
        uploaded_file = SimpleUploadedFile("sample.docx", docx_content, content_type="application/vnd.openxmlformats-officedocument.wordprocessingml.document")
        
        is_valid, file_type = FileValidationService.validate_resume_file(uploaded_file)
        self.assertTrue(is_valid)
        self.assertEqual(file_type, "docx")

    def test_oversized_file_raises_validation_error(self):
        large_content = b"%PDF-1.5 " + b"0" * (5 * 1024 * 1024 + 100)
        uploaded_file = SimpleUploadedFile("large.pdf", large_content, content_type="application/pdf")
        
        with self.assertRaises(ValidationError):
            FileValidationService.validate_resume_file(uploaded_file)

    def test_invalid_extension_raises_validation_error(self):
        uploaded_file = SimpleUploadedFile("script.py", b"print('hello')", content_type="text/plain")
        with self.assertRaises(ValidationError):
            FileValidationService.validate_resume_file(uploaded_file)

    def test_corrupt_magic_header_raises_validation_error(self):
        fake_pdf = SimpleUploadedFile("corrupt.pdf", b"NOT_A_PDF_HEADER", content_type="application/pdf")
        with self.assertRaises(ValidationError):
            FileValidationService.validate_resume_file(fake_pdf)


class SectionDetectionServiceTestCase(TestCase):
    def test_detects_standard_resume_sections(self):
        sample_text = """
        John Doe
        John.doe@example.com
        
        SUMMARY
        Senior Backend Engineer with 6 years of experience in Django and Microservices.
        
        EXPERIENCE
        Senior Developer at Tech Corp
        Built scalable APIs and optimized Postgres queries.
        
        EDUCATION
        B.S. Computer Science - State University
        
        SKILLS
        Python, Django, PostgreSQL, Redis, Docker
        """
        sections = SectionDetectionService.detect_sections(sample_text)
        self.assertGreaterEqual(len(sections), 4)
        
        section_types = [s["section_type"] for s in sections]
        self.assertIn("SUMMARY", section_types)
        self.assertIn("EXPERIENCE", section_types)
        self.assertIn("EDUCATION", section_types)
        self.assertIn("SKILLS", section_types)


class UploadResumeUseCaseTestCase(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(email="testuser@example.com", username="testuser", password="password123")
        self.repo = PostgresResumeRepository()
        self.use_case = UploadResumeUseCase(self.repo)

    @patch("parsing.tasks.extract_resume_text_task.delay")
    def test_upload_resume_creates_record_and_dispatches_task(self, mock_celery_delay):
        uploaded_file = SimpleUploadedFile("my_resume.pdf", VALID_MINIMAL_PDF_BYTES, content_type="application/pdf")
        
        result = self.use_case.execute(user=self.user, uploaded_file=uploaded_file, custom_title="My Backend Resume")
        
        self.assertEqual(result["title"], "My Backend Resume")
        self.assertEqual(result["file_type"], "pdf")
        self.assertEqual(result["version"], 1)
        mock_celery_delay.assert_called_once()

    @patch("parsing.tasks.extract_resume_text_task.delay")
    def test_versioning_increments_for_duplicate_titles(self, mock_celery_delay):
        f1 = SimpleUploadedFile("resume.pdf", VALID_MINIMAL_PDF_BYTES, content_type="application/pdf")
        f2 = SimpleUploadedFile("resume.pdf", VALID_MINIMAL_PDF_BYTES, content_type="application/pdf")
        
        r1 = self.use_case.execute(user=self.user, uploaded_file=f1, custom_title="Standard Resume")
        r2 = self.use_case.execute(user=self.user, uploaded_file=f2, custom_title="Standard Resume")
        
        self.assertEqual(r1["version"], 1)
        self.assertEqual(r2["version"], 2)


class ResumeAPIIntegrationTestCase(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.user = User.objects.create_user(email="apiuser@example.com", username="apiuser", password="password123")
        self.client.force_authenticate(user=self.user)

    @patch("parsing.tasks.extract_resume_text_task.delay")
    def test_upload_api_returns_202_accepted(self, mock_celery):
        uploaded_file = SimpleUploadedFile("dev_resume.pdf", VALID_MINIMAL_PDF_BYTES, content_type="application/pdf")
        
        response = self.client.post(
            "/api/v1/resumes/",
            {"title": "Dev Resume", "file": uploaded_file},
            format="multipart"
        )
        
        self.assertEqual(response.status_code, status.HTTP_202_ACCEPTED)
        self.assertEqual(response.data["status"], "success")
        self.assertIn("resume_id", response.data["data"])

    def test_upload_api_unauthenticated_returns_401(self):
        self.client.logout()
        uploaded_file = SimpleUploadedFile("dev_resume.pdf", VALID_MINIMAL_PDF_BYTES, content_type="application/pdf")
        
        response = self.client.post("/api/v1/resumes/", {"file": uploaded_file}, format="multipart")
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)
