from rest_framework import serializers
from analysis.models import (
    ATSAnalysis,
    ResumeImprovement,
    PositionAnalysis,
    JDMatchAnalysis,
    SkillGapAnalysis,
    CareerRoadmap,
    InterviewPreparation,
    ProjectRecommendation,
    CoverLetter,
    CareerReadinessSnapshot
)

class ATSAnalysisSerializer(serializers.ModelSerializer):
    class Meta:
        model = ATSAnalysis
        fields = "__all__"

class ResumeImprovementSerializer(serializers.ModelSerializer):
    class Meta:
        model = ResumeImprovement
        fields = "__all__"

class PositionAnalysisSerializer(serializers.ModelSerializer):
    class Meta:
        model = PositionAnalysis
        fields = "__all__"

class JDMatchAnalysisSerializer(serializers.ModelSerializer):
    recommendations = serializers.SerializerMethodField()

    class Meta:
        model = JDMatchAnalysis
        fields = "__all__"

    def get_recommendations(self, obj):
        if isinstance(obj.ats_compatibility, dict):
            recs = obj.ats_compatibility.get("recommendations", [])
            if recs:
                if isinstance(recs, list):
                    return "\n• ".join(str(r) for r in recs)
                return str(recs)
        if obj.missing_skills:
            return f"To increase your match score, consider highlighting experience with: {', '.join(obj.missing_skills[:4])}."
        return "Strong overall profile match."

class SkillGapAnalysisSerializer(serializers.ModelSerializer):
    match_score = serializers.SerializerMethodField()
    readiness_score = serializers.SerializerMethodField()
    readiness_level = serializers.SerializerMethodField()
    readiness_summary = serializers.SerializerMethodField()
    matched_skills = serializers.SerializerMethodField()
    categorized_gaps = serializers.SerializerMethodField()
    recommended_projects = serializers.SerializerMethodField()
    recommended_certifications = serializers.SerializerMethodField()
    resume_transition_tips = serializers.SerializerMethodField()

    class Meta:
        model = SkillGapAnalysis
        fields = "__all__"

    def _get_lp(self, obj):
        if obj.learning_priority and isinstance(obj.learning_priority, list) and len(obj.learning_priority) > 0:
            if isinstance(obj.learning_priority[0], dict):
                return obj.learning_priority[0]
        return {}

    def get_match_score(self, obj):
        return self._get_lp(obj).get("match_score", 65)

    def get_readiness_score(self, obj):
        return self._get_lp(obj).get("match_score", 65)

    def get_readiness_level(self, obj):
        return self._get_lp(obj).get("readiness_level", "Role Transition Analysis")

    def get_readiness_summary(self, obj):
        return self._get_lp(obj).get("readiness_summary", "")

    def get_matched_skills(self, obj):
        return self._get_lp(obj).get("matched_skills", [])

    def get_categorized_gaps(self, obj):
        return self._get_lp(obj).get("categorized_gaps", {})

    def get_recommended_projects(self, obj):
        return self._get_lp(obj).get("recommended_projects", [])

    def get_recommended_certifications(self, obj):
        return self._get_lp(obj).get("recommended_certifications", [])

    def get_resume_transition_tips(self, obj):
        return self._get_lp(obj).get("resume_transition_tips", [])

class CareerRoadmapSerializer(serializers.ModelSerializer):
    projects = serializers.SerializerMethodField()
    youtube_videos = serializers.SerializerMethodField()
    youtube_channels = serializers.SerializerMethodField()
    documentation_sites = serializers.SerializerMethodField()
    popular_courses = serializers.SerializerMethodField()
    free_courses = serializers.SerializerMethodField()

    class Meta:
        model = CareerRoadmap
        fields = "__all__"

    def _get_milestone_dict(self, obj):
        if isinstance(obj.milestones, dict):
            return obj.milestones
        if isinstance(obj.milestones, list) and len(obj.milestones) > 0 and isinstance(obj.milestones[0], dict):
            return obj.milestones[0]
        return {}

    def get_projects(self, obj):
        return self._get_milestone_dict(obj).get("projects", [])

    def get_youtube_videos(self, obj):
        d = self._get_milestone_dict(obj)
        return d.get("youtube_videos", d.get("video_tutorials", []))

    def get_youtube_channels(self, obj):
        return self._get_milestone_dict(obj).get("youtube_channels", [])

    def get_documentation_sites(self, obj):
        return self._get_milestone_dict(obj).get("documentation_sites", [])

    def get_popular_courses(self, obj):
        return self._get_milestone_dict(obj).get("popular_courses", [])

    def get_free_courses(self, obj):
        return self._get_milestone_dict(obj).get("free_courses", [])

class InterviewPreparationSerializer(serializers.ModelSerializer):
    class Meta:
        model = InterviewPreparation
        fields = "__all__"

class ProjectRecommendationSerializer(serializers.ModelSerializer):
    class Meta:
        model = ProjectRecommendation
        fields = "__all__"

class CoverLetterSerializer(serializers.ModelSerializer):
    class Meta:
        model = CoverLetter
        fields = "__all__"

class CareerReadinessSnapshotSerializer(serializers.ModelSerializer):
    class Meta:
        model = CareerReadinessSnapshot
        fields = "__all__"

# Input Serializers
class PositionAnalysisInputSerializer(serializers.Serializer):
    target_position = serializers.CharField(max_length=255)

class JDMatchInputSerializer(serializers.Serializer):
    job_description = serializers.CharField()

class SkillGapInputSerializer(serializers.Serializer):
    target_role = serializers.CharField(max_length=255)
    experience = serializers.CharField(max_length=50, required=False, default="Mid-Level")
    resume_id = serializers.CharField(max_length=255, required=False, allow_null=True, allow_blank=True)

class CareerRoadmapInputSerializer(serializers.Serializer):
    current_role = serializers.CharField(max_length=255, required=False, default="", allow_blank=True)
    target_role = serializers.CharField(max_length=255)

class InterviewPrepInputSerializer(serializers.Serializer):
    target_role = serializers.CharField(max_length=255)
    job_description = serializers.CharField(required=False, default="")
    difficulty_level = serializers.ChoiceField(
        choices=["beginner", "intermediate", "advanced"],
        default="intermediate",
        required=False
    )


class ProjectRecommendationInputSerializer(serializers.Serializer):
    career_goal = serializers.CharField(max_length=255)

class CoverLetterInputSerializer(serializers.Serializer):
    job_title = serializers.CharField(max_length=255)
    company_name = serializers.CharField(max_length=255)
    job_description = serializers.CharField()

