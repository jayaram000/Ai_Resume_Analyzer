import uuid
from django.db import models
from django.conf import settings

class ExportHistory(models.Model):
    id = models.UUIDField(
        primary_key=True,
        default=uuid.uuid4,
        editable=False
    )
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="exports"
    )
    report_type = models.CharField(max_length=100) # ats_report, jd_match, career_report, skill_gap, roadmap
    file_format = models.CharField(max_length=10) # pdf, docx
    exported_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.user.email} exported {self.report_type} ({self.file_format})"
