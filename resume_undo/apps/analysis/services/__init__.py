"""
Analysis domain services.
Re-exports all services and functions to maintain 100% backward compatibility.
"""
from ._common import _get_resume_text
from .ats_scoring_service import (
    ATSScoringService,
    generate_ats_analysis,
    CareerScoreService,
)
from .skills_analysis_service import (
    JDMatchingService,
    PositionAnalysisService,
    generate_position_analysis,
    generate_jd_match,
)
from .bullet_rewrite_service import (
    generate_resume_improvements,
    build_resume_markdown,
    generate_improved_resume_content,
)
from .skill_gap_service import (
    generate_skill_gap,
    AdvancedSkillGapService,
)
from .roadmap_service import (
    generate_career_roadmap,
    CareerRoadmapService,
)
from .interview_service import (
    generate_interview_prep,
    InterviewSimulationService,
)
from .cover_letter_service import (
    generate_cover_letter,
    CoverLetterService,
)
from .project_recommendation_service import (
    generate_project_recommendation,
    ProjectRecommendationService,
)

__all__ = [
    "_get_resume_text",
    "ATSScoringService",
    "generate_ats_analysis",
    "CareerScoreService",
    "JDMatchingService",
    "PositionAnalysisService",
    "generate_position_analysis",
    "generate_jd_match",
    "generate_resume_improvements",
    "build_resume_markdown",
    "generate_improved_resume_content",
    "generate_skill_gap",
    "AdvancedSkillGapService",
    "generate_career_roadmap",
    "CareerRoadmapService",
    "generate_interview_prep",
    "InterviewSimulationService",
    "generate_cover_letter",
    "CoverLetterService",
    "generate_project_recommendation",
    "ProjectRecommendationService",
]
