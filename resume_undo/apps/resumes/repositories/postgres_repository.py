import logging
from typing import Optional, List
from resumes.domain.interfaces import BaseResumeRepository
from resumes.models import Resume

logger = logging.getLogger(__name__)


class PostgresResumeRepository(BaseResumeRepository):
    """
    Concrete PostgreSQL repository implementation for Resume entity.
    """

    def create_resume(self, user, title: str, file_obj, file_type: str, version: int) -> Resume:
        logger.info(f"Creating Resume record for user {user.email} (Title: '{title}', v{version})")
        return Resume.objects.create(
            user=user,
            title=title,
            file=file_obj,
            file_type=file_type,
            version=version,
        )

    def get_by_id(self, resume_id: str, user) -> Optional[Resume]:
        try:
            return Resume.objects.prefetch_related("sections").get(id=resume_id, user=user)
        except Resume.DoesNotExist:
            logger.warning(f"Resume ID {resume_id} not found for user {user.email}")
            return None

    def list_by_user(self, user) -> List[Resume]:
        return list(Resume.objects.filter(user=user).prefetch_related("sections").order_by("-created_at"))

    def get_existing_versions_count(self, user, title: str) -> int:
        return Resume.objects.filter(user=user, title=title).count()

    def delete_resume(self, resume_id: str, user) -> bool:
        resume = self.get_by_id(resume_id, user)
        if resume:
            resume.file.delete(save=False)
            resume.delete()
            logger.info(f"Deleted Resume ID {resume_id} for user {user.email}")
            return True
        return False
