from rest_framework import status, permissions
from rest_framework.response import Response
from rest_framework.views import APIView
from django.db.models import Max, Min, Avg
from resumes.models import Resume
from analysis.models import ATSAnalysis
from jobs.models import JobRecommendation, Job, SelectedJob

class DashboardStatsView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        user = request.user
        
        # 1. Total Resumes (Optimized Count)
        resumes_count = Resume.objects.filter(user=user).count()
        
        # 2. Saved Jobs Count
        saved_jobs_count = SelectedJob.objects.filter(user=user, status=SelectedJob.StatusChoices.SAVED).count()

        # 3. Recommended Jobs Count
        recommended_jobs_count = JobRecommendation.objects.filter(user=user).count()
        
        # 4. Total Jobs in Cache/Database
        total_jobs_found = Job.objects.count()
        
        # 5. Aggregate ATS Scores
        ats_aggregates = ATSAnalysis.objects.filter(
            resume__user=user
        ).aggregate(
            max_score=Max('ats_score'),
            min_score=Min('ats_score'),
            avg_score=Avg('ats_score')
        )
        
        best_score = ats_aggregates['max_score'] or 0
        lowest_score = ats_aggregates['min_score'] or 0
        career_readiness = int(ats_aggregates['avg_score'] or 0)
        
        # 6. ATS Trends
        ats_trends = []
        all_user_analyses = ATSAnalysis.objects.filter(
            resume__user=user
        ).order_by("created_at")
        
        for analysis in all_user_analyses:
            ats_trends.append({
                "date": analysis.created_at.strftime("%Y-%m-%d"),
                "score": analysis.ats_score,
                "resume_title": analysis.resume.title
            })
            
        # 7. Skill Coverage Calculation
        skill_coverage_count = 0
        latest_resume = Resume.objects.filter(user=user).order_by("-created_at").first()
        if latest_resume and hasattr(latest_resume, "parsed_content"):
            skill_coverage_count = len(latest_resume.parsed_content.extracted_skills)
            
        applied_jobs_count = SelectedJob.objects.filter(user=user, status=SelectedJob.StatusChoices.APPLIED).count()

        return Response({
            "success": True,
            "data": {
                "resume_analytics": {
                    "total_resumes": resumes_count,
                    "ats_trend": ats_trends,
                    "best_resume_score": best_score,
                    "lowest_resume_score": lowest_score
                },
                "career_analytics": {
                    "career_readiness_score": career_readiness,
                    "skill_coverage": skill_coverage_count
                },
                "job_analytics": {
                    "jobs_found": total_jobs_found,
                    "jobs_saved": saved_jobs_count,
                    "jobs_recommended": recommended_jobs_count,
                    "jobs_applied": applied_jobs_count,
                    "jobs_skipped": 0
                }
            }
        })


class CareerScoreView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        from analysis.services import CareerScoreService
        
        # Calculate current score
        current_data = CareerScoreService.calculate_score(request.user)
        
        # Get history trend points
        trend = CareerScoreService.get_trend_data(request.user)
        
        # Get recommended actions
        actions = CareerScoreService.get_recommended_actions(current_data["factors"])
        
        return Response({
            "success": True,
            "data": {
                "career_score": current_data["career_score"],
                "factors": current_data["factors"],
                "trend": trend,
                "recommended_actions": actions
            }
        })


class AdminAnalyticsView(APIView):
    permission_classes = [permissions.IsAuthenticated, permissions.IsAdminUser]

    def get(self, request):
        from django.utils import timezone
        from datetime import timedelta
        from django.contrib.auth import get_user_model
        from resumes.models import Resume
        from analysis.models import ATSAnalysis
        from jobs.models import SelectedJob
        from subscriptions.models import UserSubscription
        from django.db.models import Avg
        
        User = get_user_model()
        
        # 1. Users Metrics
        total_users = User.objects.count()
        active_cutoff = timezone.now() - timedelta(days=30)
        active_users = User.objects.filter(last_login__gte=active_cutoff).count()
        
        # Premium subscriber count
        premium_users = UserSubscription.objects.filter(
            status="active",
            end_date__gte=timezone.now()
        ).values("user").distinct().count()
        
        # 2. Resumes Metrics
        total_resumes = Resume.objects.count()
        avg_score = ATSAnalysis.objects.aggregate(avg=Avg("ats_score"))["avg"] or 0
        avg_score = round(float(avg_score), 1)
        
        # ATS distribution
        score_distribution = {
            "needs_improvement": ATSAnalysis.objects.filter(ats_score__lt=50).count(),
            "average": ATSAnalysis.objects.filter(ats_score__gte=50, ats_score__lt=70).count(),
            "good": ATSAnalysis.objects.filter(ats_score__gte=70, ats_score__lt=85).count(),
            "excellent": ATSAnalysis.objects.filter(ats_score__gte=85).count(),
        }
        
        # 3. Jobs Metrics
        total_saved_jobs = SelectedJob.objects.filter(status=SelectedJob.StatusChoices.SAVED).count()
        total_applied_jobs = SelectedJob.objects.filter(status=SelectedJob.StatusChoices.APPLIED).count()
        
        # 4. Revenue Metrics
        active_subs = UserSubscription.objects.filter(
            status="active",
            end_date__gte=timezone.now()
        )
        
        mrr = 0.0
        for sub in active_subs:
            price = float(sub.plan.price)
            days = sub.plan.duration_days or 30
            mrr += price / (days / 30.0)
            
        mrr = round(mrr, 2)
        arr = round(mrr * 12.0, 2)
        
        # 5. Subscriptions breakdown
        subs_breakdown = {
            "active": active_subs.count(),
            "expired": UserSubscription.objects.filter(status="expired").count(),
            "pending": UserSubscription.objects.filter(status="pending").count(),
            "cancelled": UserSubscription.objects.filter(status="cancelled").count(),
        }
        
        return Response({
            "success": True,
            "data": {
                "users": {
                    "total_users": total_users,
                    "active_users": active_users,
                    "premium_users": premium_users
                },
                "resumes": {
                    "total_resumes": total_resumes,
                    "average_score": avg_score,
                    "score_distribution": score_distribution
                },
                "jobs": {
                    "saved_jobs": total_saved_jobs,
                    "applied_jobs": total_applied_jobs
                },
                "revenue": {
                    "monthly_recurring_revenue": mrr,
                    "annual_run_rate": arr
                },
                "subscriptions": subs_breakdown
            }
        })
