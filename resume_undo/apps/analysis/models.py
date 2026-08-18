import uuid
from django.db import models
from django.conf import settings
from resumes.models import Resume

class ATSAnalysis(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    resume = models.ForeignKey(Resume, on_delete=models.CASCADE, related_name="ats_analyses")
    ats_score = models.PositiveIntegerField(default=0)
    keyword_score = models.PositiveIntegerField(default=0)
    formatting_score = models.PositiveIntegerField(default=0)
    skills_score = models.PositiveIntegerField(default=0)
    experience_score = models.PositiveIntegerField(default=0)
    education_score = models.PositiveIntegerField(default=0)
    completeness_score = models.PositiveIntegerField(default=0)
    suggestions = models.JSONField(default=list)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"ATS: {self.ats_score} - {self.resume.title}"

class ResumeImprovement(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    resume = models.ForeignKey(Resume, on_delete=models.CASCADE, related_name="improvements")
    strengths = models.JSONField(default=list)
    weaknesses = models.JSONField(default=list)
    better_bullet_points = models.JSONField(default=dict)
    summary_suggestions = models.TextField(blank=True)
    missing_sections = models.JSONField(default=list)
    tailored_content = models.TextField(blank=True) # Holds Original + Accepted Diff Suggestions
    jd_tailored_content = models.TextField(blank=True) # Holds JD-specific tailored resume
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Improvement - {self.resume.title}"

class PositionAnalysis(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    resume = models.ForeignKey(Resume, on_delete=models.CASCADE, related_name="position_analyses")
    target_position = models.CharField(max_length=255)
    match_score = models.PositiveIntegerField()
    missing_skills = models.JSONField(default=list)
    recommended_skills = models.JSONField(default=list)
    suggestions = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Position Match: {self.match_score} for {self.target_position}"

class JDMatchAnalysis(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    resume = models.ForeignKey(Resume, on_delete=models.CASCADE, related_name="jd_matches")
    job_description = models.TextField()
    match_score = models.PositiveIntegerField()
    missing_keywords = models.JSONField(default=list)
    matched_skills = models.JSONField(default=list)
    missing_skills = models.JSONField(default=list)
    ats_compatibility = models.JSONField(default=dict)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"JD Match: {self.match_score} - {self.resume.title}"

# Premium Models
class SkillGapAnalysis(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="skill_gaps")
    target_role = models.CharField(max_length=255)
    missing_skills = models.JSONField(default=list)
    recommended_skills = models.JSONField(default=list)
    learning_priority = models.JSONField(default=list)
    roadmap = models.JSONField(default=list)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Skill Gap: {self.target_role} for {self.user.email}"

class CareerRoadmap(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="roadmaps")
    current_role = models.CharField(max_length=255)
    target_role = models.CharField(max_length=255)
    learning_path = models.JSONField(default=list)
    technologies = models.JSONField(default=list)
    certifications = models.JSONField(default=list)
    milestones = models.JSONField(default=list)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Roadmap: {self.current_role} to {self.target_role}"

class InterviewPreparation(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    resume = models.ForeignKey(Resume, on_delete=models.CASCADE, related_name="interview_preps")
    target_role = models.CharField(max_length=255)
    difficulty_level = models.CharField(max_length=50, default="intermediate") # beginner, intermediate, advanced
    technical_questions = models.JSONField(default=list)
    hr_questions = models.JSONField(default=list)
    role_specific_questions = models.JSONField(default=list)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Interview Prep: {self.target_role} ({self.difficulty_level})"

class ProjectRecommendation(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    resume = models.ForeignKey(Resume, on_delete=models.CASCADE, related_name="project_recommendations")
    career_goal = models.CharField(max_length=255)
    recommended_projects = models.JSONField(default=list)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Projects: {self.career_goal}"

class CoverLetter(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    resume = models.ForeignKey(Resume, on_delete=models.CASCADE, related_name="cover_letters")
    job_title = models.CharField(max_length=255)
    company_name = models.CharField(max_length=255)
    job_description = models.TextField()
    content = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Cover Letter: {self.job_title} at {self.company_name}"


class CareerReadinessSnapshot(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="career_snapshots")
    career_score = models.IntegerField()
    factors = models.JSONField() # ats, skills, completeness, experience, job_match, profile
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Snapshot {self.career_score} - {self.user.email} ({self.created_at.strftime('%Y-%m-%d')})"

