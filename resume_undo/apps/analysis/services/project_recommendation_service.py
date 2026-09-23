import json
import logging
from common.gemini import call_gemini_api
from resumes.models import Resume
from analysis.models import ProjectRecommendation
from ._common import _get_resume_text

logger = logging.getLogger(__name__)

def generate_project_recommendation(resume: Resume, career_goal: str) -> ProjectRecommendation:
    text = _get_resume_text(resume)
    prompt = f"""
Recommend portfolio projects for a developer based on their resume and their career goal of: "{career_goal}". Focus on projects that build missing skills.

Your response MUST be a JSON object matching this schema:
{{
  "recommended_projects": [
     {{"title": "Project Title", "description": "Details", "complexity": "Advanced/Intermediate", "skills_gained": ["skill1"]}}
  ]
}}

Resume text:
{text[:3000]}
"""
    try:
        result = call_gemini_api(prompt, response_mime_type="application/json", max_retries=1)
    except Exception as e:
        logger.error(f"Project recommendation API failed: {str(e)}")
        result = {"recommended_projects": []}
    
    proj = ProjectRecommendation.objects.create(
        resume=resume,
        career_goal=career_goal,
        recommended_projects=result.get("recommended_projects", [])
    )
    return proj



class ProjectRecommendationService:
    @staticmethod
    def recommend_projects(resume, career_goal: str):
        from analysis.services import _get_resume_text
        from common.gemini import call_gemini_api
        from analysis.models import ProjectRecommendation

        resume_text = _get_resume_text(resume)

        prompt = f"""
Recommend 4 specific, high-impact portfolio projects for a developer targeting the role "{career_goal}".
The projects should help fill potential skill gaps and make the candidate's portfolio stand out.
Each recommendation MUST contain:
- title: Project name (e.g., "AI Career Copilot", "Logistics Management System")
- problem_statement: Problem this project solves
- features: Core features to implement
- tech_stack: Recommended technologies/languages/frameworks
- difficulty: Difficulty level (Beginner/Intermediate/Advanced)
- estimated_time: Estimated time to build (e.g., "3 weeks")

Your response MUST be a JSON object matching this schema:
{{
  "recommended_projects": [
     {{
       "title": "Project title",
       "problem_statement": "Statement",
       "features": ["feature1", "feature2"],
       "tech_stack": ["tech1", "tech2"],
       "difficulty": "Intermediate",
       "estimated_time": "3 weeks"
     }}
  ]
}}

Candidate Resume:
{resume_text[:3000]}
"""
        try:
            result = call_gemini_api(prompt, response_mime_type="application/json")
        except Exception:
            result = {
                "recommended_projects": [
                    {
                        "title": "AI Career Copilot",
                        "problem_statement": "Job seekers struggle to optimize their resumes and prepare for interviews.",
                        "features": ["Resume Parsing", "ATS Scoring", "Interview simulation Q&A"],
                        "tech_stack": ["Python", "Django", "Flutter", "Gemini API"],
                        "difficulty": "Advanced",
                        "estimated_time": "4 weeks"
                    }
                ]
            }

        proj = ProjectRecommendation.objects.create(
            resume=resume,
            career_goal=career_goal,
            recommended_projects=result.get("recommended_projects", [])
        )
        return proj


