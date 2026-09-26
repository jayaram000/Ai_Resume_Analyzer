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


class FeatureUsageLog(models.Model):
    """
    Tracks freemium action consumption over a 5-hour rolling window.
    Actions: 'ats_scan', 'bullet_rewrite', 'jd_match', 'resume_comparison'
    """
    ACTION_CHOICES = (
        ("ats_scan", "ATS Analysis Scan"),
        ("bullet_rewrite", "Bullet Point Rewrite"),
        ("jd_match", "Job Description Match"),
        ("resume_comparison", "Resume Version Comparison"),
    )

    id = models.UUIDField(
        primary_key=True,
        default=uuid.uuid4,
        editable=False,
    )
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="feature_usage_logs",
    )
    action_type = models.CharField(max_length=50, choices=ACTION_CHOICES)
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)

    class Meta:
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["user", "created_at"], name="usage_user_created_idx"),
        ]

    def __str__(self):
        return f"{self.user.email} - {self.action_type} at {self.created_at.strftime('%Y-%m-%d %H:%M:%S')}"
