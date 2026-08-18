from rest_framework import serializers
from resumes.models import Resume, ResumeSection


class ResumeSectionSerializer(serializers.ModelSerializer):
    class Meta:
        model = ResumeSection
        fields = ["id", "section_type", "content", "ordinal_position"]


class ResumeDetailSerializer(serializers.ModelSerializer):
    sections = ResumeSectionSerializer(many=True, read_only=True)
    file_url = serializers.SerializerMethodField()

    class Meta:
        model = Resume
        fields = [
            "id",
            "title",
            "file_url",
            "file_type",
            "raw_text",
            "is_parsed",
            "version",
            "sections",
            "created_at",
            "updated_at",
        ]

    def get_file_url(self, obj):
        request = self.context.get("request")
        if obj.file and hasattr(obj.file, "url"):
            if request is not None:
                return request.build_absolute_uri(obj.file.url)
            return obj.file.url
        return None


class UploadResumeRequestSerializer(serializers.Serializer):
    title = serializers.CharField(max_length=255, required=False, allow_blank=True)
    file = serializers.FileField(required=True)


class UploadResumeResponseDataSerializer(serializers.Serializer):
    resume_id = serializers.UUIDField()
    id = serializers.UUIDField(required=False)
    title = serializers.CharField()
    file_type = serializers.CharField()
    file = serializers.CharField(required=False, allow_null=True)
    version = serializers.IntegerField()
    is_parsed = serializers.BooleanField()
    task_id = serializers.CharField()
    status_url = serializers.CharField()


class UploadResumeResponseSerializer(serializers.Serializer):
    status = serializers.CharField(default="success")
    message = serializers.CharField(default="File received. Ingestion job initiated.")
    data = UploadResumeResponseDataSerializer()
