from rest_framework import viewsets, status, permissions
from rest_framework.response import Response
from rest_framework.views import APIView
from django.db.models import Count
from common.permissions import IsPremiumUser
from jobs.models import Job, JobRecommendation, SelectedJob
from jobs.serializers import JobSerializer, JobRecommendationSerializer, SelectedJobSerializer
from jobs.services import JobAggregationService, calculate_recommendations

class JobSearchView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        query = request.data.get("query", "Software Engineer")
        location = request.data.get("location", "")
        if not location:
            from resumes.models import Resume
            latest_resume = Resume.objects.filter(user=request.user).order_by("-created_at").first()
            if latest_resume and hasattr(latest_resume, "parsed_content") and latest_resume.parsed_content:
                location = latest_resume.parsed_content.location or ""
        page = int(request.data.get("page", 1))
        experience_level = request.data.get("experience_level", "")
        experience_years = request.data.get("experience_years", "")
        
        results = JobAggregationService.search_and_rank_jobs(
            request.user, query, location, page, experience_level, experience_years
        )
        
        # Serialize jobs within results
        serialized_results = []
        for res in results:
            serialized_results.append({
                "job": JobSerializer(res["job"]).data,
                "match_score": res["match_score"],
                "reasons": res["reasons"]
            })
            
        return Response({"success": True, "data": serialized_results})

class JobRecommendationView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        recs = calculate_recommendations(request.user)
        serializer = JobRecommendationSerializer(recs, many=True)
        return Response({"success": True, "data": serializer.data})

class SelectedJobViewSet(viewsets.ModelViewSet):
    serializer_class = SelectedJobSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return SelectedJob.objects.filter(user=self.request.user).order_by("-updated_at")

    def create(self, request, *args, **kwargs):
        job_id = request.data.get("job_id")
        
        if job_id:
            try:
                job = Job.objects.get(id=job_id)
                selected_job, created = SelectedJob.objects.get_or_create(
                    user=request.user, 
                    job=job,
                    defaults={
                        "external_job_id": job.jsearch_id,
                        "company_name": job.company_name,
                        "job_title": job.title,
                        "apply_link": job.apply_link,
                        "location": job.location,
                        "status": SelectedJob.StatusChoices.SAVED
                    }
                )
                return Response({
                    "success": True,
                    "message": "Job selected successfully.",
                    "data": SelectedJobSerializer(selected_job).data
                }, status=status.HTTP_201_CREATED)
            except Job.DoesNotExist:
                return Response({"success": False, "message": "Job not found."}, status=404)
        else:
            # Create a custom job directly
            serializer = self.get_serializer(data=request.data)
            serializer.is_valid(raise_exception=True)
            serializer.save(user=request.user)
            return Response({
                "success": True,
                "message": "Custom job added.",
                "data": serializer.data
            }, status=status.HTTP_201_CREATED)

    def destroy(self, request, pk=None, *args, **kwargs):
        try:
            from django.db.models import Q
            selected_job = SelectedJob.objects.filter(user=request.user).filter(Q(id=pk) | Q(job_id=pk))
            if selected_job.exists():
                selected_job.delete()
                return Response({"success": True, "message": "Job removed successfully."})
            return Response({"success": False, "message": "Selected job entry not found."}, status=404)
        except Exception as e:
            return Response({"success": False, "message": str(e)}, status=400)


class JobStatsView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        stats = SelectedJob.objects.filter(user=request.user).values("status").annotate(count=Count("status"))
        
        result = {
            "SAVED": 0,
            "NOT_APPLIED": 0,
            "APPLIED": 0,
            "INTERVIEW_CALL_RECEIVED": 0,
            "REJECTED": 0,
            "OFFER_RECEIVED": 0,
            "TOTAL": 0
        }
        
        for stat in stats:
            status_code = stat["status"]
            result[status_code] = stat["count"]
            result["TOTAL"] += stat["count"]
            
        return Response({"success": True, "data": result})

class ResumeMatchJobView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, resume_id):
        from resumes.models import Resume
        try:
            resume = Resume.objects.get(id=resume_id, user=request.user)
            parsed = getattr(resume, "parsed_content", None)
            
            query = ""
            if parsed:
                if parsed.extracted_experience and isinstance(parsed.extracted_experience, list) and len(parsed.extracted_experience) > 0:
                    exp0 = parsed.extracted_experience[0]
                    query = exp0.get("role") or exp0.get("title", "")
                
                if not query:
                    skills = parsed.extracted_skills if isinstance(parsed.extracted_skills, list) else []
                    if skills:
                        query = " ".join(skills[:2])
            
            if not query:
                query = "Software Developer"

            location = parsed.location if parsed and hasattr(parsed, "location") else ""

            from jobs.services import JobAggregationService
            ranked_jobs = JobAggregationService.search_and_rank_jobs(request.user, query=query, location=location, page=1)
            
            # Serialize
            serialized_results = []
            for item in ranked_jobs[:10]: # Return top 10 matches
                job = item["job"]
                serialized_results.append({
                    "job": JobSerializer(job).data,
                    "match_score": item.get("match_score", 0),
                    "reasons": [item.get("reasons", ["Matches your resume experience."])[0]] if isinstance(item.get("reasons"), list) else [item.get("reasons", "Matches your resume experience.")]
                })
            return Response({"success": True, "data": serialized_results})
        except Exception as e:
            return Response({"success": False, "message": str(e)}, status=400)

