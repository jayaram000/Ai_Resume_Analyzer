from rest_framework import status, permissions
from rest_framework.response import Response
from rest_framework.views import APIView
from drf_spectacular.utils import extend_schema
from resumes.models import Resume
from common.permissions import IsPremiumUser
from analysis.serializers import (
    ATSAnalysisSerializer,
    ResumeImprovementSerializer,
    PositionAnalysisSerializer,
    JDMatchAnalysisSerializer,
    SkillGapAnalysisSerializer,
    CareerRoadmapSerializer,
    InterviewPreparationSerializer,
    ProjectRecommendationSerializer,
    CoverLetterSerializer,
    PositionAnalysisInputSerializer,
    JDMatchInputSerializer,
    SkillGapInputSerializer,
    CareerRoadmapInputSerializer,
    InterviewPrepInputSerializer,
    ProjectRecommendationInputSerializer,
    CoverLetterInputSerializer
)
from analysis.services import (
    generate_ats_analysis,
    generate_resume_improvements,
    generate_position_analysis,
    generate_jd_match,
    generate_skill_gap,
    generate_career_roadmap,
    generate_interview_prep,
    generate_project_recommendation,
    generate_cover_letter,
    AdvancedSkillGapService,
    CareerRoadmapService,
    InterviewSimulationService,
    CoverLetterService,
    ProjectRecommendationService,
    JDMatchingService
)


class BaseAnalysisView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get_resume(self, resume_id, user):
        try:
            return Resume.objects.get(id=resume_id, user=user)
        except Resume.DoesNotExist:
            return None

# --- Normal User Features ---

class ATSAnalysisView(BaseAnalysisView):
    @extend_schema(request=None, responses=ATSAnalysisSerializer)
    def get(self, request, resume_id):
        resume = self.get_resume(resume_id, request.user)
        if not resume:
            return Response({"success": False, "message": "Resume not found."}, status=404)
        from analysis.models import ATSAnalysis
        analysis = ATSAnalysis.objects.filter(resume=resume).order_by("-created_at").first()
        if not analysis or analysis.ats_score <= 15:
            from resumes.services import parse_and_save_resume
            if not hasattr(resume, "parsed_content") or resume.parsed_content is None:
                try:
                    parse_and_save_resume(resume)
                    resume.refresh_from_db()
                except Exception:
                    pass
            analysis = generate_ats_analysis(resume)
        return Response({"success": True, "data": ATSAnalysisSerializer(analysis).data})

    @extend_schema(request=None, responses=ATSAnalysisSerializer)
    def post(self, request, resume_id):
        resume = self.get_resume(resume_id, request.user)
        if not resume:
            return Response({"success": False, "message": "Resume not found."}, status=404)
        analysis = generate_ats_analysis(resume)
        return Response({"success": True, "data": ATSAnalysisSerializer(analysis).data})

class ResumeImprovementView(BaseAnalysisView):
    @extend_schema(request=None, responses=ResumeImprovementSerializer)
    def get(self, request, resume_id):
        resume = self.get_resume(resume_id, request.user)
        if not resume:
            return Response({"success": False, "message": "Resume not found."}, status=404)
        from analysis.models import ResumeImprovement
        
        force_refresh = request.query_params.get('refresh', 'false').lower() == 'true'
        improvement = ResumeImprovement.objects.filter(resume=resume).order_by("-created_at").first()
        if force_refresh or not improvement or not improvement.strengths or "fallback" in str(improvement.strengths).lower() or not improvement.better_bullet_points:
            improvement = generate_resume_improvements(resume)
        return Response({"success": True, "data": ResumeImprovementSerializer(improvement).data})

    @extend_schema(request=None, responses=ResumeImprovementSerializer)
    def post(self, request, resume_id):
        resume = self.get_resume(resume_id, request.user)
        if not resume:
            return Response({"success": False, "message": "Resume not found."}, status=404)
        improvement = generate_resume_improvements(resume)
        return Response({"success": True, "data": ResumeImprovementSerializer(improvement).data})

