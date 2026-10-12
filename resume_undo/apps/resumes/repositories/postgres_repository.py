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
            
            # If all resumes for this user are now deleted, wipe all residual analysis records
            if Resume.objects.filter(user=user).count() == 0:
                self.cleanup_all_user_analysis(user)
                
            return True
        return False

    def delete_all_resumes(self, user) -> int:
        resumes = Resume.objects.filter(user=user)
        count = resumes.count()
        for r in resumes:
            if r.file:
                try:
                    r.file.delete(save=False)
                except Exception as e:
                    logger.warning(f"Failed to delete file for resume {r.id}: {e}")
        resumes.delete()
        self.cleanup_all_user_analysis(user)
        logger.info(f"Deleted all {count} resumes and purged analyses for user {user.email}")
        return count

    def cleanup_all_user_analysis(self, user) -> None:
        """
        Clears all residual user-level analyses and snapshots when no resumes exist.
        """
        try:
            from analysis.models import (
                SkillGapAnalysis,
                CareerRoadmap,
                CareerReadinessSnapshot,
            )
            from jobs.models import JobRecommendation
            from common.models import ExportHistory

            SkillGapAnalysis.objects.filter(user=user).delete()
            CareerRoadmap.objects.filter(user=user).delete()
            CareerReadinessSnapshot.objects.filter(user=user).delete()
            JobRecommendation.objects.filter(user=user).delete()
            ExportHistory.objects.filter(user=user).delete()
            logger.info(f"Cleaned up all analysis records and recommendations for user {user.email}")
        except Exception as e:
            logger.error(f"Error cleaning up user analyses for {user.email}: {e}", exc_info=True)
