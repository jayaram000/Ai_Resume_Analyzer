import json
import logging
import re
from common.gemini import call_gemini_api
from resumes.models import Resume
from analysis.models import (
    ATSAnalysis,
    ResumeImprovement,
    PositionAnalysis,
    JDMatchAnalysis,
    SkillGapAnalysis,
    CareerRoadmap,
    InterviewPreparation,
    ProjectRecommendation,
    CoverLetter
)

logger = logging.getLogger(__name__)

def _get_resume_text(resume: Resume) -> str:
    """Helper to extract text from resume parse history, raw text, or file."""
    parsed = getattr(resume, "parsed_content", None)
    if parsed and parsed.extracted_text and len(parsed.extracted_text.strip()) > 50:
        return parsed.extracted_text
    if hasattr(resume, "raw_text") and resume.raw_text and len(resume.raw_text.strip()) > 50:
        return resume.raw_text
    try:
        if resume.file:
            ext = resume.file.name.split('.')[-1].lower()
            with resume.file.open('rb') as f:
                if ext == 'pdf':
                    from common.utils import extract_text_from_pdf
                    return extract_text_from_pdf(f)
                elif ext == 'docx':
                    from common.utils import extract_text_from_docx
                    return extract_text_from_docx(f)
    except Exception as e:
        logger.error(f"Failed direct text extraction for resume {resume.id}: {str(e)}")
    return ""

class ATSScoringService:
    @staticmethod
    def calculate_ats_score(resume: Resume, target_jd: str = None) -> dict:
        """
        Calculates a deterministic, non-random ATS score out of 100.
        Uses 6 scoring categories with appropriate weights.
        """
        parsed = getattr(resume, "parsed_content", None)
        text = parsed.extracted_text if parsed else _get_resume_text(resume)
        
        # 1. Completeness Score (10% weight)
        comp_points = 0
        if parsed:
            if len(text) > 100: comp_points += 2  # Has summary/intro text
            if len(parsed.extracted_skills) > 0: comp_points += 2
            if len(parsed.extracted_experience) > 0: comp_points += 2
            if len(parsed.extracted_education) > 0: comp_points += 2
            if len(parsed.extracted_projects) > 0: comp_points += 1
            if len(parsed.extracted_certifications) > 0: comp_points += 1
        else:
            comp_points = 5  # default if no parsed data
        completeness_score = int((comp_points / 10.0) * 100)

        # 2. Skills Score (20% weight)
        skills = parsed.extracted_skills if parsed else []
        skills_score = min(100, len(skills) * 10)  # 10 skills = 100 score

        # 3. Keyword Match Score (25% weight)
        standard_keywords = {
            "python", "django", "flutter", "dart", "javascript", "react", "sql", 
            "git", "docker", "aws", "kubernetes", "typescript", "postgres", 
            "html", "css", "ci/cd", "rest api", "testing", "agile", "scrum"
        }
        
        # Extract keywords from JD if provided
        jd_keywords = set()
        if target_jd:
            # Simple word extraction
            words = re.findall(r'\b[a-zA-Z]{3,}\b', target_jd.lower())
            jd_keywords = set(words).intersection(standard_keywords)
            if not jd_keywords:
                jd_keywords = {"python", "django", "flutter", "dart", "sql"} # fallback

        keyword_score = 0
        text_lower = text.lower()
        if jd_keywords:
            matched = [k for k in jd_keywords if k in text_lower]
            keyword_score = int((len(matched) / len(jd_keywords)) * 100)
        else:
            # Overlap with standard industry keywords
            matched = [k for k in standard_keywords if k in text_lower]
            keyword_score = min(100, len(matched) * 8)

        # 4. Formatting Score (15% weight)
        formatting_points = 70  # Base
        # Deduct if text is way too short or long
        char_count = len(text)
        if char_count < 500:
            formatting_points -= 30
        elif char_count > 8000:
            formatting_points -= 15
            
        # Add points if contact credentials are found
        has_email = "@" in text or (parsed and parsed.email)
        has_phone = re.search(r'\+?\d[\d -]{7,}\d', text) or (parsed and parsed.phone)
        if has_email: formatting_points += 15
        if has_phone: formatting_points += 15
        formatting_score = min(100, max(0, formatting_points))

        # 5. Experience Score (20% weight)
        action_verbs = {"led", "managed", "designed", "built", "created", "optimized", "refactored", "developed", "implemented"}
        verbs_found = [v for v in action_verbs if v in text_lower]
        exp_records = parsed.extracted_experience if parsed else []
        experience_score = min(100, (len(verbs_found) * 8) + (len(exp_records) * 15))
        if experience_score == 0 and len(text) > 500:
            experience_score = 65  # Default baseline for entry levels

        # 6. Education Score (10% weight)
        edu_score = 0
        degrees = {"phd", "doctorate", "master", "m.tech", "m.sc", "mba", "bachelor", "b.tech", "b.sc", "b.a", "degree"}
        edu_found = [d for d in degrees if d in text_lower]
        if edu_found:
            if "phd" in edu_found or "doctorate" in edu_found:
                edu_score = 100
            elif "master" in edu_found or "m.tech" in edu_found or "mba" in edu_found:
                edu_score = 90
            else:
                edu_score = 80
        elif parsed and len(parsed.extracted_education) > 0:
            edu_score = 75
        education_score = edu_score

        # Calculate weighted average ATS score
        ats_score = int(
            (keyword_score * 0.25) +
            (skills_score * 0.20) +
            (experience_score * 0.20) +
            (formatting_score * 0.15) +
            (education_score * 0.10) +
            (completeness_score * 0.10)
        )
        
        # Suggestions list based on category gaps
        suggestions = []
        if completeness_score < 80:
            suggestions.append("Fill in missing resume sections. Ensure Projects and Certifications are clearly defined.")
        if skills_score < 70:
            suggestions.append("Add more tech stack skills matching your target industry (e.g. cloud tools, APIs).")
        if keyword_score < 75:
            suggestions.append("Tailor your resume vocabulary to match industry standard keyword keywords.")
        if formatting_score < 80:
            suggestions.append("Ensure your email address and phone contact details are clearly visible on the document layout.")
        if experience_score < 75:
            suggestions.append("Use strong action verbs (e.g., 'Engineered', 'Optimized', 'Led') to start experience bullet points.")
        if education_score < 70:
            suggestions.append("Explicitly state your academic degree details (e.g. BS, B.Tech, MS) in the education section.")
            
        if not suggestions:
            suggestions.append("Resume formatting is excellent. Keep tailoring keywords to specific roles you apply for.")

        return {
            "ats_score": ats_score,
            "keyword_score": keyword_score,
            "formatting_score": formatting_score,
            "skills_score": skills_score,
            "experience_score": experience_score,
            "education_score": education_score,
            "completeness_score": completeness_score,
            "suggestions": suggestions
        }

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

def generate_ats_analysis(resume: Resume) -> ATSAnalysis:
    """
    Computes ATS score mathematically using ATSScoringService,
    then saves to database.
    """
    scores = ATSScoringService.calculate_ats_score(resume)
    
    analysis = ATSAnalysis.objects.create(
        resume=resume,
        ats_score=scores["ats_score"],
        keyword_score=scores["keyword_score"],
        formatting_score=scores["formatting_score"],
        skills_score=scores["skills_score"],
        experience_score=scores["experience_score"],
        education_score=scores["education_score"],
        completeness_score=scores["completeness_score"],
        suggestions=scores["suggestions"]
    )
    return analysis

def generate_resume_improvements(resume: Resume) -> ResumeImprovement:
    text = _get_resume_text(resume)
    parsed = getattr(resume, "parsed_content", None)
    
    candidate_bullets = []
    if parsed and parsed.extracted_experience:
        for exp in parsed.extracted_experience:
            if isinstance(exp, dict):
                for resp in exp.get("responsibilities", []):
                    if resp and str(resp).strip():
                        candidate_bullets.append(str(resp).strip())

    bullets_formatted = "\n".join([f"- {b}" for b in candidate_bullets])

    parsed_ctx = ""
    if parsed:
        parsed_ctx = f"""
Candidate Parsed Structure:
- Name: {parsed.name}
- Extracted Skills: {json.dumps(parsed.extracted_skills)}
- Extracted Education: {json.dumps(parsed.extracted_education)}
- Extracted Experience: {json.dumps(parsed.extracted_experience)}
"""

    prompt = f"""
Act as an elite Executive Recruiter and ATS-Resume Writer.
Review the following resume and provide a deeply comprehensive, professional ATS-friendly critique.
Focus on impact, action verbs, quantifiable metrics, keyword optimization, and structural completeness.

CRITICAL RULES:
1. DO NOT fabricate past experiences.
2. DO NOT criticize or mention truncated text or ellipses if the degree/education is intact in candidate structure. Focus on genuine career critique.
3. Identify top strengths, weaknesses, bullet point optimizations (mapping old text to STAR method rewrites), and professional summary advice.
4. FOR `better_bullet_points`:
   - The JSON keys MUST BE an EXACT word-for-word copy of one of the candidate's existing bullets from the list below. DO NOT rephrase, summarize, or alter the key string in any way.
   - The JSON value MUST be the improved, high-impact STAR method rewrite of that exact bullet point.

Candidate's EXACT existing bullet points to optimize:
{bullets_formatted if bullets_formatted else text[:3000]}

Your response MUST be a JSON object matching this schema exactly:
{{
  "strengths": ["Detailed strength 1", "Detailed strength 2"],
  "weaknesses": ["Detailed weakness 1", "Detailed weakness 2"],
  "better_bullet_points": {{
     "Exact existing bullet point copied word-for-word from above": "Improved bullet point using strong action verbs and metrics"
  }},
  "summary_suggestions": "A compelling, keyword-rich professional summary",
  "missing_sections": []
}}

{parsed_ctx}

Resume text:
{text[:6000]}
"""
    try:
        result = call_gemini_api(prompt, response_mime_type="application/json", max_retries=1)
    except Exception as e:
        logger.error(f"Resume improvements API failed: {str(e)}")
        result = {
            "strengths": ["Strong modern technical skill set", "Clear multi-domain project exposure"],
            "weaknesses": ["Lack of quantifiable metrics and KPIs", "Generic verb phrasing across experience section"],
            "better_bullet_points": {},
            "summary_suggestions": "Tailor your professional summary to highlight measurable achievements and leadership roles.",
            "missing_sections": []
        }
    
    weaknesses_list = result.get("weaknesses", [])
    # Clean up any hallucinated truncated/ellipses text from weaknesses
    cleaned_weaknesses = [
        w for w in weaknesses_list 
        if "truncated" not in w.lower() and "..." not in w and "lovely pr" not in w.lower()
    ]
    if not cleaned_weaknesses:
        cleaned_weaknesses = ["Lack of quantifiable metrics (KPIs) in experience bullet points."]

    improvement = ResumeImprovement.objects.create(
        resume=resume,
        strengths=result.get("strengths", []),
        weaknesses=cleaned_weaknesses,
        better_bullet_points=result.get("better_bullet_points", {}),
        summary_suggestions=result.get("summary_suggestions", ""),
        missing_sections=result.get("missing_sections", [])
    )
    return improvement

def build_resume_markdown(resume: Resume) -> str:
    """
    Builds a clean Markdown representation of the resume from parsed structured data.
    NO AI is used — this preserves the exact original content without hallucination.
    """
    parsed = getattr(resume, "parsed_content", None)
    if not parsed:
        # Fallback to raw text if no parsed content
        return _get_resume_text(resume)

    lines = []

    # --- Header ---
    if parsed.name:
        lines.append(f"# {parsed.name}")

    contact_parts = []
    if parsed.email:
        contact_parts.append(parsed.email)
    if parsed.phone:
        contact_parts.append(parsed.phone)
    if parsed.location:
        contact_parts.append(parsed.location)
    if contact_parts:
        lines.append(" | ".join(contact_parts))
    lines.append("")

    # --- Professional Summary: extract from raw text ---
    raw_text = parsed.extracted_text or _get_resume_text(resume)
    summary = _extract_section_text(raw_text, ["PROFESSIONAL SUMMARY", "SUMMARY", "PROFILE", "OBJECTIVE", "CAREER SUMMARY"])
    if summary:
        lines.append("## PROFESSIONAL SUMMARY")
        lines.append(summary.strip())
        lines.append("")

    # --- Skills ---
    if parsed.extracted_skills and len(parsed.extracted_skills) > 0:
        # Try to extract structured skills sections from raw text first
        skills_section = _extract_section_text(raw_text, ["SKILLS", "TECHNICAL SKILLS", "CORE COMPETENCIES"])
        if skills_section and len(skills_section.strip()) > 30:
            lines.append("## SKILLS")
            # Preserve the original formatting from the raw text
            for skill_line in skills_section.strip().split("\n"):
                sl = skill_line.strip()
                if sl:
                    if not sl.startswith("- ") and not sl.startswith("* ") and not sl.startswith("•"):
                        lines.append(f"* {sl}")
                    else:
                        lines.append(f"* {sl.lstrip('-*• ').strip()}")
        else:
            lines.append("## SKILLS")
            for skill in parsed.extracted_skills:
                lines.append(f"* {skill}")
        lines.append("")

    # --- Professional Experience ---
    if parsed.extracted_experience and len(parsed.extracted_experience) > 0:
        lines.append("## PROFESSIONAL EXPERIENCE")
        lines.append("")
        for exp in parsed.extracted_experience:
            if isinstance(exp, dict):
                role = exp.get("role", exp.get("title", ""))
                company = exp.get("company", "")
                duration = exp.get("duration", exp.get("dates", ""))

                header_parts = [p for p in [role, company] if p]
                lines.append(f"### {' | '.join(header_parts)}")
                if duration:
                    lines.append(f"*{duration}*")

                responsibilities = exp.get("responsibilities", exp.get("bullets", []))
                if isinstance(responsibilities, list):
                    for resp in responsibilities:
                        if resp and str(resp).strip():
                            lines.append(f"* {str(resp).strip()}")
                elif responsibilities:
                    lines.append(f"* {str(responsibilities).strip()}")
                lines.append("")
            elif isinstance(exp, str):
                lines.append(f"* {exp}")
                lines.append("")

    # --- Projects ---
    if parsed.extracted_projects and len(parsed.extracted_projects) > 0:
        lines.append("## PROJECTS")
        lines.append("")
        for proj in parsed.extracted_projects:
            if isinstance(proj, dict):
                title = proj.get("title", proj.get("name", ""))
                description = proj.get("description", "")
                technologies = proj.get("technologies", proj.get("tech_stack", []))

                if title:
                    lines.append(f"### {title}")
                if description:
                    lines.append(description.strip())
                if technologies:
                    if isinstance(technologies, list):
                        lines.append(f"**Tech Stack:** {', '.join(technologies)}")
                    else:
                        lines.append(f"**Tech Stack:** {technologies}")
                lines.append("")
            elif isinstance(proj, str):
                lines.append(f"* {proj}")
                lines.append("")

    # --- Education ---
    if parsed.extracted_education and len(parsed.extracted_education) > 0:
        lines.append("## EDUCATION")
        lines.append("")
        for edu in parsed.extracted_education:
            if isinstance(edu, dict):
                degree = edu.get("degree", "")
                field = edu.get("field", "")
                school = edu.get("school", edu.get("institution", ""))
                year = edu.get("year", edu.get("dates", ""))

                degree_text = f"{degree} in {field}" if field and degree else (degree or field)
                if degree_text:
                    lines.append(f"### {degree_text}")

                meta_parts = []
                if year:
                    meta_parts.append(str(year))
                if school:
                    meta_parts.append(school)
                if meta_parts:
                    lines.append(f"*{' | '.join(meta_parts)}*")
                lines.append("")
            elif isinstance(edu, str):
                lines.append(f"* {edu}")
                lines.append("")

    # --- Certifications ---
    if parsed.extracted_certifications and len(parsed.extracted_certifications) > 0:
        lines.append("## CERTIFICATIONS")
        for cert in parsed.extracted_certifications:
            lines.append(f"* {cert}")
        lines.append("")

    # --- Languages: try to extract from raw text ---
    languages_section = _extract_section_text(raw_text, ["LANGUAGES", "LANGUAGES & ADDITIONAL"])
    if languages_section and len(languages_section.strip()) > 3:
        lines.append("## LANGUAGES")
        lines.append(languages_section.strip())
        lines.append("")

    result = "\n".join(lines)
    # If parsed data was too sparse, fall back to raw extracted text
    if len(result.strip()) < 100:
        return raw_text
    return result