class DownloadImprovedResumeView(BaseAnalysisView):
    permission_classes = [permissions.AllowAny]

    def _authenticate_user(self, request):
        """Authenticate user from JWT token query param or session."""
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
        return user

    def get(self, request, resume_id):
        user = self._authenticate_user(request)
        if not user:
            return Response({"detail": "Authentication credentials were not provided or invalid."}, status=401)

        resume = self.get_resume(resume_id, user)
        if not resume:
            return Response({"success": False, "message": "Resume not found."}, status=404)
            
        template_style = request.query_params.get('template', 'classic').lower()
        if template_style not in ['classic', 'modern', 'minimalist']:
            template_style = 'classic'

        download_type = request.query_params.get('type', 'diff_improved').lower()

        from analysis.services import build_resume_markdown
        from analysis.models import ResumeImprovement
        from analysis.pdf_generator import generate_resume_pdf
        from django.http import HttpResponse

        improvement = ResumeImprovement.objects.filter(resume=resume).order_by("-created_at").first()

        if download_type == 'jd_tailored':
            # Use JD tailored content if available, otherwise fallback to parsed original
            if improvement and improvement.jd_tailored_content and len(improvement.jd_tailored_content.strip()) > 50:
                markdown_content = improvement.jd_tailored_content
            elif improvement and improvement.tailored_content and len(improvement.tailored_content.strip()) > 50:
                markdown_content = improvement.tailored_content
            else:
                markdown_content = build_resume_markdown(resume)
            filename = f"tailored_resume_{resume.id}.pdf"
        else:
            # diff_improved: Use original resume with ONLY the accepted diff improvements applied
            if improvement and improvement.tailored_content and len(improvement.tailored_content.strip()) > 50:
                markdown_content = improvement.tailored_content
            else:
                markdown_content = build_resume_markdown(resume)
            filename = f"improved_resume_{resume.id}.pdf"

        pdf_buffer = generate_resume_pdf(markdown_content, template_style=template_style)
        
        response = HttpResponse(pdf_buffer.getvalue(), content_type='application/pdf')
        response['Content-Disposition'] = f'attachment; filename="{filename}"'
        return response

    def post(self, request, resume_id):
        """Accept user-provided markdown content (auto-tailored/edited) and generate PDF from it."""
        user = self._authenticate_user(request)
        if not user:
            return Response({"detail": "Authentication credentials were not provided or invalid."}, status=401)

        resume = self.get_resume(resume_id, user)
        if not resume:
            return Response({"success": False, "message": "Resume not found."}, status=404)
            
        template_style = request.data.get('template', 'classic').lower()
        if template_style not in ['classic', 'modern', 'minimalist']:
            template_style = 'classic'

        download_type = request.data.get('type', 'diff_improved').lower()

        markdown_content = request.data.get('markdown_content', '').strip()
        if not markdown_content or len(markdown_content) < 50:
            from analysis.services import build_resume_markdown
            from analysis.models import ResumeImprovement
            improvement = ResumeImprovement.objects.filter(resume=resume).order_by("-created_at").first()
            if download_type == 'jd_tailored' and improvement and improvement.jd_tailored_content:
                markdown_content = improvement.jd_tailored_content
            elif improvement and improvement.tailored_content:
                markdown_content = improvement.tailored_content
            else:
                markdown_content = build_resume_markdown(resume)

        from analysis.pdf_generator import generate_resume_pdf
        from django.http import HttpResponse
        
        pdf_buffer = generate_resume_pdf(markdown_content, template_style=template_style)
        
        response = HttpResponse(pdf_buffer.getvalue(), content_type='application/pdf')
        filename = f"{'tailored' if download_type == 'jd_tailored' else 'improved'}_resume_{resume.id}.pdf"
        response['Content-Disposition'] = f'attachment; filename="{filename}"'
        return response

class ResumeImprovementContentView(BaseAnalysisView):
    def get(self, request, resume_id):
        resume = self.get_resume(resume_id, request.user)
        if not resume:
            return Response({"success": False, "message": "Resume not found."}, status=404)
        
        content_type = request.query_params.get('type', 'diff_improved').lower()
        force_refresh = request.query_params.get('refresh', 'false').lower() == 'true'
        
        from analysis.models import ResumeImprovement
        from analysis.services import build_resume_markdown
        
        improvement = ResumeImprovement.objects.filter(resume=resume).order_by("-created_at").first()
        
        if content_type == 'jd_tailored':
            content = improvement.jd_tailored_content if (improvement and improvement.jd_tailored_content) else ""
        else:
            if force_refresh or not improvement or not improvement.tailored_content:
                content = build_resume_markdown(resume)
                if improvement:
                    improvement.tailored_content = content
                    improvement.save(update_fields=['tailored_content'])
            else:
                content = improvement.tailored_content
                
        return Response({"success": True, "data": {"content": content}})
        
    def put(self, request, resume_id):
        resume = self.get_resume(resume_id, request.user)
        if not resume:
            return Response({"success": False, "message": "Resume not found."}, status=404)
            
        new_content = request.data.get("content")
        content_type = request.data.get("type", "diff_improved").lower()
        
        if not new_content:
            return Response({"success": False, "message": "Content is required."}, status=400)
            
        from analysis.models import ResumeImprovement
        improvement = ResumeImprovement.objects.filter(resume=resume).order_by("-created_at").first()
        if not improvement:
            improvement = ResumeImprovement.objects.create(
                resume=resume,
                tailored_content=new_content if content_type != 'jd_tailored' else '',
                jd_tailored_content=new_content if content_type == 'jd_tailored' else ''
            )
        else:
            if content_type == 'jd_tailored':
                improvement.jd_tailored_content = new_content
                improvement.save(update_fields=['jd_tailored_content'])
            else:
                improvement.tailored_content = new_content
                improvement.save(update_fields=['tailored_content'])
            
        return Response({"success": True, "message": "Content saved successfully."})

