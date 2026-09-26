import logging
from rest_framework import viewsets, status, permissions
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.parsers import MultiPartParser, FormParser, JSONParser
from django.core.exceptions import ValidationError
from drf_spectacular.utils import extend_schema

from resumes.models import Resume
from resumes.services import ResumeComparisonService
from common.permissions import HasUsageQuota
from common.usage_limiter import consume_usage
from resumes.serializers import (
    ResumeDetailSerializer,
    UploadResumeRequestSerializer,
    UploadResumeResponseSerializer,
)
from resumes.use_cases.upload_resume import UploadResumeUseCase
from resumes.repositories.postgres_repository import PostgresResumeRepository

logger = logging.getLogger(__name__)


class ResumeViewSet(viewsets.ModelViewSet):
    """
    Production ViewSet for Resume Upload and Management per SAD Section 8 & 10.
    """
    permission_classes = [permissions.IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser, JSONParser]
    serializer_class = ResumeDetailSerializer

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.resume_repo = PostgresResumeRepository()
        self.upload_use_case = UploadResumeUseCase(self.resume_repo)

    def get_queryset(self):
        return self.resume_repo.list_by_user(self.request.user)

    def get_permissions(self):
        if self.action in ['create', 'compare']:
            return [permissions.IsAuthenticated(), HasUsageQuota()]
        return [permissions.IsAuthenticated()]

    @extend_schema(
        summary="Upload Resume Document",
        description="Uploads a PDF or DOCX resume document for background parsing and section detection per SAD Section 10.",
        request=UploadResumeRequestSerializer,
        responses={
            202: UploadResumeResponseSerializer,
            400: "Invalid File or Size Limit Exceeded",
            401: "Unauthorized Access Token",
        },
    )
    def create(self, request, *args, **kwargs):
        request_serializer = UploadResumeRequestSerializer(data=request.data)
        if not request_serializer.is_valid():
            return Response(
                {"status": "error", "errors": request_serializer.errors},
                status=status.HTTP_400_BAD_REQUEST,
            )

        uploaded_file = request_serializer.validated_data["file"]
        custom_title = request_serializer.validated_data.get("title")

        try:
            result_data = self.upload_use_case.execute(
                user=request.user,
                uploaded_file=uploaded_file,
                custom_title=custom_title,
            )

            _, remaining, reset_at = consume_usage(request.user, "ats_scan")

            response_serializer = UploadResumeResponseSerializer({
                "status": "success",
                "message": "File received. Ingestion job initiated.",
                "data": result_data,
            })

            resp_data = dict(response_serializer.data)
            resp_data["usage_remaining"] = remaining
            resp_data["reset_at"] = reset_at

            return Response(resp_data, status=status.HTTP_202_ACCEPTED)

        except ValidationError as val_err:
            logger.warning(f"Validation error during resume upload for user {request.user.id}: {val_err.message}")
            return Response(
                {"status": "error", "message": val_err.message},
                status=status.HTTP_400_BAD_REQUEST,
            )
        except Exception as e:
            logger.error(f"Unexpected error during resume upload: {str(e)}", exc_info=True)
            return Response(
                {"status": "error", "message": "An unexpected error occurred while processing the file."},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )

    @extend_schema(
        summary="Retrieve Resume Detail",
        description="Returns detailed resume entity including raw text and detected sections.",
        responses={200: ResumeDetailSerializer, 404: "Resume Not Found"},
    )
    def retrieve(self, request, pk=None, *args, **kwargs):
        resume = self.resume_repo.get_by_id(pk, request.user)
        if not resume:
            return Response(
                {"status": "error", "message": "Resume not found."},
                status=status.HTTP_404_NOT_FOUND,
            )
        serializer = self.get_serializer(resume)
        return Response({"status": "success", "data": serializer.data}, status=status.HTTP_200_OK)

    @extend_schema(
        summary="Delete Resume Document",
        description="Deletes a resume and its associated sections from the database and storage.",
        responses={204: "No Content", 404: "Resume Not Found"},
    )
    def destroy(self, request, pk=None, *args, **kwargs):
        deleted = self.resume_repo.delete_resume(pk, request.user)
        if not deleted:
            return Response(
                {"status": "error", "message": "Resume not found or access denied."},
                status=status.HTTP_404_NOT_FOUND,
            )
        return Response(status=status.HTTP_204_NO_CONTENT)

    @extend_schema(
        summary="Compare Two Resume Dossiers",
        description="Audits diffs between two resumes, computing ATS metrics and skill/keyword adjustments.",
        responses={200: "Comparison Result", 400: "Bad Request", 404: "Not Found"},
    )
    @action(detail=False, methods=["post"], url_path="compare", permission_classes=[permissions.IsAuthenticated, HasUsageQuota])
    def compare(self, request, *args, **kwargs):
        before_id = request.data.get("before_resume_id")
        after_id = request.data.get("after_resume_id")

        if not before_id or not after_id:
            return Response(
                {"success": False, "message": "Both before_resume_id and after_resume_id are required."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            resume_old = Resume.objects.get(id=before_id, user=request.user)
            resume_new = Resume.objects.get(id=after_id, user=request.user)
        except (Resume.DoesNotExist, ValueError):
            return Response(
                {"success": False, "message": "One or both resumes could not be found or access denied."},
                status=status.HTTP_404_NOT_FOUND,
            )

        try:
            comparison_result = ResumeComparisonService.compare_resumes(resume_old, resume_new)
            _, remaining, reset_at = consume_usage(request.user, "resume_comparison")
            return Response({
                "success": True, 
                "data": comparison_result,
                "usage_remaining": remaining,
                "reset_at": reset_at,
            }, status=status.HTTP_200_OK)
        except Exception as e:
            logger.error(f"Resume comparison error: {e}", exc_info=True)
            return Response(
                {"success": False, "message": f"Comparison failed: {str(e)}"},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )
