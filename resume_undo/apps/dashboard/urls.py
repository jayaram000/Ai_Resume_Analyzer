from django.urls import path
from dashboard.views import DashboardStatsView, CareerScoreView, AdminAnalyticsView

urlpatterns = [
    path("stats/", DashboardStatsView.as_view(), name="dashboard-stats"),
    path("career-score/", CareerScoreView.as_view(), name="career-score"),
    path("admin/analytics/", AdminAnalyticsView.as_view(), name="admin-analytics"),
]
