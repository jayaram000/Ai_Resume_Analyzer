from abc import ABC, abstractmethod
from typing import Optional, List
from resumes.models import Resume


class BaseResumeRepository(ABC):
    """
    Abstract Repository Interface for Resume domain entity per Clean Architecture.
    """

    @abstractmethod
    def create_resume(self, user, title: str, file_obj, file_type: str, version: int) -> Resume:
        pass

    @abstractmethod
    def get_by_id(self, resume_id: str, user) -> Optional[Resume]:
        pass

    @abstractmethod
    def list_by_user(self, user) -> List[Resume]:
        pass

    @abstractmethod
    def get_existing_versions_count(self, user, title: str) -> int:
        pass

    @abstractmethod
    def delete_resume(self, resume_id: str, user) -> bool:
        pass
