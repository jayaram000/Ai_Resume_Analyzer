import json
import logging
import re
from common.gemini import call_gemini_api
from resumes.models import Resume
from analysis.models import PositionAnalysis, JDMatchAnalysis
from ._common import _get_resume_text

logger = logging.getLogger(__name__)

class JDMatchingService:
    @staticmethod
    def match_resume_to_jd(resume: Resume, job_description: str) -> dict:
        """
        Deep comparison of resume vs a specific job description.
        """
        parsed = getattr(resume, "parsed_content", None)
        resume_text = parsed.extracted_text if parsed else _get_resume_text(resume)
        
        prompt = f"""
Perform a deep comparison between the following resume and the target job description.
Identify:
1. Compatibility match score (0 to 100)
2. Matched skills (skills present in both the resume and JD)
3. Missing skills (skills in the JD but missing from the resume)
4. Missing keywords
5. ATS compatibility details (compatibility score and any structural issues).
6. Concrete recommendations.

Your response MUST be a JSON object matching this schema:
{{
  "match_score": 75,
  "matched_skills": ["Python", "Django", "REST APIs"],
  "missing_skills": ["Docker", "AWS", "Celery"],
  "missing_keywords": ["keyword1"],
  "ats_compatibility": {{
     "score": 80,
     "status": "Compatible",
     "issues": []
  }},
  "recommendations": ["rec1"]
}}

Resume text:
{resume_text[:3000]}

Job Description:
{job_description[:3000]}
"""
        try:
            result = call_gemini_api(prompt, response_mime_type="application/json")
        except Exception as e:
            logger.error(f"JD matching API failed: {str(e)}")
            # Default response
            result = {
                "match_score": 50,
                "matched_skills": [],
                "missing_skills": ["Required Skills"],
                "missing_keywords": ["Keywords"],
                "ats_compatibility": {"score": 50, "status": "Needs Improvement", "issues": []},
                "recommendations": ["Tailor resume keywords to the job description."]
            }
        return result

    @staticmethod
    def generate_tailored_resume(resume: Resume, job_description: str, missing_skills: list = None) -> dict:
        """
        Rewrites the resume to better target the job description.
        Returns a dict with:
          - markdown: the tailored resume in Markdown
          - changes: list of specific changes made
          - keywords_added: list of JD keywords incorporated
        """
        parsed = getattr(resume, "parsed_content", None)
        resume_text = parsed.extracted_text if parsed else _get_resume_text(resume)
        
        # Build original resume markdown for reference
        original_markdown = build_resume_markdown(resume)
        
        missing_skills_ctx = ""
        if missing_skills:
            missing_skills_ctx = f"""
CRITICAL - These are the MISSING SKILLS from the JD analysis that the resume currently LACKS.
You MUST strategically weave these keywords into relevant sections (Skills, Summary, Experience bullets):
Missing Skills: {', '.join(missing_skills)}

For each missing skill:
- If the candidate likely has exposure to it (transferable skill), add it naturally to relevant bullet points
- If it's a tool/technology, add it to the Skills section
- DO NOT fabricate experience, but DO emphasize related/transferable skills
"""
        
        prompt = f"""
You are an expert ATS-Resume Writer. Your task is to optimize the following resume to target the provided Job Description.

CRITICAL RULES:
1. DO NOT fabricate or invent past experiences, degrees, companies, or fake metrics.
2. DO rewrite the professional summary to align with the JD's goals and incorporate missing keywords.
3. DO rewrite bullet points to highlight transferable skills and exact keywords found in the JD.
4. DO add missing relevant skills to the Skills section if the candidate could reasonably have exposure to them.
5. DO NOT change company names, dates, degrees, or institutions.
6. Keep the same structure: # Name, ## sections.

{missing_skills_ctx}

Your response MUST be a JSON object with this exact schema:
{{
  "tailored_markdown": "The full tailored resume in Markdown format",
  "changes": [
    {{"section": "Professional Summary", "description": "Rewrote summary to emphasize X and Y from JD"}},
    {{"section": "Skills", "description": "Added Provider, Firebase, Docker to skills list"}},
    {{"section": "Experience Bullet #3", "description": "Highlighted REST API integration with Dio client"}}
  ],
  "keywords_added": ["Provider", "Firebase", "Docker", "JWT"]
}}

Original Resume Text:
{resume_text[:4000]}

Job Description:
{job_description[:4000]}
"""
        try:
            result = call_gemini_api(prompt, response_mime_type="application/json")
            
            if isinstance(result, dict):
                tailored_md = result.get("tailored_markdown", "")
                changes = result.get("changes", [])
                keywords_added = result.get("keywords_added", [])
                
                if not tailored_md or len(tailored_md.strip()) < 100:
                    tailored_md = original_markdown
                    
                return {
                    "markdown": tailored_md,
                    "original_markdown": original_markdown,
                    "changes": changes,
                    "keywords_added": keywords_added
                }
            
            # If result is a string (plain text), wrap it
            return {
                "markdown": str(result),
                "original_markdown": original_markdown,
                "changes": [],
                "keywords_added": []
            }
        except Exception as e:
            logger.error(f"Auto-Tailor API failed: {str(e)}")
            return {
                "markdown": original_markdown,
                "original_markdown": original_markdown,
                "changes": [],
                "keywords_added": [],
                "error": "Failed to generate tailored resume. Please try again."
            }