def _extract_section_text(text: str, section_names: list) -> str:
    """
    Extract text belonging to a specific section from raw resume text.
    Looks for section headers and captures text until the next section header.
    """
    if not text:
        return ""

    # Common section headers in resumes
    all_sections = [
        "PROFESSIONAL SUMMARY", "SUMMARY", "PROFILE", "OBJECTIVE", "CAREER SUMMARY",
        "SKILLS", "TECHNICAL SKILLS", "CORE COMPETENCIES",
        "PROFESSIONAL EXPERIENCE", "WORK EXPERIENCE", "EXPERIENCE",
        "PROJECTS", "EDUCATION", "CERTIFICATIONS", "LANGUAGES",
        "LANGUAGES & ADDITIONAL", "ADDITIONAL INFO", "ACHIEVEMENTS",
    ]

    lines = text.split("\n")
    capturing = False
    captured = []

    for line in lines:
        stripped = line.strip().upper()
        # Check if this line is a section header
        is_section_header = any(stripped == s or stripped.startswith(s + ":") or stripped.startswith(s + " ") for s in all_sections)

        if is_section_header:
            if any(stripped == s or stripped.startswith(s + ":") or stripped.startswith(s + " ") for s in [sn.upper() for sn in section_names]):
                capturing = True
                continue
            elif capturing:
                # We've hit the next section, stop capturing
                break
        elif capturing:
            captured.append(line)

    return "\n".join(captured).strip()


