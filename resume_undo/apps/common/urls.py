from django.urls import path
from common.views import ExportReportView, UsageStatusView

urlpatterns = [
    path("export/<str:report_type>/<str:file_format>/", ExportReportView.as_view(), name="common-export"),
    path("usage-status/", UsageStatusView.as_view(), name="common-usage-status"),
]

