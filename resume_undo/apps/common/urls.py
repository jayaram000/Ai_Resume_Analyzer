from django.urls import path
from common.views import ExportReportView

urlpatterns = [
    path("export/<str:report_type>/<str:file_format>/", ExportReportView.as_view(), name="common-export"),
]
