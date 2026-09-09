from rest_framework import serializers
from jobs.models import Job, JobRecommendation, SelectedJob

class JobSerializer(serializers.ModelSerializer):
    class Meta:
        model = Job
        fields = [
            "id",
            "jsearch_id",
            "title",
            "company_name",
            "company_logo",
            "location",
            "apply_link",
            "description",
            "raw_data",
            "created_at"
        ]

class JobRecommendationSerializer(serializers.ModelSerializer):
    job = JobSerializer(read_only=True)

    class Meta:
        model = JobRecommendation
        fields = ["id", "job", "match_score", "reasons", "created_at"]

class SelectedJobSerializer(serializers.ModelSerializer):
    job_details = JobSerializer(source="job", read_only=True)

    class Meta:
        model = SelectedJob
        fields = "__all__"
        read_only_fields = ["id", "user", "saved_at", "updated_at"]
