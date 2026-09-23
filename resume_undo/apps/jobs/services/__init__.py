"""
Jobs domain services.
Re-exports all services, clients, and helpers to maintain 100% backward compatibility.
"""
from .jsearch_client import (
    REGIONAL_MARKET_COMPANIES,
    generate_platform_links,
    fetch_jobs_from_jsearch,
)
from .salary_normalization_service import SalaryNormalizationService
from .application_tracker_service import ApplicationTrackerService
from .job_ranking_service import (
    is_relevant_tech_job,
    is_geo_compatible,
    JobAggregationService,
    calculate_recommendations,
)

__all__ = [
    "REGIONAL_MARKET_COMPANIES",
    "generate_platform_links",
    "fetch_jobs_from_jsearch",
    "SalaryNormalizationService",
    "ApplicationTrackerService",
    "is_relevant_tech_job",
    "is_geo_compatible",
    "JobAggregationService",
    "calculate_recommendations",
]
