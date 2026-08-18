import uuid
from django.db import models
from django.conf import settings


class Resume(models.Model):
    """
    Master Resume Table per SAD Section 7.
    """
    FILE_TYPE_CHOICES = (
        ("pdf", "PDF Document"),
        ("docx", "Microsoft Word Document"),
    )

    id = models.UUIDField(
        primary_key=True,
        default=uuid.uuid4,
        editable=False
    )
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="resumes"
    )
    title = models.CharField(max_length=255)
    file = models.FileField(upload_to="resumes/")
    file_type = models.CharField(max_length=10, choices=FILE_TYPE_CHOICES, default="pdf")
    raw_text = models.TextField(blank=True, default="")
    is_parsed = models.BooleanField(default=False)
    version = models.PositiveIntegerField(default=1)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.title} (v{self.version}) - {self.user.email}"


class ResumeSection(models.Model):
    """
    Parsed Resume Sections per SAD Section 7.
    """
    SECTION_TYPE_CHOICES = (
        ("SUMMARY", "Professional Summary"),
        ("EXPERIENCE", "Work Experience"),
        ("EDUCATION", "Education"),
        ("SKILLS", "Skills"),
        ("PROJECTS", "Projects"),
        ("CERTIFICATIONS", "Certifications"),
        ("OTHER", "Other"),
    )

    id = models.UUIDField(
        primary_key=True,
        default=uuid.uuid4,
        editable=False
    )
    resume = models.ForeignKey(
        Resume,
        on_delete=models.CASCADE,
        related_name="sections"
    )
    section_type = models.CharField(max_length=50, choices=SECTION_TYPE_CHOICES, default="OTHER")
    content = models.TextField()
    ordinal_position = models.PositiveIntegerField(default=1)

    class Meta:
        ordering = ["ordinal_position"]

    def __str__(self):
        return f"Section: {self.section_type} (Pos: {self.ordinal_position}) for {self.resume.title}"


class ParsedResume(models.Model):
    """
    Legacy / Detailed Extracted Metadata Model for backward compatibility.
    """
    id = models.UUIDField(
        primary_key=True,
        default=uuid.uuid4,
        editable=False
    )
    resume = models.OneToOneField(
        Resume,
        on_delete=models.CASCADE,
        related_name="parsed_content"
    )
    extracted_text = models.TextField(blank=True)
    name = models.CharField(max_length=255, blank=True)
    email = models.CharField(max_length=255, blank=True)
    phone = models.CharField(max_length=50, blank=True)
    location = models.CharField(max_length=255, blank=True)
    extracted_skills = models.JSONField(default=list)
    extracted_projects = models.JSONField(default=list)
    extracted_experience = models.JSONField(default=list)
    extracted_education = models.JSONField(default=list)
    extracted_certifications = models.JSONField(default=list)

    def __str__(self):
        return f"Parsed: {self.resume.title}"