class PositionAnalysisView(BaseAnalysisView):
    @extend_schema(request=PositionAnalysisInputSerializer, responses=PositionAnalysisSerializer)
    def post(self, request, resume_id):
        resume = self.get_resume(resume_id, request.user)
        if not resume:
            return Response({"success": False, "message": "Resume not found."}, status=404)
            
        serializer = PositionAnalysisInputSerializer(data=request.data)
        if serializer.is_valid():
            analysis = generate_position_analysis(
                resume, 
                serializer.validated_data["target_position"]
            )
            return Response({"success": True, "data": PositionAnalysisSerializer(analysis).data})
        return Response(serializer.errors, status=400)

class JDMatchAnalysisView(BaseAnalysisView):
    @extend_schema(request=JDMatchInputSerializer, responses=JDMatchAnalysisSerializer)
    def post(self, request, resume_id):
        resume = self.get_resume(resume_id, request.user)
        if not resume:
            return Response({"success": False, "message": "Resume not found."}, status=404)
            
        serializer = JDMatchInputSerializer(data=request.data)
        if serializer.is_valid():
            analysis = generate_jd_match(
                resume, 
                serializer.validated_data["job_description"]
            )
            return Response({"success": True, "data": JDMatchAnalysisSerializer(analysis).data})
        return Response(serializer.errors, status=400)

class AutoTailorResumeView(BaseAnalysisView):
    def post(self, request, resume_id):
        resume = self.get_resume(resume_id, request.user)
        if not resume:
            return Response({"success": False, "message": "Resume not found."}, status=404)
            
        serializer = JDMatchInputSerializer(data=request.data)
        if serializer.is_valid():
            # Get missing skills from the latest JD match analysis for this resume
            missing_skills = []
            try:
                from analysis.models import JDMatchAnalysis
                latest_jd_match = JDMatchAnalysis.objects.filter(resume=resume).order_by("-created_at").first()
                if latest_jd_match and latest_jd_match.missing_skills:
                    missing_skills = latest_jd_match.missing_skills
            except Exception:
                pass
            
            result = JDMatchingService.generate_tailored_resume(
                resume, 
                serializer.validated_data["job_description"],
                missing_skills=missing_skills
            )
            
            # Immediately save the newly tailored markdown into ResumeImprovement.jd_tailored_content
            # so download endpoints in JD match tab immediately use it!
            if isinstance(result, dict) and result.get("markdown"):
                try:
                    from analysis.models import ResumeImprovement
                    improvement = ResumeImprovement.objects.filter(resume=resume).order_by("-created_at").first()
                    if not improvement:
                        improvement = ResumeImprovement.objects.create(
                            resume=resume,
                            jd_tailored_content=result["markdown"]
                        )
                    else:
                        improvement.jd_tailored_content = result["markdown"]
                        improvement.save(update_fields=['jd_tailored_content'])
                except Exception as e:
                    logger.error(f"Failed to auto-save jd tailored markdown: {e}")
                    
            return Response({"success": True, "data": result})
        return Response(serializer.errors, status=400)

# --- Premium Features (Gated) ---

class SkillGapAnalysisView(APIView):
    permission_classes = [permissions.IsAuthenticated, IsPremiumUser]

    @extend_schema(request=SkillGapInputSerializer, responses=SkillGapAnalysisSerializer)
    def post(self, request):
        serializer = SkillGapInputSerializer(data=request.data)
        if serializer.is_valid():
            request.user._temp_experience = serializer.validated_data.get("experience", "Mid-Level")
            AdvancedSkillGapService.analyze_skill_gap(
                request.user, 
                serializer.validated_data["target_role"],
                serializer.validated_data.get("resume_id")
            )
            from analysis.models import SkillGapAnalysis
            analysis = SkillGapAnalysis.objects.filter(
                user=request.user, 
                target_role=serializer.validated_data["target_role"]
            ).order_by("-created_at").first()
            from resumes.models import Resume
            latest_resume = Resume.objects.filter(user=request.user).order_by("-created_at").first()
            is_guiding_mode = False
            if not latest_resume or not hasattr(latest_resume, "parsed_content") or not latest_resume.parsed_content.extracted_skills:
                is_guiding_mode = True
                
            data = SkillGapAnalysisSerializer(analysis).data
            data['is_guiding_mode'] = is_guiding_mode
            return Response({"success": True, "data": data})
        return Response(serializer.errors, status=400)

