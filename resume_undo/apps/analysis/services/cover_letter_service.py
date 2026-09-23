import json
import logging
from common.gemini import call_gemini_api
from resumes.models import Resume
from analysis.models import CoverLetter
from ._common import _get_resume_text

logger = logging.getLogger(__name__)

def generate_cover_letter(resume: Resume, job_title: str, company_name: str, job_description: str) -> CoverLetter:
    text = _get_resume_text(resume)
    prompt = f"""
Generate a professional cover letter based on the user's resume and target job description.
Job Title: "{job_title}"
Company Name: "{company_name}"

Your response MUST be a JSON object matching this schema:
{{
  "content": "Full cover letter text content..."
}}

Resume:
{text[:3000]}

Job Description:
{job_description[:3000]}
"""
    try:
        result = call_gemini_api(prompt, response_mime_type="application/json", max_retries=1)
    except Exception as e:
        logger.error(f"Cover letter API failed: {str(e)}")
        result = {"content": "Could not generate cover letter at this time. Please try again later."}
    
    letter = CoverLetter.objects.create(
        resume=resume,
        job_title=job_title,
        company_name=company_name,
        job_description=job_description,
        content=result.get("content", "")
    )
    return letter




class CoverLetterService:
    @staticmethod
    def generate_cover_letter(resume, job_title: str, company_name: str, job_description: str):
        from analysis.services import generate_cover_letter
        return generate_cover_letter(resume, job_title, company_name, job_description)


