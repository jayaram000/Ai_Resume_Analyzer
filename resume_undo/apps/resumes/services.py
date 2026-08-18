import logging
from common.utils import extract_text_from_pdf, extract_text_from_docx
from common.gemini import call_gemini_api
from resumes.models import Resume, ParsedResume

logger = logging.getLogger(__name__)

def parse_and_save_resume(resume: Resume) -> ParsedResume:
    """
    Parses document file content, extracts text, calls Gemini to structure 
    the text (extracting Name, Email, Phone, Skills, Education, Experience,
    Projects, and Certifications), and saves it to the database.
    """
    ext = resume.file.name.split('.')[-1].lower()
    
    # Ensure the file is opened and readable in binary mode
    with resume.file.open('rb') as file_obj:
        # 1. Text Extraction
        if ext == 'pdf':
            extracted_text = extract_text_from_pdf(file_obj)
        elif ext == 'docx':
            extracted_text = extract_text_from_docx(file_obj)
        else:
            raise ValueError("Unsupported file format.")
        
    if not extracted_text.strip():
        raise ValueError("No text could be extracted from this document.")
        
    # 2. Structure using Gemini
    prompt = f"""
Analyze the following resume raw text and extract structured information.
Your response MUST be a single JSON object matching this schema:
{{
  "name": "Candidate Full Name",
  "email": "candidate@email.com",
  "phone": "+1234567890",
  "skills": ["skill1", "skill2"],
  "education": [
     {{"degree": "Degree", "field": "Field of Study", "school": "Institution Name", "year": "Graduation Year"}}
  ],
  "experience": [
     {{"role": "Role Title", "company": "Company Name", "duration": "Duration", "responsibilities": ["responsibility 1", "responsibility 2"]}}
  ],
  "projects": [
     {{"title": "Project Title", "description": "Project Description", "technologies": ["tech1"]}}
  ],
  "certifications": ["Certification 1"],
  "location": "Country Name (Prioritize extracting the Country if present, e.g. USA, Canada, India) or City/State"
}}

Resume Raw Text:
{extracted_text}
"""
    
    try:
        structured_data = call_gemini_api(prompt, response_mime_type="application/json")
        name = structured_data.get("name") or ""
        email = structured_data.get("email") or ""
        phone = structured_data.get("phone") or ""
        location = structured_data.get("location") or ""
        skills = structured_data.get("skills", [])
        education = structured_data.get("education", [])
        experience = structured_data.get("experience", [])
        projects = structured_data.get("projects", [])
        certifications = structured_data.get("certifications", [])
    except Exception as e:
        logger.error(f"Failed to structure resume text with Gemini: {str(e)}")
        # Default fallback values to prevent system crash
        name = ""
        email = ""
        phone = ""
        location = ""
        skills = ["Parsed Skill"]
        education = []
        experience = []
        projects = []
        certifications = []
        
    # 3. Save to Database
    parsed_resume, created = ParsedResume.objects.update_or_create(
        resume=resume,
        defaults={
            "extracted_text": extracted_text,
            "name": name,
            "email": email,
            "phone": phone,
            "location": location,
            "extracted_skills": skills,
            "extracted_education": education,
            "extracted_experience": experience,
            "extracted_projects": projects,
            "extracted_certifications": certifications
        }
    )
    return parsed_resume


