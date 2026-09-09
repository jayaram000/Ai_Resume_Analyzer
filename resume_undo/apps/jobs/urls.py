from django.urls import path, include
from rest_framework.routers import SimpleRouter
from jobs.views import JobSearchView, JobRecommendationView, SelectedJobViewSet, JobStatsView, ResumeMatchJobView, JobPreferenceView

router = SimpleRouter()
router.register(r"selected", SelectedJobViewSet, basename="selected-jobs")
router.register(r"saved", SelectedJobViewSet, basename="saved-jobs")

urlpatterns = [
    path("search/", JobSearchView.as_view(), name="jobs-search"),
    path("recommendations/", JobRecommendationView.as_view(), name="jobs-recommendations"),
    path("stats/", JobStatsView.as_view(), name="jobs-stats"),
    path("preferences/", JobPreferenceView.as_view(), name="jobs-preferences"),
    path("resume-matches/<uuid:resume_id>/", ResumeMatchJobView.as_view(), name="resume-matches"),
    path("", include(router.urls)),
]

