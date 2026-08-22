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
    class Meta:
        model = JDMatchAnalysis
        fields = "__all__"

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
    class Meta:
        model = CareerRoadmap
        fields = "__all__"

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
    current_role = serializers.CharField(max_length=255, required=False, default="Software Developer", allow_blank=True)
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