class ResumeComparisonService:
    @staticmethod
    def get_or_create_snapshot(resume: Resume):
        from resumes.models import ResumeAnalysisSnapshot
        snapshot = getattr(resume, "analysis_snapshot", None)
        if snapshot:
            return snapshot

        parsed = getattr(resume, "parsed_content", None)
        resume_text = parsed.extracted_text if parsed else "No text found."
        
        prompt = f"""
        You are an expert technical recruiter and ATS system.
        Analyze the following resume and provide a deep analysis snapshot.
        Your response MUST be a single JSON object matching this schema:
        {{
            "ats_score": 0-100,
            "recruiter_score": 0-100,
            "health_score": 0-100,
            "missing_skills": ["skill1", "skill2"],
            "missing_keywords": ["keyword1"],
            "improvement_suggestions": ["suggestion1"]
        }}
        Resume Text:
        {resume_text}
        """
        try:
            gemini_result = call_gemini_api(prompt, response_mime_type="application/json")
        except Exception as e:
            logger.error(f"Snapshot generation failed: {e}")
            gemini_result = {
                "ats_score": 50, "recruiter_score": 50, "health_score": 50,
                "missing_skills": [], "missing_keywords": [], "improvement_suggestions": []
            }

        extracted_skills = parsed.extracted_skills if parsed else []
        extracted_projects = parsed.extracted_projects if parsed else []
        extracted_experience = parsed.extracted_experience if parsed else []

        snapshot = ResumeAnalysisSnapshot.objects.create(
            resume=resume,
            ats_score=gemini_result.get("ats_score", 50),
            recruiter_score=gemini_result.get("recruiter_score", 50),
            health_score=gemini_result.get("health_score", 50),
            missing_skills=gemini_result.get("missing_skills", []),
            missing_keywords=gemini_result.get("missing_keywords", []),
            improvement_suggestions=gemini_result.get("improvement_suggestions", []),
            extracted_skills=extracted_skills,
            extracted_projects=extracted_projects,
            extracted_experience=extracted_experience
        )
        return snapshot

    @staticmethod
    def compare_resumes(resume_old: Resume, resume_new: Resume):
        from resumes.models import ResumeComparison
        
        snap_old = ResumeComparisonService.get_or_create_snapshot(resume_old)
        snap_new = ResumeComparisonService.get_or_create_snapshot(resume_new)

        skills_old = set(snap_old.extracted_skills)
        skills_new = set(snap_new.extracted_skills)
        added_skills = list(skills_new - skills_old)
        removed_skills = list(skills_old - skills_new)

        keywords_old = set(snap_old.missing_keywords)
        keywords_new = set(snap_new.missing_keywords)
        # Keywords "added" means keywords that were missing in OLD but are now PRESENT in NEW
        # So they are in keywords_old but NOT in keywords_new
        added_keywords = list(keywords_old - keywords_new)
        # Keywords "removed" means keywords that were present in OLD but missing in NEW
        removed_keywords = list(keywords_new - keywords_old)

        ats_diff = snap_new.ats_score - snap_old.ats_score
        recruiter_diff = snap_new.recruiter_score - snap_old.recruiter_score
        health_diff = snap_new.health_score - snap_old.health_score

        prompt = f"""
        You are an expert career coach. Compare these two resume versions based on their analysis snapshots.
        
        Old Version:
        ATS: {snap_old.ats_score}, Recruiter: {snap_old.recruiter_score}, Health: {snap_old.health_score}
        Skills: {snap_old.extracted_skills}
        
        New Version:
        ATS: {snap_new.ats_score}, Recruiter: {snap_new.recruiter_score}, Health: {snap_new.health_score}
        Skills: {snap_new.extracted_skills}
        Added Skills: {added_skills}
        
        Provide a short (2-3 sentences) professional summary of the improvement, acting as the AI Career Copilot.
        Return plain text.
        """
        try:
            ai_summary_dict = call_gemini_api(prompt, response_mime_type="text/plain")
            if isinstance(ai_summary_dict, dict) and "text" in ai_summary_dict:
                ai_summary = ai_summary_dict["text"]
            else:
                ai_summary = str(ai_summary_dict)
        except Exception:
            ai_summary = f"Your updated resume shows an ATS score change of {ats_diff} and a health score change of {health_diff}."

        comparison = ResumeComparison.objects.create(
            user=resume_new.user,
            before_resume=resume_old,
            after_resume=resume_new,
            ats_difference=ats_diff,
            recruiter_difference=recruiter_diff,
            health_difference=health_diff,
            added_skills=added_skills,
            removed_skills=removed_skills,
            added_keywords=added_keywords,
            removed_keywords=removed_keywords,
            ai_summary=ai_summary
        )
        return comparison
