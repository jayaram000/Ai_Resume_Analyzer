from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static
from drf_spectacular.views import (
    SpectacularAPIView,
    SpectacularSwaggerView,
)

urlpatterns = [
    path("admin/", admin.site.urls),

    # App APIs (v1 API Prefix per SAD Section 10)
    path("api/v1/resumes/", include("resumes.urls")),
    path("api/auth/", include("accounts.urls")),
    path("api/subscriptions/", include("subscriptions.urls")),
    path("api/resumes/", include("resumes.urls")),
    path("api/analysis/", include("analysis.urls")),
    path("api/jobs/", include("jobs.urls")),
    path("api/dashboard/", include("dashboard.urls")),
    path("api/common/", include("common.urls")),

    path(
        "api/schema/",
        SpectacularAPIView.as_view(),
        name="schema",
    ),

    path(
        "api/docs/",
        SpectacularSwaggerView.as_view(
            url_name="schema"
        ),
        name="swagger-ui",
    ),
]

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)