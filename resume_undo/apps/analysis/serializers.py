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
    class Meta:
        model = SkillGapAnalysis
        fields = "__all__"

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
    experience = serializers.CharField(max_length=50, default="Mid-Level")
    resume_id = serializers.IntegerField(required=False, allow_null=True)

class CareerRoadmapInputSerializer(serializers.Serializer):
    current_role = serializers.CharField(max_length=255)
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

