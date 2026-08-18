import uuid
from django.db import models
from django.conf import settings

class Job(models.Model):
    id = models.UUIDField(
        primary_key=True,
        default=uuid.uuid4,
        editable=False
    )
    jsearch_id = models.CharField(max_length=255, unique=True, db_index=True)
    title = models.CharField(max_length=255)
    company_name = models.CharField(max_length=255)
    company_logo = models.URLField(max_length=500, blank=True, null=True)
    location = models.CharField(max_length=255)
    apply_link = models.URLField(max_length=1000)
    description = models.TextField(blank=True)
    raw_data = models.JSONField(default=dict)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.title} at {self.company_name}"

class JobRecommendation(models.Model):
    id = models.UUIDField(
        primary_key=True,
        default=uuid.uuid4,
        editable=False
    )
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="job_recommendations"
    )
    job = models.ForeignKey(
        Job,
        on_delete=models.CASCADE,
        related_name="recommendations"
    )
    match_score = models.PositiveIntegerField()
    reasons = models.JSONField(default=list)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Rec: {self.match_score} for {self.user.email}"

class SelectedJob(models.Model):
    class StatusChoices(models.TextChoices):
        SAVED = 'SAVED', 'Saved'
        NOT_APPLIED = 'NOT_APPLIED', 'Not Applied'
        APPLIED = 'APPLIED', 'Applied'
        INTERVIEW_CALL_RECEIVED = 'INTERVIEW_CALL_RECEIVED', 'Interview Call Received'
        REJECTED = 'REJECTED', 'Rejected'
        OFFER_RECEIVED = 'OFFER_RECEIVED', 'Offer Received'

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="selected_jobs")
    job = models.ForeignKey(Job, on_delete=models.CASCADE, related_name="selected_by_users", null=True, blank=True)
    external_job_id = models.CharField(max_length=255, blank=True)
    company_name = models.CharField(max_length=255)
    job_title = models.CharField(max_length=255)
    apply_link = models.URLField(max_length=1000)
    location = models.CharField(max_length=255, blank=True)
    status = models.CharField(max_length=50, choices=StatusChoices.choices, default=StatusChoices.SAVED)
    saved_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.job_title} at {self.company_name} - {self.status}"

