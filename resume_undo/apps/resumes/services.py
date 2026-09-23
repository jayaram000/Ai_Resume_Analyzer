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
    def _extract_skills_and_keywords(resume: Resume):
        parsed = getattr(resume, "parsed_content", None)
        skills = []
        if parsed and parsed.extracted_skills:
            skills = list(parsed.extracted_skills)
        
        text = resume.raw_text or (parsed.extracted_text if parsed else "")
        if not text and hasattr(resume, "sections"):
            text = " ".join([s.content for s in resume.sections.all()])
            
        common_tech = [
            "Python", "Django", "DRF", "Flutter", "Dart", "JavaScript", "TypeScript",
            "React", "Node.js", "PostgreSQL", "SQL", "Docker", "Kubernetes", "AWS",
            "Git", "CI/CD", "REST API", "Microservices", "Redis", "Celery", "Linux",
            "GraphQL", "MongoDB", "HTML", "CSS", "Agile", "Scrum", "TDD", "System Design"
        ]
        
        found_skills = set(s.lower() for s in skills)
        if text:
            lower_text = text.lower()
            for tech in common_tech:
                if tech.lower() in lower_text:
                    found_skills.add(tech.lower())
        
        skills_list = [s.title() if len(s) > 3 else s.upper() for s in found_skills]
        return skills_list, text

    @staticmethod
    def get_snapshot_data(resume: Resume):
        latest_analysis = resume.ats_analyses.order_by("-created_at").first()
        if latest_analysis:
            ats = latest_analysis.ats_score
            formatting = latest_analysis.formatting_score or 70
            completeness = latest_analysis.completeness_score or 70
            skills_score = latest_analysis.skills_score or 70
            health = int((ats + formatting + completeness + skills_score) / 4)
            recruiter = max(20, min(100, int(ats * 0.95)))
        else:
            try:
                from analysis.services.ats_scoring_service import ATSScoringService
                scores = ATSScoringService.calculate_ats_score(resume)
                ats = scores.get("ats_score", 65)
                health = scores.get("completeness_score", 70)
                recruiter = scores.get("skills_score", 60)
            except Exception:
                ats = 65
                health = 70
                recruiter = 65

        skills, text = ResumeComparisonService._extract_skills_and_keywords(resume)
        return {
            "ats_score": ats,
            "health_score": health,
            "recruiter_score": recruiter,
            "skills": skills,
            "text": text,
        }

    @staticmethod
    def compare_resumes(resume_old: Resume, resume_new: Resume):
        import uuid
        snap_old = ResumeComparisonService.get_snapshot_data(resume_old)
        snap_new = ResumeComparisonService.get_snapshot_data(resume_new)

        skills_old = set(snap_old["skills"])
        skills_new = set(snap_new["skills"])
        added_skills = sorted(list(skills_new - skills_old))
        removed_skills = sorted(list(skills_old - skills_new))

        keywords_old = set(w.lower() for w in snap_old["skills"])
        keywords_new = set(w.lower() for w in snap_new["skills"])
        added_keywords = [k.title() for k in (keywords_new - keywords_old)]
        removed_keywords = [k.title() for k in (keywords_old - keywords_new)]

        ats_diff = snap_new["ats_score"] - snap_old["ats_score"]
        recruiter_diff = snap_new["recruiter_score"] - snap_old["recruiter_score"]
        health_diff = snap_new["health_score"] - snap_old["health_score"]

        prompt = f"""
        You are an expert career coach. Compare these two resume versions based on their analysis snapshots:
        Old Version:
        ATS: {snap_old['ats_score']}, Recruiter: {snap_old['recruiter_score']}, Health: {snap_old['health_score']}
        Skills: {snap_old['skills']}

        New Version:
        ATS: {snap_new['ats_score']}, Recruiter: {snap_new['recruiter_score']}, Health: {snap_new['health_score']}
        Skills: {snap_new['skills']}
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
            delta_str = f"+{ats_diff}" if ats_diff >= 0 else f"{ats_diff}"
            if added_skills:
                skills_highlight = f", incorporating key competencies such as {', '.join(added_skills[:3])}"
            else:
                skills_highlight = ""
            ai_summary = f"Your revised resume shows an ATS score progression of {delta_str} points and a health score change of {health_diff} points{skills_highlight}. The structure demonstrates improved keyword alignment."

        return {
            "id": str(uuid.uuid4()),
            "before_resume": {
                "id": str(resume_old.id),
                "title": resume_old.title,
                "version": getattr(resume_old, "version", 1),
                "analysis_snapshot": {
                    "ats_score": snap_old["ats_score"],
                    "health_score": snap_old["health_score"],
                    "recruiter_score": snap_old["recruiter_score"],
                },
            },
            "after_resume": {
                "id": str(resume_new.id),
                "title": resume_new.title,
                "version": getattr(resume_new, "version", 1),
                "analysis_snapshot": {
                    "ats_score": snap_new["ats_score"],
                    "health_score": snap_new["health_score"],
                    "recruiter_score": snap_new["recruiter_score"],
                },
            },
            "ats_difference": ats_diff,
            "recruiter_difference": recruiter_diff,
            "health_difference": health_diff,
            "added_skills": added_skills,
            "removed_skills": removed_skills,
            "added_keywords": added_keywords,
            "removed_keywords": removed_keywords,
            "ai_summary": ai_summary.strip(),
        }