def generate_improved_resume_content(resume: Resume) -> str:
    """
    Returns the resume content as Markdown.
    Uses saved tailored_content if available (user has already accepted suggestions),
    otherwise builds markdown from the parsed resume data.
    NO AI hallucination — preserves exact original content.
    """
    from analysis.models import ResumeImprovement

    # Check if user has already saved tailored content (via accepted suggestions)
    improvement = ResumeImprovement.objects.filter(resume=resume).order_by("-created_at").first()
    if improvement and improvement.tailored_content and len(improvement.tailored_content.strip()) > 150:
        return improvement.tailored_content

    # Build markdown from actual parsed resume data (no AI)
    markdown = build_resume_markdown(resume)

    # Save it so next time it's instant
    if improvement and markdown and len(markdown.strip()) > 100:
        improvement.tailored_content = markdown
        improvement.save(update_fields=['tailored_content'])

    return markdown


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
    
    analysis = JDMatchAnalysis.objects.create(
        resume=resume,
        job_description=job_description,
        match_score=result.get("match_score", 50),
        missing_keywords=result.get("missing_keywords", []),
        matched_skills=result.get("matched_skills", []), # Note: matches JDMatchAnalysis model fields
        missing_skills=result.get("missing_skills", []),
        ats_compatibility=result.get("ats_compatibility", {})
    )
    return analysis

def generate_skill_gap(user, target_role: str, experience: str = "Mid-Level") -> SkillGapAnalysis:
    latest_resume = Resume.objects.filter(user=user).order_by("-created_at").first()
    user_skills = []
    if latest_resume and hasattr(latest_resume, "parsed_content"):
        user_skills = latest_resume.parsed_content.extracted_skills
        
    prompt = f"""
Compare the user's current skills vs. requirements for target role: "{target_role}" at "{experience}" level.
User's skills: {json.dumps(user_skills)}

Identify:
1. Missing skills
2. Recommended skills
3. Learning priority list indicating priority, time estimates, and learning resource references.
4. A detailed phased career roadmap containing specific milestones and actionable guidance based on the user's experience level.

Your response MUST be a JSON object matching this schema:
{{
  "missing_skills": ["skill1"],
  "recommended_skills": ["skill2"],
  "learning_priority": [
     {{"skill": "skillname", "priority": "High/Medium/Low", "time_estimate": "1 week", "resources": "links/docs"}}
  ],
  "roadmap": [
     {{"phase": "Phase 1 (Months 1-2): Core Foundations", "milestones": ["Learn X", "Build Y"], "guidance": "Focus on..."}}
  ]
}}
"""
    try:
        result = call_gemini_api(prompt, response_mime_type="application/json", max_retries=1)
    except Exception as e:
        logger.error(f"Skill gap API failed: {str(e)}")
        result = {
            "missing_skills": ["Unable to fetch missing skills"],
            "recommended_skills": ["Unable to fetch recommendations"],
            "learning_priority": [],
            "roadmap": []
        }
    
    gap = SkillGapAnalysis.objects.create(
        user=user,
        target_role=target_role,
        missing_skills=result.get("missing_skills", []),
        recommended_skills=result.get("recommended_skills", []),
        learning_priority=result.get("learning_priority", []),
        roadmap=result.get("roadmap", [])
    )
    return gap

