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

    def get(self, request):
        return self._search(request, is_get=True)

    def post(self, request):
        return self._search(request, is_get=False)

    def _search(self, request, is_get=False):
        params = request.query_params if is_get else (request.data if hasattr(request, "data") and isinstance(request.data, dict) else request.query_params)
        query = params.get("query") or params.get("search") or "Software Engineer"
        location = params.get("location", "")
        if not location:
            from resumes.models import Resume
            latest_resume = Resume.objects.filter(user=request.user).order_by("-created_at").first()
            if latest_resume and hasattr(latest_resume, "parsed_content") and latest_resume.parsed_content:
                location = latest_resume.parsed_content.location or ""
        page = int(params.get("page", 1))
        
        results = JobAggregationService.search_and_rank_jobs(
            request.user, query, location or "Remote", page
        )
        
        serialized_results = []
        for res in results:
            job_data = JobSerializer(res["job"]).data
            serialized_results.append({
                **job_data,
                "job": job_data,
                "match_score": res["match_score"],
                "reasons": res["reasons"]
            })
            
        return Response({"success": True, "data": serialized_results})

class JobRecommendationView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        recs = calculate_recommendations(request.user)
        data = []
        for rec in recs:
            job_data = JobSerializer(rec.job).data
            data.append({
                **job_data,
                "id": str(rec.id),
                "job": job_data,
                "match_score": rec.match_score,
                "reasons": rec.reasons,
                "created_at": rec.created_at
            })
        return Response({"success": True, "data": data})