class PositionAnalysisService:
    @staticmethod
    def analyze_position(resume: Resume, target_position: str) -> dict:
        """
        Evaluates resume compatibility against a general target position role.
        """
        parsed = getattr(resume, "parsed_content", None)
        resume_text = parsed.extracted_text if parsed else _get_resume_text(resume)
        
        prompt = f"""
Analyze the following resume compatibility for the target position: "{target_position}".
Identify:
1. Compatibility score (0 to 100)
2. Missing skills
3. Recommended skills to pick up
4. Actionable learning suggestions.

Your response MUST be a JSON object matching this schema:
{{
  "match_score": 80,
  "missing_skills": ["skill1"],
  "recommended_skills": ["skill2"],
  "suggestions": "detailed text suggestions"
}}

Resume text:
{resume_text[:4000]}
"""
        try:
            result = call_gemini_api(prompt, response_mime_type="application/json")
        except Exception as e:
            logger.error(f"Position Analysis API failed: {str(e)}")
            result = {
                "match_score": 60,
                "missing_skills": ["Role specific skills"],
                "recommended_skills": ["Tech stack"],
                "suggestions": "Review role requirements and build relevant projects."
            }
        return result


# --- Model Helper Handlers ---



def generate_position_analysis(resume: Resume, target_position: str) -> PositionAnalysis:
    result = PositionAnalysisService.analyze_position(resume, target_position)
    
    analysis = PositionAnalysis.objects.create(
        resume=resume,
        target_position=target_position,
        match_score=result.get("match_score", 60),
        missing_skills=result.get("missing_skills", []),
        recommended_skills=result.get("recommended_skills", []),
        suggestions=result.get("suggestions", "")
    )
    return analysis



def generate_jd_match(resume: Resume, job_description: str) -> JDMatchAnalysis:
    result = JDMatchingService.match_resume_to_jd(resume, job_description)
    
    ats_comp = result.get("ats_compatibility")
    if not isinstance(ats_comp, dict):
        ats_comp = {}
    if "recommendations" not in ats_comp and result.get("recommendations"):
        ats_comp["recommendations"] = result.get("recommendations")
    
    analysis = JDMatchAnalysis.objects.create(
        resume=resume,
        job_description=job_description,
        match_score=result.get("match_score", 50),
        missing_keywords=result.get("missing_keywords", []),
        matched_skills=result.get("matched_skills", []),
        missing_skills=result.get("missing_skills", []),
        ats_compatibility=ats_comp
    )
    return analysis