def generate_career_roadmap(user, current_role: str, target_role: str) -> CareerRoadmap:
    prompt = f"""
Generate a step-by-step career path roadmap from current role "{current_role}" to target role "{target_role}".
Provide learning path phases, required technologies, certifications, and milestones.

Your response MUST be a JSON object matching this schema:
{{
  "learning_path": [
     {{"phase": "Phase title", "milestones": ["milestone 1", "milestone 2"]}}
  ],
  "technologies": ["tech1", "tech2"],
  "certifications": ["cert1"],
  "milestones": ["milestone 1"]
}}
"""
    try:
        result = call_gemini_api(prompt, response_mime_type="application/json", max_retries=1)
    except Exception as e:
        logger.error(f"Career roadmap API failed: {str(e)}")
        result = {
            "learning_path": [],
            "technologies": [],
            "certifications": [],
            "milestones": []
        }
    
    roadmap = CareerRoadmap.objects.create(
        user=user,
        current_role=current_role,
        target_role=target_role,
        learning_path=result.get("learning_path", []),
        technologies=result.get("technologies", []),
        certifications=result.get("certifications", []),
        milestones=result.get("milestones", [])
    )
    return roadmap

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


class CareerScoreService:
    @staticmethod
    def calculate_score(user) -> dict:
        from resumes.models import Resume
        from analysis.models import CareerReadinessSnapshot
        from jobs.models import JobRecommendation, SelectedJob

        latest_resume = Resume.objects.filter(user=user).order_by("-created_at").first()
        ats_score = 0
        parsed = None
        if latest_resume:
            ats_obj = latest_resume.ats_analyses.order_by("-created_at").first()
            if ats_obj:
                ats_score = ats_obj.ats_score
            else:
                from analysis.services import ATSScoringService
                try:
                    ats_res = ATSScoringService.calculate_ats_score(latest_resume)
                    ats_score = ats_res.get("ats_score", 0)
                except Exception:
                    ats_score = 0
            parsed = getattr(latest_resume, "parsed_content", None)

        skills = []
        if parsed and parsed.extracted_skills:
            skills = [s.lower() for s in parsed.extracted_skills if isinstance(s, str)]

        industry_baselines = {
            "python", "django", "flask", "fastapi", "javascript", "react", "angular", "vue",
            "node", "express", "typescript", "flutter", "dart", "java", "spring", "c++", "c#",
            ".net", "ruby", "rails", "go", "golang", "php", "laravel", "sql", "postgres", "mysql",
            "mongodb", "redis", "docker", "kubernetes", "aws", "gcp", "azure", "git", "github",
            "ci/cd", "html", "css", "tailwind", "sass", "graphql", "rest api", "testing", "pytest",
            "jest", "selenium", "agile", "scrum", "jira", "linux", "bash"
        }
        matched_baselines = [s for s in skills if s in industry_baselines]
        skill_coverage_score = min(100, len(matched_baselines) * 10)

        completeness_score = 0
        if parsed:
            comp_fields = [
                parsed.name,
                parsed.email,
                parsed.phone,
                parsed.extracted_skills,
                parsed.extracted_experience,
                parsed.extracted_education,
                parsed.extracted_projects,
                parsed.extracted_certifications
            ]
            filled_fields = [f for f in comp_fields if f]
            completeness_score = int((len(filled_fields) / 8.0) * 100)

        experience_score = 0
        if latest_resume:
            text = (parsed.extracted_text if parsed else getattr(latest_resume, "raw_text", "")) or ""
            action_verbs = {"led", "managed", "designed", "built", "created", "optimized", "refactored", "developed", "implemented", "engineered"}
            verbs_found = [v for v in action_verbs if v in text.lower()]
            exp_count = len(parsed.extracted_experience if (parsed and parsed.extracted_experience) else [])
            experience_score = min(100, (len(verbs_found) * 10) + (exp_count * 15))
            if experience_score == 0 and len(text) > 100:
                experience_score = 60

        job_match_scores = []
        saved_jobs = SelectedJob.objects.filter(user=user, status=SelectedJob.StatusChoices.SAVED)
        for sj in saved_jobs:
            job_match_scores.append(85)
        recs = JobRecommendation.objects.filter(user=user)
        for r in recs:
            job_match_scores.append(r.match_score)

        if job_match_scores:
            job_match_score = int(sum(job_match_scores) / len(job_match_scores))
        else:
            job_match_score = 70

        profile_score = 0
        profile = getattr(user, "profile", None)
        if profile:
            profile_fields = [
                profile.phone,
                profile.location,
                profile.linkedin_url,
                profile.github_url,
                profile.current_role,
                profile.years_of_experience
            ]
            filled_profile = [f for f in profile_fields if f]
            profile_score = int((len(filled_profile) / 6.0) * 100)

        career_score = int(
            (ats_score * 0.25) +
            (skill_coverage_score * 0.20) +
            (completeness_score * 0.15) +
            (experience_score * 0.15) +
            (job_match_score * 0.15) +
            (profile_score * 0.10)
        )

        factors = {
            "ats": ats_score,
            "skills": skill_coverage_score,
            "completeness": completeness_score,
            "experience": experience_score,
            "job_match": job_match_score,
            "profile": profile_score
        }

        snapshot = CareerReadinessSnapshot.objects.create(
            user=user,
            career_score=career_score,
            factors=factors
        )

        return {
            "career_score": career_score,
            "factors": factors,
            "created_at": snapshot.created_at.strftime("%Y-%m-%d")
        }

    @staticmethod
    def get_trend_data(user) -> list:
        from analysis.models import CareerReadinessSnapshot
        snapshots = CareerReadinessSnapshot.objects.filter(user=user).order_by("created_at")
        trend = []
        for s in snapshots:
            trend.append({
                "date": s.created_at.strftime("%Y-%m-%d"),
                "score": s.career_score
            })
        return trend

    @staticmethod
    def get_recommended_actions(factors: dict) -> list:
        if not isinstance(factors, dict):
            factors = {}
        actions = []
        if factors.get("ats", 0) < 80:
            actions.append("Optimize your resume's keywords and formatting to boost ATS compatibility.")
        if factors.get("skills", 0) < 70:
            actions.append("Acquire industry-standard skills (e.g. Docker, Cloud tools, CI/CD) matching your career target.")
        if factors.get("completeness", 0) < 90:
            actions.append("Complete missing resume sections (e.g. Certifications, Projects) to present a comprehensive profile.")
        if factors.get("experience", 0) < 70:
            actions.append("Strengthen resume bullet points by using strong action verbs like 'Engineered' or 'Led'.")
        if factors.get("job_match", 0) < 75:
            actions.append("Apply to job roles that match your skill set to improve job match compatibility.")
        if factors.get("profile", 0) < 80:
            actions.append("Complete your user profile, adding LinkedIn and GitHub URLs to improve recruiter outreach.")
        if not actions:
            actions.append("Excellent career readiness! Keep updating your skills and certifications.")
