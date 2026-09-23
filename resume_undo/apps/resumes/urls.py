from django.urls import path, include
from rest_framework.routers import DefaultRouter
from resumes.views import ResumeViewSet

router = DefaultRouter()
router.register(r"", ResumeViewSet, basename="resume")

urlpatterns = [
    path("compare/", ResumeViewSet.as_view({"post": "compare"}), name="resume-compare"),
    path("", include(router.urls)),
]
