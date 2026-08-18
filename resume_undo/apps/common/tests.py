import io
import zipfile
from django.test import SimpleTestCase
from django.core.exceptions import ValidationError
from rest_framework.exceptions import APIException
from common.exceptions import custom_exception_handler
from common.utils import extract_text_from_pdf, extract_text_from_docx
from common.gemini import call_gemini_api, generate_mock_response

class CommonUtilsTests(SimpleTestCase):
    def test_custom_exception_handler_format(self):
        # 1. Test standard API exception handling
        exc = APIException(detail="Unauthorized request")
        response = custom_exception_handler(exc, {})
        self.assertIsNotNone(response)
        self.assertFalse(response.data["success"])
        self.assertEqual(response.data["error"]["message"], "Unauthorized request")

        # 2. Test list-based validation error formatting
        from rest_framework.exceptions import ValidationError as DRFValidationError
        list_exc = DRFValidationError(detail=["First list error"])
        response_list = custom_exception_handler(list_exc, {})
        self.assertEqual(response_list.data["error"]["message"], "First list error")

        # 3. Test non_field_errors validation formatting
        dict_exc = DRFValidationError(detail={"non_field_errors": ["Special non field error"]})
        response_dict = custom_exception_handler(dict_exc, {})
        self.assertEqual(response_dict.data["error"]["message"], "Special non field error")

        # 4. Test standard field validation formatting
        field_exc = DRFValidationError(detail={"username": ["This field is required"]})
        response_field = custom_exception_handler(field_exc, {})
        self.assertEqual(response_field.data["error"]["message"], "Validation error occurred.")

        # 5. Test non-API unexpected error formatting
        runtime_exc = ValueError("Database failure")
        response_500 = custom_exception_handler(runtime_exc, {})
        self.assertEqual(response_500.status_code, 500)
        self.assertFalse(response_500.data["success"])
        self.assertIn("unexpected server error", response_500.data["error"]["message"])

    def test_is_premium_user_permission_class(self):
        from django.test import RequestFactory
        from common.permissions import IsPremiumUser
        from django.contrib.auth.models import AnonymousUser

        factory = RequestFactory()
        request = factory.get('/')
        
        # Test anonymous user
        request.user = AnonymousUser()
        permission = IsPremiumUser()
        self.assertFalse(permission.has_permission(request, None))


    def test_extract_text_from_pdf_corrupted(self):
        # Raw corrupted PDF byte stream
        file_obj = io.BytesIO(b"random garbage bytes that cannot compile")
        # Should execute ASCII regex extraction
        text = extract_text_from_pdf(file_obj)
        self.assertIn("random garbage", text)

    def test_extract_text_from_docx_fallback_parsing(self):
        # Construct a dummy zip docx in memory containing word/document.xml
        zip_buffer = io.BytesIO()
        with zipfile.ZipFile(zip_buffer, 'w') as z:
            xml_content = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
                <w:body>
                    <w:p>
                        <w:r>
                            <w:t>Hello World from Mock Docx Fallback!</w:t>
                        </w:r>
                    </w:p>
                </w:body>
            </w:document>
            """
            z.writestr("word/document.xml", xml_content)
            
        zip_buffer.seek(0)
        text = extract_text_from_docx(zip_buffer)
        self.assertEqual(text.strip(), "Hello World from Mock Docx Fallback!")

    def test_gemini_api_mock_fallbacks(self):
        # 1. Default fallback checking
        res = generate_mock_response("random string prompt")
        self.assertIn("status", res)
        self.assertEqual(res["status"], "success")

        # 2. Key components parsing detection mock check
        res_parse = call_gemini_api("Please extract information for resume schema: \"name\":")
        self.assertIn("skills", res_parse)
        self.assertTrue(len(res_parse["skills"]) > 0)


from rest_framework.test import APITestCase
from rest_framework import status
from django.contrib.auth import get_user_model
from django.urls import reverse
from resumes.models import Resume
from resumes.services import parse_and_save_resume
from django.core.files.uploadedfile import SimpleUploadedFile
from common.models import ExportHistory

User = get_user_model()

class ExportAPITests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            email="export_tester@career.ai",
            username="export_tester",
            password="testpassword123"
        )
        self.client.force_authenticate(user=self.user)
        
        VALID_PDF = b"%PDF-1.4\n1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj\n2 0 obj<</Type/Pages/Count 1/Kids[3 0 R]>>endobj\n3 0 obj<</Type/Page/MediaBox[0 0 612 792]/Parent 2 0 R/Resources<<>>>>endobj\nxref\n0 4\n0000000000 65535 f\n0000000009 00000 n\n0000000052 00000 n\n00000000101 00000 n\ntrailer<</Size 4/Root 1 0 R>>\nstartxref\n178\n%%EOF\n"
        
        # Upload a resume so there is data for the ats_report export
        self.resume = Resume.objects.create(
            user=self.user,
            title="Export Candidate Resume",
            file=SimpleUploadedFile("export.pdf", VALID_PDF, content_type="application/pdf")
        )
        parse_and_save_resume(self.resume)

    def test_export_pdf_ats_report(self):
        url = reverse("common-export", kwargs={"report_type": "ats_report", "file_format": "pdf"})
        response = self.client.get(url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.headers["Content-Type"], "application/pdf")
        self.assertIn("attachment; filename=", response.headers["Content-Disposition"])
        
        # Verify ExportHistory creation
        self.assertTrue(ExportHistory.objects.filter(user=self.user, report_type="ats_report", file_format="pdf").exists())

    def test_export_docx_ats_report(self):
        url = reverse("common-export", kwargs={"report_type": "ats_report", "file_format": "docx"})
        response = self.client.get(url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.headers["Content-Type"], "application/vnd.openxmlformats-officedocument.wordprocessingml.document")
        self.assertIn("attachment; filename=", response.headers["Content-Disposition"])

        # Verify ExportHistory creation
        self.assertTrue(ExportHistory.objects.filter(user=self.user, report_type="ats_report", file_format="docx").exists())

    def test_export_unsupported_format(self):
        url = reverse("common-export", kwargs={"report_type": "ats_report", "file_format": "txt"})
        response = self.client.get(url)
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertFalse(response.data["success"])

    def test_export_invalid_report_type(self):
        url = reverse("common-export", kwargs={"report_type": "unknown_report", "file_format": "pdf"})
        response = self.client.get(url)
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertFalse(response.data["success"])

    def test_export_career_report_pdf(self):
        url = reverse("common-export", kwargs={"report_type": "career_report", "file_format": "pdf"})
        response = self.client.get(url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.headers["Content-Type"], "application/pdf")
        self.assertTrue(ExportHistory.objects.filter(user=self.user, report_type="career_report", file_format="pdf").exists())