from django.http import HttpResponse
from analysis.pdf_generator import generate_skill_gap_pdf
from django.shortcuts import get_object_or_404
from analysis.models import SkillGapAnalysis

class DownloadSkillGapPDFView(APIView):
    permission_classes = [permissions.IsAuthenticated, IsPremiumUser]
    
    def get(self, request, pk):
        analysis = get_object_or_404(SkillGapAnalysis, pk=pk, user=request.user)
        from resumes.models import Resume
        latest_resume = Resume.objects.filter(user=request.user).order_by("-created_at").first()
        is_guiding_mode = False
        if not latest_resume or not hasattr(latest_resume, "parsed_content") or not latest_resume.parsed_content.extracted_skills:
            is_guiding_mode = True
            
        pdf_buffer = generate_skill_gap_pdf(analysis, is_guiding_mode=is_guiding_mode)
        
        response = HttpResponse(pdf_buffer.getvalue(), content_type='application/pdf')
        response['Content-Disposition'] = f'attachment; filename="roadmap_{analysis.target_role.replace(" ", "_")}.pdf"'
        return response

class CareerRoadmapView(APIView):
    permission_classes = [permissions.IsAuthenticated, IsPremiumUser]

    @extend_schema(request=CareerRoadmapInputSerializer, responses=CareerRoadmapSerializer)
    def post(self, request):
        serializer = CareerRoadmapInputSerializer(data=request.data)
        if serializer.is_valid():
            analysis = CareerRoadmapService.generate_roadmap(
                request.user,
                serializer.validated_data["current_role"],
                serializer.validated_data["target_role"]
            )
            return Response({"success": True, "data": CareerRoadmapSerializer(analysis).data})
        return Response(serializer.errors, status=400)

class InterviewPreparationView(BaseAnalysisView):
    permission_classes = [permissions.IsAuthenticated, IsPremiumUser]

    @extend_schema(request=InterviewPrepInputSerializer, responses=InterviewPreparationSerializer)
    def post(self, request, resume_id):
        resume = self.get_resume(resume_id, request.user)
        if not resume:
            return Response({"success": False, "message": "Resume not found."}, status=404)
            
        serializer = InterviewPrepInputSerializer(data=request.data)
        if serializer.is_valid():
            analysis = InterviewSimulationService.generate_kit(
                resume, 
                serializer.validated_data["target_role"],
                serializer.validated_data.get("job_description", ""),
                serializer.validated_data.get("difficulty_level", "intermediate")
            )
            return Response({"success": True, "data": InterviewPreparationSerializer(analysis).data})
        return Response(serializer.errors, status=400)

class ProjectRecommendationView(BaseAnalysisView):
    permission_classes = [permissions.IsAuthenticated, IsPremiumUser]

    @extend_schema(request=ProjectRecommendationInputSerializer, responses=ProjectRecommendationSerializer)
    def post(self, request, resume_id):
        resume = self.get_resume(resume_id, request.user)
        if not resume:
            return Response({"success": False, "message": "Resume not found."}, status=404)
            
        serializer = ProjectRecommendationInputSerializer(data=request.data)
        if serializer.is_valid():
            analysis = ProjectRecommendationService.recommend_projects(
                resume, 
                serializer.validated_data["career_goal"]
            )
            return Response({"success": True, "data": ProjectRecommendationSerializer(analysis).data})
        return Response(serializer.errors, status=400)

class CoverLetterView(BaseAnalysisView):
    permission_classes = [permissions.IsAuthenticated, IsPremiumUser]

    @extend_schema(request=CoverLetterInputSerializer, responses=CoverLetterSerializer)
    def post(self, request, resume_id):
        resume = self.get_resume(resume_id, request.user)
        if not resume:
            return Response({"success": False, "message": "Resume not found."}, status=404)
            
        serializer = CoverLetterInputSerializer(data=request.data)
        if serializer.is_valid():
            analysis = CoverLetterService.generate_cover_letter(
                resume,
                serializer.validated_data["job_title"],
                serializer.validated_data["company_name"],
                serializer.validated_data["job_description"]
            )
            return Response({"success": True, "data": CoverLetterSerializer(analysis).data})
        return Response(serializer.errors, status=400)