class SelectedJobViewSet(viewsets.ModelViewSet):
    serializer_class = SelectedJobSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        qs = SelectedJob.objects.filter(user=self.request.user).order_by("-updated_at")
        status_filter = self.request.query_params.get("status")
        if status_filter:
            qs = qs.filter(status=status_filter)
        return qs

    def create(self, request, *args, **kwargs):
        job_id = request.data.get("job_id") or request.data.get("id")
        target_status = request.data.get("status") or SelectedJob.StatusChoices.SAVED
        
        if job_id:
            try:
                job = Job.objects.filter(id=job_id).first()
                if job:
                    selected_job, created = SelectedJob.objects.get_or_create(
                        user=request.user, 
                        job=job,
                        defaults={
                            "external_job_id": job.jsearch_id,
                            "company_name": job.company_name,
                            "job_title": job.title,
                            "apply_link": job.apply_link,
                            "location": job.location,
                            "status": target_status
                        }
                    )
                    if not created and target_status:
                        selected_job.status = target_status
                        selected_job.save(update_fields=["status", "updated_at"])
                    return Response({
                        "success": True,
                        "message": f"Job marked as {selected_job.get_status_display()}.",
                        "data": SelectedJobSerializer(selected_job).data
                    }, status=status.HTTP_200_OK if not created else status.HTTP_201_CREATED)
            except Exception as e:
                pass

        # Fallback to company & title matching or creation
        company_name = request.data.get("company_name") or request.data.get("company", "Tech Company")
        job_title = request.data.get("job_title") or request.data.get("title", "Software Developer")
        apply_link = request.data.get("apply_link") or request.data.get("url", "")
        location = request.data.get("location", "Remote")
        
        selected_job, created = SelectedJob.objects.get_or_create(
            user=request.user,
            company_name=company_name,
            job_title=job_title,
            defaults={
                "apply_link": apply_link,
                "location": location,
                "status": target_status
            }
        )
        if not created and target_status:
            selected_job.status = target_status
            if apply_link:
                selected_job.apply_link = apply_link
            selected_job.save(update_fields=["status", "apply_link", "updated_at"] if apply_link else ["status", "updated_at"])
            
        return Response({
            "success": True,
            "message": f"Job saved as {selected_job.get_status_display()}.",
            "data": SelectedJobSerializer(selected_job).data
        }, status=status.HTTP_200_OK if not created else status.HTTP_201_CREATED)

    def partial_update(self, request, *args, **kwargs):
        instance = self.get_object()
        new_status = request.data.get("status")
        if new_status:
            instance.status = new_status
            instance.save(update_fields=["status", "updated_at"])
        serializer = self.get_serializer(instance)
        return Response({"success": True, "data": serializer.data})

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

            import re
            detected_resume_loc = ""
            if parsed and hasattr(parsed, "location") and parsed.location and parsed.location.lower() not in ("remote", "any", ""):
                detected_resume_loc = parsed.location.strip()
            
            raw = (resume.raw_text or "").lower()
            CITY_MAP = [
                ("trivandrum", "Trivandrum"),
                ("thiruvananthapuram", "Trivandrum"),
                ("technopark", "Trivandrum"),
                ("kochi", "Kochi"),
                ("cochin", "Kochi"),
                ("calicut", "Kochi"),
                ("kerala", "Kerala"),
                ("bengaluru", "Bengaluru"),
                ("bangalore", "Bengaluru"),
                ("hyderabad", "Hyderabad"),
                ("mumbai", "Mumbai"),
                ("chennai", "Chennai"),
                ("pune", "Pune"),
                ("delhi", "Delhi NCR"),
                ("noida", "Noida"),
                ("gurgaon", "Gurgaon"),
                ("gurugram", "Gurgaon"),
                ("london", "London"),
                ("usa", "USA"),
                ("new york", "New York"),
            ]
            for pattern, loc_label in CITY_MAP:
                if re.search(r'\b' + re.escape(pattern) + r'\b', raw):
                    detected_resume_loc = loc_label
                    break

            if not detected_resume_loc:
                detected_resume_loc = "Kochi"

            location = request.query_params.get("location")
            if not location or location.lower() in ("remote", "any", "all"):
                # If explicit location wasn't chosen by user or requested defaults, use detected resume location
                location = detected_resume_loc if not location else location

            from jobs.services import JobAggregationService
            ranked_jobs = JobAggregationService.search_and_rank_jobs(
                request.user, query=query, location=location, page=1, resume_instance=resume
            )
            
            # Serialize
            serialized_results = []
            for item in ranked_jobs: # Return all matching jobs
                job = item["job"]
                job_data = JobSerializer(job).data
                serialized_results.append({
                    **job_data,
                    "job": job_data,
                    "match_score": item.get("match_score", 85),
                    "reasons": [item.get("reasons", ["Matches your resume experience."])[0]] if isinstance(item.get("reasons"), list) else [item.get("reasons", "Matches your resume experience.")]
                })

            import urllib.parse
            q_enc = urllib.parse.quote_plus(query)
            loc_enc = urllib.parse.quote_plus(location)
            platform_search_links = {
                "linkedin": f"https://www.linkedin.com/jobs/search/?keywords={q_enc}&location={loc_enc}",
                "naukri": f"https://www.naukri.com/jobs-in-{urllib.parse.quote_plus(location.lower().replace(' ', '-'))}?kwd={q_enc}",
                "indeed": f"https://www.indeed.com/jobs?q={q_enc}&l={loc_enc}",
                "foundit": f"https://www.foundit.in/srp/results?query={q_enc}&locations={loc_enc}",
                "google": f"https://www.google.com/search?q={urllib.parse.quote_plus(f'{query} jobs in {location}')}&ibp=htl;jobs"
            }

            return Response({
                "success": True, 
                "detected_location": detected_resume_loc,
                "searched_location": location,
                "detected_role": query,
                "platform_search_links": platform_search_links,
                "data": serialized_results
            })
        except Exception as e:
            return Response({"success": False, "message": str(e)}, status=400)


class JobPreferenceView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        from accounts.models import UserProfile
        profile, _ = UserProfile.objects.get_or_create(user=request.user)
        prefs = profile.preferences or {}
        view_mode = prefs.get("jobs_view_mode", "kanban")
        return Response({"success": True, "view_mode": view_mode, "preferences": prefs})

    def post(self, request):
        from accounts.models import UserProfile
        profile, _ = UserProfile.objects.get_or_create(user=request.user)
        view_mode = request.data.get("view_mode") or request.data.get("jobs_view_mode", "kanban")
        prefs = dict(profile.preferences or {})
        prefs["jobs_view_mode"] = view_mode
        profile.preferences = prefs
        profile.save(update_fields=["preferences"])
        return Response({"success": True, "view_mode": view_mode, "preferences": prefs})