class AdvancedSkillGapService:
    @staticmethod
    def analyze_skill_gap(user, target_role: str, resume_id: int = None):
        """
        Calculates missing skills and creates a career roadmap by:
        1. Checking the provided resume (or latest)
        2. Scraping job descriptions for the role
        3. Identifying missing skills
        4. Leveraging AI to build a customized career roadmap
        """
        from resumes.models import Resume
        from jobs.services import fetch_jobs_from_jsearch
        from analysis.models import SkillGapAnalysis
        import re
        from collections import Counter

        if resume_id:
            latest_resume = Resume.objects.filter(user=user, id=resume_id).first()
        else:
            latest_resume = Resume.objects.filter(user=user).order_by("-created_at").first()
            
        user_skills = []
        if latest_resume and hasattr(latest_resume, "parsed_content") and latest_resume.parsed_content:
            user_skills = [s.lower() for s in latest_resume.parsed_content.extracted_skills]

        jobs = fetch_jobs_from_jsearch(target_role, page=1)

        tech_dictionary = {
            "python", "django", "flask", "fastapi", "javascript", "react", "angular", "vue",
            "node", "express", "typescript", "flutter", "dart", "java", "spring", "c++", "c#",
            "net", "ruby", "rails", "go", "golang", "php", "laravel", "sql", "postgres", "mysql",
            "mongodb", "redis", "docker", "kubernetes", "aws", "gcp", "azure", "git", "github",
            "ci/cd", "html", "css", "tailwind", "sass", "graphql", "rest api", "testing", "pytest",
            "jest", "selenium", "agile", "scrum", "jira", "linux", "bash"
        }

        tech_counts = Counter()
        for job in jobs:
            desc_lower = job.description.lower()
            for tech in tech_dictionary:
                if re.search(r'\b' + re.escape(tech) + r'\b', desc_lower):
                    tech_counts[tech] += 1

        if not tech_counts:
            defaults = ["git", "sql", "docker"]
            if "python" in target_role.lower() or "backend" in target_role.lower():
                defaults += ["python", "django", "postgres", "aws"]
            elif "flutter" in target_role.lower() or "mobile" in target_role.lower():
                defaults += ["flutter", "dart", "rest api"]
            else:
                defaults += ["javascript", "react", "html", "css"]
            for d in defaults:
                tech_counts[d] = 1

        total_jobs = len(jobs) if jobs else 1
        priority_skills = []
        missing_skills = []

        sorted_market_techs = [tech for tech, count in tech_counts.most_common()]

        for tech in sorted_market_techs:
            frequency_pct = (tech_counts[tech] / total_jobs) * 100
            if frequency_pct >= 50:
                priority = "High"
            elif frequency_pct >= 20:
                priority = "Medium"
            else:
                priority = "Low"

            if tech not in user_skills:
                if frequency_pct >= 20:
                    missing_skills.append(tech)
                    priority_skills.append({
                        "skill": tech,
                        "priority": priority,
                        "market_demand_pct": int(frequency_pct)
                    })

        # Ask Gemini to generate a detailed roadmap based on the scraped missing skills
        from common.gemini import call_gemini_api
        import json
        
        experience = getattr(user, '_temp_experience', 'Mid-Level')
        
        prompt = f"""
Create a detailed phased career roadmap for a user transitioning to "{target_role}" at the "{experience}" experience level.
The user is currently missing the following key skills (which were scraped from live job postings): {missing_skills}

Identify:
1. A detailed phased career roadmap containing specific milestones and actionable guidance based on the user's experience level.

Your response MUST be a JSON object matching this schema:
{{
  "roadmap": [
     {{"phase": "Phase 1 (Months 1-2): Core Foundations", "milestones": ["Learn X", "Build Y"], "guidance": "Focus on..."}}
  ]
}}
"""
        roadmap = []
        try:
            ai_result = call_gemini_api(prompt, response_mime_type="application/json", max_retries=1)
            roadmap = ai_result.get("roadmap", [])
        except Exception as e:
            logger.error(f"Skill gap AI roadmap failed: {str(e)}")
            # Fallback to basic if AI fails
            roadmap = [{"phase": "Basic Phase", "milestones": missing_skills, "guidance": "Learn these skills"}]

        gap, created = SkillGapAnalysis.objects.update_or_create(
            user=user,
            target_role=target_role,
            defaults={
                "missing_skills": missing_skills,
                "recommended_skills": missing_skills[:5],
                "learning_priority": [],
                "roadmap": roadmap
            }
        )

        return {
            "missing_skills": missing_skills,
            "priority_skills": priority_skills,
            "recommended_learning_order": missing_skills,
            "learning_priority": [],
            "roadmap": roadmap
        }


class CareerRoadmapService:
    @staticmethod
    def generate_roadmap(user, current_role: str, target_role: str):
        from analysis.services import generate_career_roadmap
        return generate_career_roadmap(user, current_role, target_role)


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


class CoverLetterService:
    @staticmethod
    def generate_cover_letter(resume, job_title: str, company_name: str, job_description: str):
        from analysis.services import generate_cover_letter
        return generate_cover_letter(resume, job_title, company_name, job_description)


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


