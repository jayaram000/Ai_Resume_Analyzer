from django.urls import path
from analysis.views import (
    ATSAnalysisView,
    ResumeImprovementView,
    PositionAnalysisView,
    JDMatchAnalysisView,
    SkillGapAnalysisView,
    CareerRoadmapView,
    InterviewPreparationView,
    ProjectRecommendationView,
    CoverLetterView,
    AutoTailorResumeView,
    DownloadImprovedResumeView,
    ResumeImprovementContentView
)
from analysis import views

urlpatterns = [
    path("ats/<uuid:resume_id>/", ATSAnalysisView.as_view(), name="analysis-ats"),
    path("improve/<uuid:resume_id>/", ResumeImprovementView.as_view(), name="analysis-improve"),
    path("improve/<uuid:resume_id>/content/", ResumeImprovementContentView.as_view(), name="analysis-improve-content"),
    path("improve/<uuid:resume_id>/download/", DownloadImprovedResumeView.as_view(), name="analysis-improve-download"),
    path("match-position/<uuid:resume_id>/", PositionAnalysisView.as_view(), name="analysis-match-position"),
    path("match-jd/<uuid:resume_id>/", JDMatchAnalysisView.as_view(), name="analysis-match-jd"),
    path("skill-gap/", SkillGapAnalysisView.as_view(), name="analysis-skill-gap"),
    path("skill-gap/<uuid:pk>/", views.SkillGapDetailView.as_view(), name="analysis-skill-gap-detail"),
    path('skill-gap/<uuid:pk>/pdf/', views.DownloadSkillGapPDFView.as_view(), name='skill-gap-pdf'),
    path("roadmap/", CareerRoadmapView.as_view(), name="analysis-roadmap"),
    path("roadmap/<uuid:pk>/", views.CareerRoadmapDetailView.as_view(), name="analysis-roadmap-detail"),
    path("roadmap/<uuid:pk>/pdf/", views.DownloadCareerRoadmapPDFView.as_view(), name="roadmap-pdf"),
    path("interview/<uuid:resume_id>/", InterviewPreparationView.as_view(), name="analysis-interview"),
    path("project/<uuid:resume_id>/", ProjectRecommendationView.as_view(), name="analysis-project"),
    path("cover-letter/<uuid:resume_id>/", CoverLetterView.as_view(), name="analysis-cover-letter"),
    path("auto-tailor/<uuid:resume_id>/", AutoTailorResumeView.as_view(), name="analysis-auto-tailor"),
]
