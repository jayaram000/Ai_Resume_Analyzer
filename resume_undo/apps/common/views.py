import io
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import permissions, status
from django.http import FileResponse
from django.utils import timezone
from common.utils import ExportService
from common.models import ExportHistory

class ExportReportView(APIView):
    permission_classes = [permissions.AllowAny]

    def get(self, request, report_type, file_format):
        if file_format not in ["pdf", "docx"]:
            return Response({"success": False, "message": "Unsupported file format."}, status=status.HTTP_400_BAD_REQUEST)

        token = request.query_params.get('token')
        user = None
        if token:
            try:
                from rest_framework_simplejwt.authentication import JWTAuthentication
                jwt_auth = JWTAuthentication()
                validated_token = jwt_auth.get_validated_token(token)
                user = jwt_auth.get_user(validated_token)
            except Exception:
                pass
                
        if not user and request.user.is_authenticated:
            user = request.user
            
        if not user:
            return Response({"detail": "Authentication credentials were not provided or invalid."}, status=401)
            
        data = {}

        try:
            if report_type == "ats_report":
                from resumes.models import Resume
                from analysis.models import ATSAnalysis
                resume_id = request.query_params.get("resume_id")
                if not resume_id:
                    resume = Resume.objects.filter(user=user).order_by("-created_at").first()
                else:
                    resume = Resume.objects.get(id=resume_id, user=user)
                
                if not resume:
                    return Response({"success": False, "message": "No resume found."}, status=status.HTTP_404_NOT_FOUND)
                
                ats_obj = resume.ats_analyses.order_by("-created_at").first()
                if not ats_obj:
                    from analysis.services import generate_ats_analysis
                    ats_obj = generate_ats_analysis(resume)
                
                data = {
                    "ats_score": ats_obj.ats_score,
                    "keyword_score": ats_obj.keyword_score,
                    "formatting_score": ats_obj.formatting_score,
                    "skills_score": ats_obj.skills_score,
                    "experience_score": ats_obj.experience_score,
                    "education_score": ats_obj.education_score,
                    "completeness_score": ats_obj.completeness_score,
                    "suggestions": ats_obj.suggestions
                }

            elif report_type == "jd_match":
                from analysis.models import JDMatchAnalysis
                jd_match_id = request.query_params.get("jd_match_id")
                if jd_match_id:
                    match_obj = JDMatchAnalysis.objects.get(id=jd_match_id, resume__user=user)
                else:
                    match_obj = JDMatchAnalysis.objects.filter(resume__user=user).order_by("-created_at").first()
                
                if not match_obj:
                    return Response({"success": False, "message": "No JD Match Analysis found."}, status=status.HTTP_404_NOT_FOUND)
                
                data = {
                    "match_score": match_obj.match_score,
                    "missing_keywords": match_obj.missing_keywords,
                    "missing_skills": match_obj.missing_skills,
                    "ats_compatibility": match_obj.ats_compatibility,
                    "recommendations": match_obj.ats_compatibility.get("issues", []) or ["Optimize resume terms based on JD."]
                }

            elif report_type == "career_report":
                from analysis.services import CareerScoreService
                score_data = CareerScoreService.calculate_score(user)
                data = {
                    "career_score": score_data["career_score"],
                    "factors": score_data["factors"],
                    "recommended_actions": CareerScoreService.get_recommended_actions(score_data["factors"])
                }

            elif report_type == "skill_gap":
                from analysis.models import SkillGapAnalysis
                target_role = request.query_params.get("target_role")
                if target_role:
                    gap_obj = SkillGapAnalysis.objects.filter(user=user, target_role=target_role).order_by("-created_at").first()
                else:
                    gap_obj = SkillGapAnalysis.objects.filter(user=user).order_by("-created_at").first()
                
                if not gap_obj:
                    return Response({"success": False, "message": "No Skill Gap analysis found."}, status=status.HTTP_404_NOT_FOUND)
                
                data = {
                    "target_role": gap_obj.target_role,
                    "missing_skills": gap_obj.missing_skills,
                    "learning_priority": gap_obj.learning_priority
                }

            elif report_type == "roadmap":
                from analysis.models import CareerRoadmap
                roadmap_id = request.query_params.get("roadmap_id")
                if roadmap_id:
                    roadmap_obj = CareerRoadmap.objects.get(id=roadmap_id, user=user)
                else:
                    roadmap_obj = CareerRoadmap.objects.filter(user=user).order_by("-created_at").first()
                
                if not roadmap_obj:
                    return Response({"success": False, "message": "No Career Roadmap found."}, status=status.HTTP_404_NOT_FOUND)
                
                data = {
                    "current_role": roadmap_obj.current_role,
                    "target_role": roadmap_obj.target_role,
                    "learning_path": roadmap_obj.learning_path,
                    "technologies": roadmap_obj.technologies,
                    "certifications": roadmap_obj.certifications,
                    "milestones": roadmap_obj.milestones
                }
            else:
                return Response({"success": False, "message": "Invalid report type."}, status=status.HTTP_400_BAD_REQUEST)

        except Exception as e:
            return Response({"success": False, "message": f"Error gathering report data: {str(e)}"}, status=status.HTTP_400_BAD_REQUEST)

        try:
            if file_format == "pdf":
                file_stream = ExportService.generate_pdf(report_type, data, user.email)
                filename = f"{report_type}_{timezone.now().strftime('%Y%m%d')}.pdf"
                content_type = "application/pdf"
            else:
                file_stream = ExportService.generate_docx(report_type, data, user.email)
                filename = f"{report_type}_{timezone.now().strftime('%Y%m%d')}.docx"
                content_type = "application/vnd.openxmlformats-officedocument.wordprocessingml.document"

            ExportHistory.objects.create(
                user=user,
                report_type=report_type,
                file_format=file_format
            )

            response = FileResponse(file_stream, content_type=content_type)
            response['Content-Disposition'] = f'attachment; filename="{filename}"'
            return response
        except Exception as e:
            return Response({"success": False, "message": f"Failed to generate document: {str(e)}"}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
