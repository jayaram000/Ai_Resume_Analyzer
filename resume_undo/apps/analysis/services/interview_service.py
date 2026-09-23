import json
import logging
from common.gemini import call_gemini_api
from resumes.models import Resume
from analysis.models import InterviewPreparation
from ._common import _get_resume_text

logger = logging.getLogger(__name__)

def generate_interview_prep(resume: Resume, target_role: str) -> InterviewPreparation:
    text = _get_resume_text(resume)
    prompt = f"""
Generate technical, HR, and role-specific interview preparation questions and sample answers based on the user's resume and target role: "{target_role}".

Your response MUST be a JSON object matching this schema:
{{
  "technical_questions": [
     {{"question": "Q1", "answer": "A1"}}
  ],
  "hr_questions": [
     {{"question": "Q1", "answer": "A1"}}
  ],
  "role_specific_questions": [
     {{"question": "Q1", "answer": "A1"}}
  ]
}}

Resume text:
{text[:3000]}
"""
    try:
        result = call_gemini_api(prompt, response_mime_type="application/json", max_retries=1)
    except Exception as e:
        logger.error(f"Interview prep API failed: {str(e)}")
        result = {
            "technical_questions": [],
            "hr_questions": [],
            "role_specific_questions": []
        }
    
    prep = InterviewPreparation.objects.create(
        resume=resume,
        target_role=target_role,
        technical_questions=result.get("technical_questions", []),
        hr_questions=result.get("hr_questions", []),
        role_specific_questions=result.get("role_specific_questions", [])
    )
    return prep



class InterviewSimulationService:
    @staticmethod
    def generate_kit(resume, target_role: str, job_description: str, difficulty_level: str):
        from analysis.services import _get_resume_text
        from common.gemini import call_gemini_api
        from analysis.models import InterviewPreparation

        resume_text = _get_resume_text(resume)

        prompt = f"""
Generate an interview preparation kit for the target role "{target_role}" with difficulty level "{difficulty_level}".
Base the questions on the candidate's resume and target job description.
The output MUST include:
1. Technical Questions (focus on tech stack, libraries, architecture)
2. HR Questions (focus on career goals, strengths, weaknesses)
3. Behavioral Questions (focus on STAR method: Situation, Task, Action, Result)

Your response MUST be a single JSON object matching this schema:
{{
  "technical_questions": [
     {{"question": "Question text", "answer": "Suggested response guidelines"}}
  ],
  "hr_questions": [
     {{"question": "Question text", "answer": "Suggested response guidelines"}}
  ],
  "role_specific_questions": [
     {{"question": "Behavioral Question (STAR method) text", "answer": "Suggested response guidelines using STAR"}}
  ]
}}

Candidate Resume:
{resume_text[:3000]}

Job Description:
{job_description[:3000]}
"""
        try:
            result = call_gemini_api(prompt, response_mime_type="application/json")
        except Exception:
            result = {
                "technical_questions": [{"question": f"Explain key concepts in {target_role}.", "answer": "Discuss core frameworks and tools."}],
                "hr_questions": [{"question": "Why do you want to join our company?", "answer": "Align your values with the company."}],
                "role_specific_questions": [{"question": "Tell me about a time you solved a complex problem.", "answer": "Use STAR method."}]
            }

        prep = InterviewPreparation.objects.create(
            resume=resume,
            target_role=target_role,
            difficulty_level=difficulty_level,
            technical_questions=result.get("technical_questions", []),
            hr_questions=result.get("hr_questions", []),
            role_specific_questions=result.get("role_specific_questions", [])
        )
        return prep


