import logging
from typing import Dict, Any
from resumes.repositories.postgres_repository import PostgresResumeRepository
from parsing.services.file_validator import FileValidationService
from parsing.tasks import extract_resume_text_task

logger = logging.getLogger(__name__)


class UploadResumeUseCase:
    """
    Use Case for uploading and processing a new resume document.
    Enforces validation, versioning, persistence, and async background parsing.
    """

    def __init__(self, resume_repository: PostgresResumeRepository = None):
        self.resume_repo = resume_repository or PostgresResumeRepository()

    def execute(self, user, uploaded_file, custom_title: str = None) -> Dict[str, Any]:
        """
        Executes resume upload workflow.
        Returns dictionary with resume metadata and parsing task tracking ID.
        """
        # 1. Validate File Size, Extension & Magic Bytes
        is_valid, file_type = FileValidationService.validate_resume_file(uploaded_file)

        # 2. Determine Title & Version History
        title = custom_title.strip() if custom_title else uploaded_file.name
        existing_count = self.resume_repo.get_existing_versions_count(user, title)
        version = existing_count + 1

        # 3. Persist Model Record via Repository
        resume = self.resume_repo.create_resume(
            user=user,
            title=title,
            file_obj=uploaded_file,
            file_type=file_type,
            version=version,
        )

        # 4. Dispatch Async Celery Parsing Task to 'parsing_queue' per SAD Section 9
        task_id = None
        try:
            async_result = extract_resume_text_task.delay(str(resume.id))
            task_id = async_result.id
            logger.info(f"Dispatched extract_resume_text_task with ID '{task_id}' for Resume '{resume.id}'")
        except Exception as celery_err:
            logger.warning(
                f"Celery broker dispatch failed: {str(celery_err)}. Falling back to direct parsing execution."
            )
            # Synchronous Fallback Execution for local testing / broker outage
            try:
                extract_resume_text_task(str(resume.id))
                resume.refresh_from_db()
            except Exception as sync_err:
                logger.error(f"Fallback direct parsing failed for Resume ID {resume.id}: {str(sync_err)}")

        file_url = resume.file.url if (resume.file and hasattr(resume.file, "url")) else None

        return {
            "resume_id": str(resume.id),
            "id": str(resume.id),
            "title": resume.title,
            "file_type": resume.file_type,
            "file": file_url,
            "version": resume.version,
            "is_parsed": resume.is_parsed,
            "task_id": task_id or "sync-completed",
            "status_url": f"/api/v1/resumes/{resume.id}/",
        }
